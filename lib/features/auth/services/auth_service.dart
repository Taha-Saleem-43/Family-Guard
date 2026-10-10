import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tracelet/tracelet.dart' as tl;
import '../../../core/models/member.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/user_session_service.dart';
import '../../../core/services/push_runtime.dart';
import '../domain/circle_model.dart';
import '../domain/user_account_model.dart';

import '../../../core/services/backend_functions.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final Future<void> Function(String?)? _stopTracking;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    Future<void> Function(String?)? stopTracking,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _stopTracking = stopTracking;

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
      _requireCurrentUid(user.uid);
      await user.updateDisplayName(displayName.trim());
      _requireCurrentUid(user.uid);
      final account = UserAccountModel(
        uid: user.uid,
        email: email.trim(),
        displayName: displayName.trim(),
        role: UserRole.child,
        createdAt: DateTime.now().toUtc(),
      );
      await _firestore.collection('users').doc(user.uid).set(account.toMap());
      _requireCurrentUid(user.uid);
      return account;
    } catch (_) {
      if (_auth.currentUser?.uid == user.uid) await user.delete();
      rethrow;
    }
  }

  Future<UserAccountModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _requireCurrentUid(credential.user!.uid);
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
    _requireCurrentUid(user.uid);
    if (!doc.exists || doc.data() == null) {
      throw Exception(
        'Account profile is unavailable. Please contact support.',
      );
    }
    if (doc.data()?['deletionRequested'] == true) {
      await _auth.signOut();
      throw Exception('Account deletion is processing.');
    }
    final account = UserAccountModel.fromMap(doc.data()!, user.uid);
    await UserSessionService.saveUserSession(
      uid: user.uid,
      role: account.role.name,
      circleId: account.circleId ?? '',
      email: account.email,
      userName: account.displayName,
    );
    _requireCurrentUid(user.uid);
    return account;
  }

  Future<CircleModel> createCircle({required String circleName}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Please sign in.');
    final result = await BackendFunctions.callable(
      'createCircle',
      functions: _functions,
    ).call({'expectedUid': uid, 'circleName': circleName.trim()});
    _requireCurrentUid(uid);
    final data = Map<String, dynamic>.from(result.data as Map);
    return CircleModel.fromMap(data, data['id'] as String);
  }

  Future<UserAccountModel> joinCircleByCode({
    required String inviteCode,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Please sign in.');
    if (inviteCode.trim().isEmpty) {
      throw Exception('Enter the complete invite code.');
    }
    await BackendFunctions.callable(
      'joinCircle',
      functions: _functions,
    ).call({'expectedUid': uid, 'inviteCode': inviteCode.trim().toUpperCase()});
    _requireCurrentUid(uid);
    return loadCurrentAccount();
  }

  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await PushRuntime.active?.coordinator.detach(uid);
    Object? trackingError;
    StackTrace? trackingStack;
    try {
      await (_stopTracking?.call(uid) ??
          LocationService.instance.stop(expectedUid: uid));
    } catch (error, stack) {
      trackingError = error;
      trackingStack = stack;
    }
    if (_auth.currentUser?.uid != uid) {
      throw StateError('Your account changed.');
    }
    await _auth.signOut();
    if (uid != null) await UserSessionService.clearUserSession(uid);
    await LocationService.clearDebugLog();
    if (trackingError != null) {
      Error.throwWithStackTrace(trackingError, trackingStack!);
    }
  }

  void _requireCurrentUid(String uid) {
    if (_auth.currentUser?.uid != uid) {
      throw StateError('Your account changed.');
    }
  }

  Future<void> verifyDeletionSignIn(String uid, String password) async {
    _requireCurrentUid(uid);
    final user = _auth.currentUser!;
    final email = user.email;
    if (email == null) throw StateError('Sign-in verification is unavailable.');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
    await user.getIdToken(true);
    _requireCurrentUid(uid);
  }

  Future<void> pauseDeletionSharing(String uid) async {
    _requireCurrentUid(uid);
    await PushRuntime.active?.coordinator.detach(uid);
    await (_stopTracking?.call(uid) ??
        LocationService.instance.stop(expectedUid: uid));
    _requireCurrentUid(uid);
  }

  Future<bool> enqueueAccountDeletion(String uid) async {
    _requireCurrentUid(uid);
    final result = await BackendFunctions.callable(
      'requestAccountDeletion',
      functions: _functions,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    ).call({'expectedUid': uid});
    return result.data is Map && result.data['accepted'] == true;
  }

  Future<void> clearDeletedAccountLocalData(String uid) async {
    if (_auth.currentUser != null && _auth.currentUser?.uid != uid) {
      throw StateError('Account changed; local tracking data was not cleared.');
    }
    var nativeComplete = true;
    try {
      if (!await tl.Tracelet.destroyLocations()) nativeComplete = false;
    } catch (_) {
      nativeComplete = false;
    }
    try {
      if (!await tl.Tracelet.removeGeofences()) nativeComplete = false;
    } catch (_) {
      nativeComplete = false;
    }
    await LocationService.clearDebugLog();
    await UserSessionService.deleteUserSession(uid);
    if (!nativeComplete) {
      throw StateError('Native tracking data cleanup was incomplete.');
    }
  }

  Future<void> signOutDeletedAccount(String uid) async {
    if (_auth.currentUser?.uid == uid) await _auth.signOut();
    await UserSessionService.deleteUserSession(uid);
  }

  Future<DateTime> rotateCircleInvites(String circleId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Please sign in.');
    final result = await BackendFunctions.callable(
      'rotateCircleInvites',
      functions: _functions,
    ).call({'expectedUid': uid, 'circleId': circleId});
    _requireCurrentUid(uid);
    final data = Map<String, dynamic>.from(result.data as Map);
    return DateTime.parse(data['expiresAt'] as String);
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
