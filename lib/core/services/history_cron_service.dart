import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_location_service.dart';

/// Client-side Cron service to automatically purge historical data > 30 days old.
class HistoryCronService {
  HistoryCronService._();
  static final HistoryCronService instance = HistoryCronService._();

  static const String _lastPurgeKey = 'fg_last_history_purge_timestamp';
  final FirestoreLocationService _firestoreLocationService = FirestoreLocationService();

  Timer? _periodicTimer;
  bool _isPurging = false;

  /// Initializes the client-side cron timer.
  /// Runs purge check immediately on startup and schedules a 12-hour periodic timer.
  void initCronJob(String uid) {
    if (uid.isEmpty) return;

    // Run startup check
    runPurgeIfNeeded(uid: uid);

    // Schedule 12-hour periodic check
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(hours: 12), (_) {
      runPurgeIfNeeded(uid: uid);
    });
  }

  /// Triggers retention purge if more than 12 hours have passed since last cleanup
  Future<int> runPurgeIfNeeded({required String uid, bool force = false}) async {
    if (uid.isEmpty || _isPurging) return 0;

    _isPurging = true;
    int deletedCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPurgeMillis = prefs.getInt(_lastPurgeKey) ?? 0;
      final lastPurgeDate = DateTime.fromMillisecondsSinceEpoch(lastPurgeMillis);
      final now = DateTime.now();

      final hoursSinceLastPurge = now.difference(lastPurgeDate).inHours;

      if (force || hoursSinceLastPurge >= 12) {
        debugPrint('[HistoryCronService] Running 30-day data retention cleanup for user: $uid...');
        deletedCount = await _firestoreLocationService.purgeExpiredDocuments(uid: uid, retentionDays: 30);
        await prefs.setInt(_lastPurgeKey, now.millisecondsSinceEpoch);
        debugPrint('[HistoryCronService] Retention cleanup complete. Purged $deletedCount documents.');
      }
    } catch (e) {
      debugPrint('[HistoryCronService] Error executing retention cleanup: $e');
    } finally {
      _isPurging = false;
    }

    return deletedCount;
  }

  /// Gets the last purge execution timestamp
  Future<DateTime?> getLastPurgeDate() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastPurgeKey);
    if (millis == null || millis == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }
}
