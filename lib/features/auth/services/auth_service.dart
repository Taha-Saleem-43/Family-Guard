import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/app_state_provider.dart';
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
      return account;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Authentication failed');
    }
  }

  // 2. Sign In
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
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        return UserAccountModel.fromMap(doc.data()!, user.uid);
      } else {
        // Fallback if user doc missing
        final fallback = UserAccountModel(
          uid: user.uid,
          email: email,
          displayName: user.displayName ?? 'Family Member',
          role: UserRole.parent,
          createdAt: DateTime.now(),
        );
        await _firestore.collection('users').doc(user.uid).set(fallback.toMap());
        return fallback;
      }
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

    await _firestore.collection('circles').doc(circleId).set(circle.toMap());

    // Update user record with role: parent and circleId
    await _firestore.collection('users').doc(user.uid).update({
      'role': 'parent',
      'circleId': circleId,
    });

    return circle;
  }

  // 4. Join Circle by Code (Role derived from invite code type)
  Future<UserAccountModel> joinCircleByCode({required String inviteCode}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final normalizedCode = inviteCode.trim().toUpperCase();

    // Query circles by parent code or child code
    final parentMatchQuery = await _firestore
        .collection('circles')
        .where('parentInviteCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    UserRole assignedRole;
    DocumentSnapshot<Map<String, dynamic>>? circleDoc;

    if (parentMatchQuery.docs.isNotEmpty) {
      assignedRole = UserRole.parent;
      circleDoc = parentMatchQuery.docs.first;
    } else {
      final childMatchQuery = await _firestore
          .collection('circles')
          .where('childInviteCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (childMatchQuery.docs.isNotEmpty) {
        assignedRole = UserRole.child;
        circleDoc = childMatchQuery.docs.first;
      } else {
        throw Exception('Invalid or expired invite code. Please check and try again.');
      }
    }

    final circleId = circleDoc.id;

    // Add user to circle memberIds
    await _firestore.collection('circles').doc(circleId).update({
      'memberIds': FieldValue.arrayUnion([user.uid]),
    });

    // Lock in user's role and circleId
    final roleString = assignedRole == UserRole.parent ? 'parent' : 'child';
    await _firestore.collection('users').doc(user.uid).update({
      'role': roleString,
      'circleId': circleId,
    });

    final updatedDoc = await _firestore.collection('users').doc(user.uid).get();
    return UserAccountModel.fromMap(updatedDoc.data()!, user.uid);
  }

  // 5. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Helper code generator
  static String generateInviteCode(String prefix) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final randomPart = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return '$prefix-$randomPart';
  }
}
