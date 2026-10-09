import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Personal location data stays in memory. Native tracking storage has a
/// separate lifecycle; Firestore's disk cache must not outlive an account.
class FirestorePrivacyService {
  static void configureMemoryCache() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  static Future<void> prepareForeground() async {
    await FirestoreCacheMigration(
      configure: configureMemoryCache,
      clear: () => FirebaseFirestore.instance.clearPersistence(),
    ).prepare();
  }
}

class FirestoreCacheMigration {
  static const migrationKey = 'fg_firestore_memory_cache_migrated_v1';
  final void Function() configure;
  final Future<void> Function() clear;
  const FirestoreCacheMigration({required this.configure, required this.clear});

  Future<void> prepare() async {
    configure();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(migrationKey) == true) return;
    // Before the first query/listener, remove disk caches from older versions.
    // Never mark a failed cleanup complete. Later launches use memory only and
    // do not attempt to clear a client already running in a headless engine.
    await clear();
    if (!await prefs.setBool(migrationKey, true)) {
      throw StateError('Could not record private storage migration.');
    }
  }
}
