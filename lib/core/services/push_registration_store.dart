import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushDeviceRegistration {
  final String installationId;
  final int version;
  final String secret;
  const PushDeviceRegistration(
    this.installationId,
    this.version, [
    this.secret = '',
  ]);
}

class PushRegistrationStore {
  static Future<void> _writes = Future.value();
  static const _idKey = 'fg_push_installation_id';
  static const _versionKey = 'fg_push_registration_version';
  static const _secretKey = 'fg_push_installation_secret';

  Future<PushDeviceRegistration> next() {
    final next = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      var secret = prefs.getString(_secretKey);
      if (secret == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(secret)) {
        final random = Random.secure();
        secret = List.generate(
          32,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        if (!await prefs.setString(_secretKey, secret)) {
          throw StateError('Device registration could not be saved.');
        }
      }
      final id = sha256
          .convert(utf8.encode(secret))
          .toString()
          .substring(0, 32);
      if (prefs.getString(_idKey) != id && !await prefs.setString(_idKey, id)) {
        throw StateError('Device identifier could not be saved.');
      }
      final version = (prefs.getInt(_versionKey) ?? 0) + 1;
      if (version < 1 ||
          version > 9007199254740991 ||
          !await prefs.setInt(_versionKey, version)) {
        throw StateError('Device registration version could not be saved.');
      }
      return PushDeviceRegistration(id, version, secret);
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
