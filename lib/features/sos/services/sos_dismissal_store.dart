import 'package:shared_preferences/shared_preferences.dart';

abstract class SOSDismissalStore {
  Future<Set<String>> load(String uid, String circleId);
  Future<void> save(String uid, String circleId, Set<String> ids);
}

/// Stores only opaque alert IDs, scoped to the signed-in account and circle.
class PreferencesSOSDismissalStore implements SOSDismissalStore {
  // Shared across provider recreation so a late older write cannot replace a newer dismissal.
  static Future<void> _pendingWrites = Future.value();
  static final Map<String, List<String>> _pendingSnapshots = {};
  final Future<bool> Function(String, List<String>)? _write;
  PreferencesSOSDismissalStore({
    Future<bool> Function(String, List<String>)? write,
  }) : _write = write;

  static Set<String> bounded(
    Iterable<String> ids, {
    Set<String> activeIds = const {},
  }) {
    final ordered = ids.toSet();
    final recent = [
      ...ordered.where((id) => !activeIds.contains(id)),
      ...ordered.where(activeIds.contains),
    ];
    return (recent.length > 100 ? recent.sublist(recent.length - 100) : recent)
        .toSet();
  }

  String _key(String uid, String circleId) =>
      'sos.dismissed.${Uri.encodeComponent(uid)}.${Uri.encodeComponent(circleId)}';
  @override
  Future<Set<String>> load(String uid, String circleId) async {
    final key = _key(uid, circleId);
    final prefs = await SharedPreferences.getInstance();
    return bounded(_pendingSnapshots[key] ?? prefs.getStringList(key) ?? []);
  }

  @override
  Future<void> save(String uid, String circleId, Set<String> ids) {
    final snapshot = bounded(ids).toList();
    final key = _key(uid, circleId);
    _pendingSnapshots[key] = snapshot;
    final next = _pendingWrites.then((_) async {
      try {
        final bool saved;
        if (_write != null) {
          saved = await _write(key, snapshot);
        } else {
          final prefs = await SharedPreferences.getInstance();
          saved = await prefs.setStringList(key, snapshot);
        }
        if (!saved) throw StateError('Could not save dismissed emergencies.');
      } finally {
        if (identical(_pendingSnapshots[key], snapshot)) {
          _pendingSnapshots.remove(key);
        }
      }
    });
    _pendingWrites = next.catchError((Object _) {});
    return next;
  }
}
