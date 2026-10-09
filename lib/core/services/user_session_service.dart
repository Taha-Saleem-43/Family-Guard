import 'package:shared_preferences/shared_preferences.dart';
import '../../features/sos/services/sos_dismissal_store.dart';

class UserSessionService {
  static const String _activeUidKey = 'fg_active_user_uid';
  static String _key(String uid, String suffix) =>
      'fg_user_session_${uid}_$suffix';

  static Future<void> deleteUserSession(String uid) async {
    await PreferencesSOSDismissalStore.drainPendingWrites();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('fg_push_token_account_uid') == uid &&
        !await prefs.remove('fg_push_token_account_uid')) {
      throw StateError('Could not clear local device account data.');
    }
    if (prefs.getString(_activeUidKey) == uid) {
      await prefs.remove(_activeUidKey);
    }
    final encoded = Uri.encodeComponent(uid);
    bool ownsSosKey(String key, String prefix) {
      if (!key.startsWith(prefix)) return false;
      final rest = key.substring(prefix.length);
      final separator = rest.lastIndexOf('.');
      return separator >= 0 && rest.substring(0, separator) == encoded;
    }

    final sessionKeys = {
      for (final suffix in [
        'isLoggedIn',
        'role',
        'circleId',
        'email',
        'userName',
        'circleName',
        'childCode',
        'parentCode',
        'idToken',
        'tokenSavedAt',
        'sharingConsent',
      ])
        _key(uid, suffix),
    };
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              sessionKeys.contains(key) ||
              ownsSosKey(key, 'sos.pending.') ||
              ownsSosKey(key, 'sos.dismissed.'),
        )
        .toList();
    for (final key in keys) {
      if (!await prefs.remove(key)) {
        throw StateError('Could not clear local account data.');
      }
    }
  }

  /// Cache display metadata only. Firebase Auth owns credential persistence.
  static Future<void> saveUserSession({
    required String uid,
    required String role,
    required String circleId,
    String? email,
    String? userName,
    String? circleName,
    String? childCode,
    String? parentCode,
    String? idToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeUidKey, uid);
      await prefs.setBool(_key(uid, 'isLoggedIn'), true);
      await prefs.setString(_key(uid, 'role'), role);
      await prefs.setString(_key(uid, 'circleId'), circleId);
      if (email != null && email.isNotEmpty) {
        await prefs.setString(_key(uid, 'email'), email);
      }
      if (userName != null && userName.isNotEmpty) {
        await prefs.setString(_key(uid, 'userName'), userName);
      }
      if (circleName != null && circleName.isNotEmpty) {
        await prefs.setString(_key(uid, 'circleName'), circleName);
      }
      if (childCode != null && childCode.isNotEmpty) {
        await prefs.setString(_key(uid, 'childCode'), childCode);
      }
      if (parentCode != null && parentCode.isNotEmpty) {
        await prefs.setString(_key(uid, 'parentCode'), parentCode);
      }
      // Remove tokens written by earlier app versions; never store a new JWT here.
      await prefs.remove(_key(uid, 'idToken'));
      await prefs.remove(_key(uid, 'tokenSavedAt'));
    } catch (_) {}
  }

  /// Get cached session data for a specific user ID
  static Future<Map<String, dynamic>?> getUserSession(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_key(uid, 'isLoggedIn')) ?? false;
      final role = prefs.getString(_key(uid, 'role'));
      final circleId = prefs.getString(_key(uid, 'circleId'));

      if (isLoggedIn && circleId != null && circleId.isNotEmpty) {
        return {
          'uid': uid,
          'isLoggedIn': true,
          'role': role ?? 'child',
          'circleId': circleId,
          'email': prefs.getString(_key(uid, 'email')),
          'userName': prefs.getString(_key(uid, 'userName')),
          'circleName': prefs.getString(_key(uid, 'circleName')),
          'childCode': prefs.getString(_key(uid, 'childCode')),
          'parentCode': prefs.getString(_key(uid, 'parentCode')),
        };
      }
    } catch (_) {}
    return null;
  }

  /// Get currently saved active user session (if any)
  static Future<Map<String, dynamic>?> getActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeUid = prefs.getString(_activeUidKey);
      if (activeUid != null && activeUid.isNotEmpty) {
        return await getUserSession(activeUid);
      }
    } catch (_) {}
    return null;
  }

  /// Clear session data for a user ID and invalidate active JWT session
  static Future<void> clearUserSession(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeUid = prefs.getString(_activeUidKey);
      if (activeUid == uid) {
        await prefs.remove(_activeUidKey);
      }
      await prefs.setBool(_key(uid, 'isLoggedIn'), false);
      await prefs.remove(_key(uid, 'role'));
      await prefs.remove(_key(uid, 'circleId'));
      await prefs.remove(_key(uid, 'email'));
      await prefs.remove(_key(uid, 'userName'));
      await prefs.remove(_key(uid, 'circleName'));
      await prefs.remove(_key(uid, 'childCode'));
      await prefs.remove(_key(uid, 'parentCode'));
      await prefs.remove(_key(uid, 'idToken'));
      await prefs.remove(_key(uid, 'tokenSavedAt'));
      await prefs.remove(_key(uid, 'sharingConsent'));
    } catch (_) {}
  }
}
