import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracelet/tracelet.dart' as tl;
import 'location_sync_service.dart';

/// Owns native tracking lifecycle and forwards fixes to the shared sync service.
/// Diagnostic fix logging is bounded and enabled only in debug builds.
class LocationService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  LocationService._();
  static final LocationService instance = LocationService._();

  // ── Internal state ─────────────────────────────────────────────────────────
  bool _isReady = false;
  bool _isTracking = false;
  Timer? _retryTimer;

  bool get isReady => _isReady;
  bool get isTracking => _isTracking;

  // ── SharedPreferences key ──────────────────────────────────────────────────
  static const _logKey = 'fg_location_log';
  static const _maxLogEntries = 200;

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Call once, from [main()] after [Tracelet.registerHeadlessTask()].
  /// Safe to call multiple times — no-ops if already ready.
  Future<void> init() async {
    if (_isReady) return;

    // Subscribe to foreground location events before calling ready().
    tl.Tracelet.onLocation((tl.Location loc) async {
      await appendDebugLog(loc, source: 'FOREGROUND');
      await LocationSyncService.ingest(loc);
    });

    // Subscribe to motion-change events (stationary ↔ moving transitions).
    tl.Tracelet.onMotionChange((tl.Location loc) {
      unawaited(LocationSyncService.ingest(loc));
    });
    tl.Tracelet.onConnectivityChange((event) {
      unawaited(LocationSyncService.flush());
    });

    await tl.Tracelet.ready(
      tl.Config.balanced().copyWith(
        geo: const tl.GeoConfig(
          desiredAccuracy: tl.DesiredAccuracy.high,
          // 10-metre filter = ignore minor static GPS drift on-device.
          distanceFilter: 10.0,
        ),
        app: const tl.AppConfig(
          // Keep tracking when user swipes app away or reboots device.
          stopOnTerminate: false,
          startOnBoot: true,
        ),
        motion: const tl.MotionConfig(
          // 0 = no stationary timeout — Tracelet decides when to stop.
          stopTimeout: 0,
        ),
        persistence: const tl.PersistenceConfig(
          maxDaysToPersist: 7,
          maxRecordsToPersist: 5000,
        ),
        android: const tl.AndroidConfig(
          foregroundService: tl.ForegroundServiceConfig(
            notificationTitle: 'FamilyGuard',
            notificationText: 'Sharing your location with your Circle',
          ),
        ),
        logger: tl.LoggerConfig(
          // Verbose logging in debug only — silent in release builds.
          debug: _isDebugBuild(),
          logLevel: _isDebugBuild() ? tl.LogLevel.verbose : tl.LogLevel.off,
        ),
      ),
    );

    _isReady = true;
  }

  // ── Start / Stop ──────────────────────────────────────────────────────────

  Future<void> start({required String uid, required String circleId}) async {
    if (!_isReady || FirebaseAuth.instance.currentUser?.uid != uid) return;
    await LocationSyncService.outbox.activate(
      uid,
      circleId,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      await LocationSyncService.outbox.deactivate(uid);
      return;
    }
    await tl.Tracelet.start();
    _isTracking = true;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(LocationSyncService.recover().catchError((Object _) {}));
    });
    unawaited(LocationSyncService.recover().catchError((Object _) {}));
  }

  Future<void> stop() async {
    _retryTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await LocationSyncService.outbox.deactivate(uid);
    // Native tracking may already be running after a process restart.
    await tl.Tracelet.stop();
    _isTracking = false;
  }

  // ── Event subscriptions (thin wrappers) ───────────────────────────────────

  /// Subscribe to foreground location fixes.
  /// Callback fires on every fix while the app is in the foreground.
  StreamSubscription<tl.Location> onLocation(
    void Function(tl.Location) callback,
  ) => tl.Tracelet.onLocation(callback);

  /// Subscribe to moving ↔ stationary transitions.
  StreamSubscription<tl.Location> onMotionChange(
    void Function(tl.Location) callback,
  ) => tl.Tracelet.onMotionChange(callback);

  // ── Health check ──────────────────────────────────────────────────────────

  /// Returns Tracelet's internal health snapshot.
  /// Used by the Settings permission dashboard and for OEM battery prompts.
  /// Return type is [tl.HealthCheck] (exported from tracelet/src/models/health_check.dart).
  Future<tl.HealthCheck> getHealth() => tl.Tracelet.getHealth();

  /// Opens the device battery-settings screen (OEM-specific power manager).
  Future<void> openBatterySettings() => tl.Tracelet.openBatterySettings();

  // ── Debug log (local only — no Firestore) ─────────────────────────────────

  /// Appends a single timestamped entry to SharedPreferences.
  /// Called from both the foreground callback and the headless top-level function.
  ///
  /// Format matches the spike exactly:
  ///   `2026-08-04 14:22:01 | FOREGROUND | lat=33.123456 lng=73.654321 acc=8.0m spd=0.0m/s`
  static Future<void> appendDebugLog(
    tl.Location location, {
    String source = 'FOREGROUND',
  }) async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final lat = location.coords.latitude.toStringAsFixed(6);
    final lng = location.coords.longitude.toStringAsFixed(6);
    final acc = location.coords.accuracy.toStringAsFixed(1);
    final spd = location.coords.speed.toStringAsFixed(1);
    final entry =
        '$stamp | $source | lat=$lat lng=$lng acc=${acc}m spd=${spd}m/s';

    final log = prefs.getStringList(_logKey) ?? [];
    log.add(entry);
    // Cap log size to avoid unbounded growth during 8-hour runs.
    if (log.length > _maxLogEntries) {
      log.removeRange(0, log.length - _maxLogEntries);
    }
    await prefs.setStringList(_logKey, log);
  }

  /// Returns the full debug log (newest-first for display).
  static Future<List<String>> readDebugLog() async {
    final prefs = await SharedPreferences.getInstance();
    final log = prefs.getStringList(_logKey) ?? [];
    return log.reversed.toList();
  }

  /// Clears the local debug log.
  static Future<void> clearDebugLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_logKey, []);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// True when running in a Flutter debug build.
  static bool _isDebugBuild() {
    bool result = false;
    assert(() {
      result = true;
      return true;
    }());
    return result;
  }
}
