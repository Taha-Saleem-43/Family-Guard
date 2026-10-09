import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ConsentSession = ({String uid, int signedInAt});

/// Records an explicit disclosure acknowledgement for this device and sign-in.
class SharingConsentService {
  SharingConsentService({ConsentSession? Function()? session})
    : _session = session ?? _firebaseSession;
  final ConsentSession? Function() _session;
  static const version = 1;
  static ConsentSession? _firebaseSession() {
    if (Firebase.apps.isEmpty) return null;
    final user = FirebaseAuth.instance.currentUser;
    final time = user?.metadata.lastSignInTime;
    return user == null || time == null
        ? null
        : (uid: user.uid, signedInAt: time.millisecondsSinceEpoch);
  }

  String _key(String uid) => 'fg_user_session_${uid}_sharingConsent';

  Future<bool> accepted(String uid, String circleId) async {
    final session = _session();
    if (session == null || session.uid != uid || circleId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    if (_session() != session) return false;
    try {
      final value = jsonDecode(prefs.getString(_key(uid)) ?? '');
      return value is Map &&
          value['version'] == version &&
          value['circleId'] == circleId &&
          value['signedInAt'] == session.signedInAt;
    } on FormatException {
      return false;
    }
  }

  Future<void> accept(String uid, String circleId) async {
    final session = _session();
    if (session == null || session.uid != uid || circleId.isEmpty) {
      throw StateError('Sign in before confirming location sharing.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (_session() != session) throw StateError('Account changed.');
    final saved = await prefs.setString(
      _key(uid),
      jsonEncode({
        'version': version,
        'circleId': circleId,
        'signedInAt': session.signedInAt,
      }),
    );
    if (!saved || _session() != session) {
      throw StateError('Location sharing consent could not be saved.');
    }
  }
}
