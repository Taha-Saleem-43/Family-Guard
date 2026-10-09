import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracelet/tracelet.dart' as tl;
import 'location_sync_service.dart';
import 'tracking_lifecycle.dart';

/// Owns native tracking lifecycle and forwards fixes to the shared sync service.
/// Diagnostic fix logging is bounded and enabled only in debug builds.
class LocationService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  LocationService._();
  static final LocationService instance = LocationService._();

  // ── Internal state ─────────────────────────────────────────────────────────
  bool _isReady = false;
  bool _subscribed = false;
  Future<void>? _initializing;
  Timer? _retryTimer;
  String? _retryTimerUid;
  int? _verifiedAuthTime;
  late final _lifecycle = TrackingLifecycle(
    currentUid: () => FirebaseAuth.instance.currentUser?.uid,
    verifyScope: (uid, circleId) async {
      if (FirebaseAuth.instance.currentUser?.metadata.lastSignInTime == null) {
        return false;
      }
      final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult();
      if (FirebaseAuth.instance.currentUser?.uid != uid ||
          token.authTime == null) {
        return false;
      }
      final signedInAt = FirebaseAuth
          .instance
          .currentUser!
          .metadata
          .lastSignInTime!
          .millisecondsSinceEpoch;
      final authTime = token.authTime!.millisecondsSinceEpoch;
      _verifiedAuthTime = signedInAt > authTime ? signedInAt : authTime;
      final db = FirebaseFirestore.instance;
      final profile = await db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (FirebaseAuth.instance.currentUser?.uid != uid) return false;
      final data = profile.data();
      if (data == null ||
          data['role'] != 'child' ||
          data['circleId'] != circleId ||
          data['deletionRequested'] == true) {
        return false;
      }
      final circle = await db
          .collection('circles')
          .doc(circleId)
          .get(const GetOptions(source: Source.server));
      return circle.exists &&
          (circle.data()?['memberIds'] is List) &&
          (circle.data()!['memberIds'] as List).contains(uid);
    },
    activate: (uid, circle) async {
      await LocationSyncService.outbox.activate(
        uid,
        circle,
        DateTime.now().millisecondsSinceEpoch,
        minimumStartedAt: _verifiedAuthTime!,
      );
    },
    deactivate: (uid) => LocationSyncService.outbox.deactivate(uid),
    startNative: () async {
      await tl.Tracelet.start();
    },
    stopNative: () async {
      await tl.Tracelet.stop();
    },
  );

  bool get isReady => _isReady;
  bool get isTracking => _lifecycle.activeScope != null;

  // ── SharedPreferences key ──────────────────────────────────────────────────
  static const _logKey = 'fg_location_log';
  static const _maxLogEntries = 200;

  // ── Initialise ─────────────────────────────────────────────────────────────

  /// Call once, from [main()] after [Tracelet.registerHeadlessTask()].
  /// Safe to call multiple times — no-ops if already ready.
  Future<void> init() {
    if (_isReady) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    // Subscribe to foreground location events before calling ready().
    if (!_subscribed) {
      _subscribed = true;
      tl.Tracelet.onLocation((tl.Location loc) async {
        try {
          await appendDebugLog(loc, source: 'FOREGROUND');
        } catch (_) {
          /* Diagnostics do not block persistence. */
        }
        try {
          await LocationSyncService.ingest(loc);
        } catch (_) {
          debugPrint(
            '[LocationService] Persistence failed; recovery will retry.',
          );
        }
      });

      // Subscribe to motion-change events (stationary ↔ moving transitions).
      tl.Tracelet.onMotionChange((tl.Location loc) {
        unawaited(LocationSyncService.ingest(loc).catchError((Object _) {}));
      });
      tl.Tracelet.onConnectivityChange((event) {
        unawaited(LocationSyncService.flush().catchError((Object _) {}));
      });
    }

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
    await _lifecycle.start(uid, circleId);
    if (_lifecycle.activeScope != (uid: uid, circleId: circleId)) return;
    _retryTimer?.cancel();
    _retryTimerUid = uid;
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(LocationSyncService.recover().catchError((Object _) {}));
    });
    unawaited(LocationSyncService.recover().catchError((Object _) {}));
  }

  Future<void> stop({String? expectedUid}) async {
    final uid = expectedUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (_retryTimerUid == uid || uid == null) {
      _retryTimer?.cancel();
      _retryTimerUid = null;
    }
    await _lifecycle.stop(uid);
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
