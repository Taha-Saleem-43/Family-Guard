import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/member.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/user_session_service.dart';
import '../domain/circle_model.dart';
import '../domain/user_account_model.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserAccountModel> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (displayName.trim().isEmpty || displayName.trim().length > 80) {
      throw Exception('Enter a name of 1–80 characters.');
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    try {
      await user.updateDisplayName(displayName.trim());
      final account = UserAccountModel(
        uid: user.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: UserRole.child,
        createdAt: DateTime.now().toUtc(),
      );
      await _firestore.collection('users').doc(user.uid).set(account.toMap());
      return account;
    } catch (_) {
      await user.delete();
      rethrow;
    }
  }

  Future<UserAccountModel> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return loadCurrentAccount();
  }

  /// Preferences are display metadata, never authority for identity or membership.
  Future<UserAccountModel> loadCurrentAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Please sign in.');
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'Account profile is unavailable. Please contact support.',
      );
    }
    final account = UserAccountModel.fromMap(doc.data()!, user.uid);
    await UserSessionService.saveUserSession(
      uid: user.uid,
      role: account.role.name,
      circleId: account.circleId ?? '',
      email: account.email,
      userName: account.displayName,
    );
    return account;
  }

  Future<CircleModel> createCircle({required String circleName}) async {
    if (_auth.currentUser == null) throw Exception('Please sign in.');
    final result = await _functions.httpsCallable('createCircle').call({
      'circleName': circleName.trim(),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return CircleModel.fromMap(data, data['id'] as String);
  }

  Future<UserAccountModel> joinCircleByCode({
    required String inviteCode,
  }) async {
    if (_auth.currentUser == null) throw Exception('Please sign in.');
    if (inviteCode.trim().isEmpty) {
      throw Exception('Enter the complete invite code.');
    }
    await _functions.httpsCallable('joinCircle').call({
      'inviteCode': inviteCode.trim().toUpperCase(),
    });
    return loadCurrentAccount();
  }

  Future<void> signOut() async {
    await LocationService.instance.stop();
    final uid = _auth.currentUser?.uid;
    await _auth.signOut();
    if (uid != null) await UserSessionService.clearUserSession(uid);
    await LocationService.clearDebugLog();
  }

  Stream<CircleModel?> streamCircle(String circleId) {
    if (circleId.isEmpty) return Stream.value(null);
    return _firestore.collection('circles').doc(circleId).snapshots().map((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) return null;
      return CircleModel.fromMap(doc.data()!, doc.id);
    });
  }

  Stream<Map<String, dynamic>?> streamInvites(String circleId) => _firestore
      .collection('circles')
      .doc(circleId)
      .collection('private')
      .doc('invites')
      .snapshots()
      .map((doc) => doc.data());

  Stream<List<UserAccountModel>> streamCircleMembers(String circleId) {
    if (circleId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('users')
        .where('circleId', isEqualTo: circleId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => UserAccountModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Production codes are generated only by the server; retained for format tests.
  static String generateInviteCode(String prefix) {
    final random = Random.secure();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
    return '$prefix-$suffix';
  }
}
