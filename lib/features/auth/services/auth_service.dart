import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/services/user_session_service.dart';
import '../domain/circle_model.dart';
import '../domain/user_account_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Sign Up
  Future<UserAccountModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;
      await user.updateDisplayName(displayName);

      final account = UserAccountModel(
        uid: user.uid,
        email: email,
        displayName: displayName,
        role: UserRole.parent, // Default until circle created or joined
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(user.uid).set(account.toMap());

      try {
        final idToken = await user.getIdToken();
        await UserSessionService.saveUserSession(
          uid: user.uid,
          role: 'parent',
          circleId: '',
          email: email,
          userName: displayName,
          idToken: idToken,
        );
      } catch (_) {}

      return account;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed');
    }
  }

  // 2. Sign In (Restores circleId and role from Firestore or local UserSessionService)
  Future<UserAccountModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await _firestore.collection('users').doc(user.uid).get();
      } catch (_) {}

      UserAccountModel account;

      if (doc != null && doc.exists && doc.data() != null) {
        account = UserAccountModel.fromMap(doc.data()!, user.uid);
      } else {
        account = UserAccountModel(
          uid: user.uid,
          email: email,
          displayName: user.displayName ?? 'Family Member',
          role: UserRole.parent,
          createdAt: DateTime.now(),
        );
      }

      String? idToken;
      try {
        idToken = await user.getIdToken();
      } catch (_) {}

      // Check local session cache if circleId is missing or empty
      if (account.circleId == null || account.circleId!.isEmpty) {
        final cached = await UserSessionService.getUserSession(user.uid);
        if (cached != null && cached['circleId'] != null) {
          final cachedRole = cached['role'] == 'parent' ? UserRole.parent : UserRole.child;
          account = account.copyWith(
            circleId: cached['circleId'],
            role: cachedRole,
          );
          // Sync restored data back to Firestore
          try {
            await _firestore.collection('users').doc(user.uid).set({
              'role': cached['role'],
              'circleId': cached['circleId'],
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }

      // Check circle details if circleId is present
      String? circleName;
      String? childCode;
      String? parentCode;
      if (account.circleId != null && account.circleId!.isNotEmpty) {
        try {
          final cDoc = await _firestore.collection('circles').doc(account.circleId!).get();
          if (cDoc.exists && cDoc.data() != null) {
            final cData = cDoc.data()!;
            circleName = cData['name'] as String?;
            childCode = cData['childInviteCode'] as String?;
            parentCode = cData['parentInviteCode'] as String?;
          }
        } catch (_) {}
      }

      // Save latest info & token to local session cache
      await UserSessionService.saveUserSession(
        uid: user.uid,
        role: account.role == UserRole.parent ? 'parent' : 'child',
        circleId: account.circleId ?? '',
        circleName: circleName,
        childCode: childCode,
        parentCode: parentCode,
        email: account.email,
        userName: account.displayName,
        idToken: idToken,
      );

      return account;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Sign in failed');
    }
  }

  // 3. Create Circle (Assigns role: parent)
  Future<CircleModel> createCircle({required String circleName}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final circleId = _firestore.collection('circles').doc().id;
    final parentCode = generateInviteCode('PARENT');
    final childCode = generateInviteCode('FAMILY');

    final circle = CircleModel(
      id: circleId,
      name: circleName,
      parentInviteCode: parentCode,
      childInviteCode: childCode,
      createdBy: user.uid,
      memberIds: [user.uid],
      createdAt: DateTime.now(),
    );

    try {
      await _firestore.collection('circles').doc(circleId).set(circle.toMap());
      await _firestore.collection('users').doc(user.uid).set({
        'role': 'parent',
        'circleId': circleId,
        'displayName': user.displayName ?? 'Family Member',
        'email': user.email ?? '',
      }, SetOptions(merge: true));
    } catch (_) {}

    String? idToken;
    try {
      idToken = await user.getIdToken();
    } catch (_) {}

    // Persist to local session cache
    await UserSessionService.saveUserSession(
      uid: user.uid,
      role: 'parent',
      circleId: circleId,
      circleName: circleName,
      childCode: childCode,
      parentCode: parentCode,
      email: user.email,
      userName: user.displayName,
      idToken: idToken,
    );

    return circle;
  }

  // 4. Join Circle by Code (Role derived from invite code type)
  Future<UserAccountModel> joinCircleByCode({required String inviteCode}) async {
    final user = _auth.currentUser;
    final normalizedCode = inviteCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('Please enter a valid invite code');
    }

    // Try code variants (e.g. 7K4X, FAMILY-7K4X, PARENT-7K4X)
    List<String> childVariants = [normalizedCode];
    List<String> parentVariants = [normalizedCode];

    if (!normalizedCode.contains('-')) {
      childVariants.add('FAMILY-$normalizedCode');
      parentVariants.add('PARENT-$normalizedCode');
    }

    UserRole assignedRole = UserRole.child;
    DocumentSnapshot<Map<String, dynamic>>? circleDoc;

    try {
      if (normalizedCode.startsWith('PARENT') || normalizedCode.startsWith('P-')) {
        // Query by parent invite code first
        final parentMatchQuery = await _firestore
            .collection('circles')
            .where('parentInviteCode', whereIn: parentVariants)
            .limit(1)
            .get();

        if (parentMatchQuery.docs.isNotEmpty) {
          assignedRole = UserRole.parent;
          circleDoc = parentMatchQuery.docs.first;
        }
      } else {
        // Query by child invite code first
        final childMatchQuery = await _firestore
            .collection('circles')
            .where('childInviteCode', whereIn: childVariants)
            .limit(1)
            .get();

        if (childMatchQuery.docs.isNotEmpty) {
          assignedRole = UserRole.child;
          circleDoc = childMatchQuery.docs.first;
        } else {
          // Fallback: check parent invite code
          final parentMatchQuery = await _firestore
              .collection('circles')
              .where('parentInviteCode', whereIn: parentVariants)
              .limit(1)
              .get();

          if (parentMatchQuery.docs.isNotEmpty) {
            assignedRole = UserRole.parent;
            circleDoc = parentMatchQuery.docs.first;
          }
        }
      }
    } catch (_) {
      if (normalizedCode.startsWith('PARENT') || normalizedCode.startsWith('P-')) {
        assignedRole = UserRole.parent;
      } else {
        assignedRole = UserRole.child;
      }
    }

    final circleId = circleDoc?.id ?? 'circle_${normalizedCode.replaceAll('-', '_').toLowerCase()}';
    final roleString = assignedRole == UserRole.parent ? 'parent' : 'child';

    String? idToken;
    try {
      if (user != null) {
        idToken = await user.getIdToken();
      }
    } catch (_) {}

    final circleName = circleDoc?.data()?['name'] as String?;
    final childCode = circleDoc?.data()?['childInviteCode'] as String?;
    final parentCode = circleDoc?.data()?['parentInviteCode'] as String?;

    if (user != null) {
      // Save local user session cache
      await UserSessionService.saveUserSession(
        uid: user.uid,
        role: roleString,
        circleId: circleId,
        circleName: circleName,
        childCode: childCode,
        parentCode: parentCode,
        email: user.email,
        userName: user.displayName,
        idToken: idToken,
      );

      try {
        if (circleDoc != null) {
          await _firestore.collection('circles').doc(circleId).update({
            'memberIds': FieldValue.arrayUnion([user.uid]),
          });
        }
        await _firestore.collection('users').doc(user.uid).set({
          'role': roleString,
          'circleId': circleId,
          'displayName': user.displayName ?? 'Family Member',
          'email': user.email ?? '',
          'batteryLevel': 100,
          'isCharging': false,
          'lastSeen': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));

        final updatedDoc = await _firestore.collection('users').doc(user.uid).get();
        if (updatedDoc.exists && updatedDoc.data() != null) {
          return UserAccountModel.fromMap(updatedDoc.data()!, user.uid);
        }
      } catch (_) {}

      return UserAccountModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Family Member',
        role: assignedRole,
        circleId: circleId,
        createdAt: DateTime.now(),
      );
    } else {
      return UserAccountModel(
        uid: 'demo_user',
        email: 'demo@familyguard.app',
        displayName: 'Family Member',
        role: assignedRole,
        circleId: circleId,
        createdAt: DateTime.now(),
      );
    }
  }

  // 5. Sign Out & Invalidate Session / JWT Token
  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      try {
        await user.getIdToken(true); // Force refresh/check before sign out
      } catch (_) {}
      await UserSessionService.clearUserSession(uid);
    }
    await _auth.signOut();
  }

  // 6. Real-time Streams
  Stream<CircleModel?> streamCircle(String circleId) {
    if (circleId.isEmpty) return Stream.value(null);
    return _firestore.collection('circles').doc(circleId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CircleModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Stream<List<UserAccountModel>> streamCircleMembers(String circleId) {
    if (circleId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .where('circleId', isEqualTo: circleId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserAccountModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Helper code generator
  static String generateInviteCode(String prefix) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final randomPart = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix-$randomPart';
  }
}

