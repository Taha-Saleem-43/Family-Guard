import 'package:shared_preferences/shared_preferences.dart';

abstract class SOSDismissalStore {
  Future<Set<String>> load(String uid, String circleId);
  Future<void> save(String uid, String circleId, Set<String> ids);
}

/// Stores only opaque alert IDs, scoped to the signed-in account and circle.
class PreferencesSOSDismissalStore implements SOSDismissalStore {
  String _key(String uid, String circleId) =>
      'sos.dismissed.${Uri.encodeComponent(uid)}.${Uri.encodeComponent(circleId)}';
  @override
  Future<Set<String>> load(String uid, String circleId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key(uid, circleId)) ?? []).toSet();
  }

  @override
  Future<void> save(String uid, String circleId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = ids.toList();
    final bounded = recent.length > 100
        ? recent.sublist(recent.length - 100)
        : recent;
    if (!await prefs.setStringList(_key(uid, circleId), bounded)) {
      throw StateError('Could not save dismissed emergencies.');
    }
  }
}
