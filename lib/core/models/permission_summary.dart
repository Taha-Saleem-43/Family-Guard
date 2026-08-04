/// Snapshot of all permission states required by FamilyGuard.
/// Created during onboarding and re-read by the Settings permission dashboard.
class PermissionSummary {
  /// True if ACCESS_FINE_LOCATION was granted (foreground).
  final bool foregroundLocation;

  /// True if ACCESS_BACKGROUND_LOCATION was granted ("Allow all the time").
  /// When false the app operates in degraded foreground-only mode.
  final bool backgroundLocation;

  /// True if POST_NOTIFICATIONS was granted (Android 13+).
  final bool notifications;

  /// True if the battery-optimization exemption was granted
  /// (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).
  final bool batteryOptimization;

  const PermissionSummary({
    required this.foregroundLocation,
    required this.backgroundLocation,
    required this.notifications,
    required this.batteryOptimization,
  });

  /// All critical permissions (foreground + background) are granted.
  bool get isFullyGranted => foregroundLocation && backgroundLocation;

  /// Foreground location is granted but background is not — degraded mode.
  bool get isDegraded => foregroundLocation && !backgroundLocation;

  /// Minimum viable: at least foreground location granted.
  bool get canOperate => foregroundLocation;

  PermissionSummary copyWith({
    bool? foregroundLocation,
    bool? backgroundLocation,
    bool? notifications,
    bool? batteryOptimization,
  }) {
    return PermissionSummary(
      foregroundLocation: foregroundLocation ?? this.foregroundLocation,
      backgroundLocation: backgroundLocation ?? this.backgroundLocation,
      notifications: notifications ?? this.notifications,
      batteryOptimization: batteryOptimization ?? this.batteryOptimization,
    );
  }

  @override
  String toString() =>
      'PermissionSummary(fg=$foregroundLocation, bg=$backgroundLocation, '
      'notif=$notifications, battery=$batteryOptimization)';
}
