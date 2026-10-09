import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SOSRequestStore {
  Future<String> getOrCreate(String uid, String circleId);
  Future<void> clear(String uid, String circleId);
}

/// Saves an idempotency key before network I/O and retains it after a timeout.
class PreferencesSOSRequestStore implements SOSRequestStore {
  String _key(String uid, String circleId) =>
      'sos.pending.${Uri.encodeComponent(uid)}.${Uri.encodeComponent(circleId)}';
  @override
  Future<String> getOrCreate(String uid, String circleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(uid, circleId);
    final existing = prefs.getString(key);
    if (existing != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    if (!await prefs.setString(key, id)) {
      throw StateError('Could not save request for safe retry.');
    }
    return id;
  }

  @override
  Future<void> clear(String uid, String circleId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(uid, circleId))) {
      throw StateError('Could not clear request.');
    }
  }
}
