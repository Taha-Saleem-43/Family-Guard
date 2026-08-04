import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/permission_summary.dart';

/// Handles all runtime permission requests in the correct sequence.
///
/// **Sequence contract (must be respected by callers):**
///   1. [requestForegroundLocation] — always first
///   2. [requestBackgroundLocation] — only after (1) returns GRANTED
///   3. [requestNotifications]
///   4. [requestBatteryOptimization]
///
/// Violating the order causes an [AssertionError] in debug builds and a
/// [StateError] in release builds, satisfying test-case T1 from the plan.
class PermissionService {
  // ── OEM detection ─────────────────────────────────────────────────────────

  /// Returns true if the device is made by an OEM known to aggressively kill
  /// background processes and requires a manual auto-start setting.
  Future<bool> get requiresOemAutoStartStep async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    const oemList = [
      'samsung',
      'xiaomi',
      'redmi',
      'oppo',
      'huawei',
      'honor',
      'vivo',
      'realme',
      'oneplus',
    ];
    final manufacturer = info.manufacturer.toLowerCase();
    return oemList.any((oem) => manufacturer.contains(oem));
  }

  // ── Permission requests ────────────────────────────────────────────────────

  /// Step 1 — Request ACCESS_FINE_LOCATION.
  /// Must be called first. Returns the resulting [PermissionStatus].
  Future<PermissionStatus> requestForegroundLocation() async {
    final status = await Permission.location.request();
    return status;
  }

  /// Step 2 — Request ACCESS_BACKGROUND_LOCATION ("Allow all the time").
  ///
  /// [foregroundGranted] must be true before this is called.
  /// Throws [AssertionError] in debug / [StateError] in release if violated.
  Future<PermissionStatus> requestBackgroundLocation({
    required bool foregroundGranted,
  }) async {
    assert(
      foregroundGranted,
      'requestBackgroundLocation() called before foreground location was '
      'granted. Fix the call-site order — this is test-case T1.',
    );
    if (!foregroundGranted) {
      throw StateError(
        'requestBackgroundLocation() requires foreground location to be '
        'granted first.',
      );
    }
    final status = await Permission.locationAlways.request();
    return status;
  }

  /// Step 3 — Request POST_NOTIFICATIONS (Android 13+, no-op on older).
  Future<PermissionStatus> requestNotifications() async {
    final status = await Permission.notification.request();
    return status;
  }

  /// Step 4 — Request battery-optimization exemption.
  Future<PermissionStatus> requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status;
  }

  // ── Status queries (no dialogs) ────────────────────────────────────────────

  /// Returns the current permission status without showing any dialog.
  Future<PermissionStatus> foregroundLocationStatus() =>
      Permission.location.status;

  Future<PermissionStatus> backgroundLocationStatus() =>
      Permission.locationAlways.status;

  Future<PermissionStatus> notificationStatus() =>
      Permission.notification.status;

  Future<PermissionStatus> batteryOptimizationStatus() =>
      Permission.ignoreBatteryOptimizations.status;

  // ── Summary (used by Settings screen in Step 13) ───────────────────────────

  /// Reads the current status of all four permissions without requesting them.
  Future<PermissionSummary> getPermissionSummary() async {
    final results = await Future.wait([
      Permission.location.status,
      Permission.locationAlways.status,
      Permission.notification.status,
      Permission.ignoreBatteryOptimizations.status,
    ]);

    return PermissionSummary(
      foregroundLocation: results[0].isGranted,
      backgroundLocation: results[1].isGranted,
      notifications: results[2].isGranted,
      batteryOptimization: results[3].isGranted,
    );
  }

  // ── Deep-link to system settings ──────────────────────────────────────────

  /// Opens the app's system settings page so the user can manually grant
  /// a permission that was permanently denied.
  Future<bool> openSystemAppSettings() => openAppSettings();
}
