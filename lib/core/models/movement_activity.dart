import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum MovementActivity {
  stationary,
  walking,
  driving;

  String get label {
    switch (this) {
      case MovementActivity.stationary:
        return 'Stationary';
      case MovementActivity.walking:
        return 'Walking';
      case MovementActivity.driving:
        return 'Driving';
    }
  }

  String get emoji {
    switch (this) {
      case MovementActivity.stationary:
        return '🛑';
      case MovementActivity.walking:
        return '🚶';
      case MovementActivity.driving:
        return '🚗';
    }
  }

  IconData get icon {
    switch (this) {
      case MovementActivity.stationary:
        return Icons.pan_tool_rounded;
      case MovementActivity.walking:
        return Icons.directions_walk_rounded;
      case MovementActivity.driving:
        return Icons.directions_car_rounded;
    }
  }

  Color get color {
    switch (this) {
      case MovementActivity.stationary:
        return AppColors.sosRed;
      case MovementActivity.walking:
        return AppColors.teal;
      case MovementActivity.driving:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  Color get bgColor {
    switch (this) {
      case MovementActivity.stationary:
        return const Color(0xFFFEF2F2); // Red tint
      case MovementActivity.walking:
        return const Color(0xFFF0FDF4); // Teal tint
      case MovementActivity.driving:
        return const Color(0xFFF3E8FF); // Purple tint
    }
  }

  /// Parses movement activity from string name.
  static MovementActivity fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'walking':
        return MovementActivity.walking;
      case 'driving':
        return MovementActivity.driving;
      case 'stationary':
      default:
        return MovementActivity.stationary;
    }
  }

  /// Calculates movement activity from speed (in mph) and raw activity type.
  static MovementActivity fromSpeed(double speedMph, {String? rawActivity}) {
    final raw = rawActivity?.toLowerCase() ?? '';
    if (raw == 'in_vehicle' || raw == 'driving' || speedMph > 10.0) {
      return MovementActivity.driving;
    }
    if (raw == 'walking' ||
        raw == 'on_foot' ||
        raw == 'running' ||
        (speedMph > 0.5 && speedMph <= 10.0)) {
      return MovementActivity.walking;
    }
    return MovementActivity.stationary;
  }
}

class BatteryHelper {
  static String label(int batteryLevel) =>
      batteryLevel < 0 ? 'Unknown' : '$batteryLevel%';

  static Color getColor(int batteryLevel) {
    if (batteryLevel < 0) return Colors.grey;
    if (batteryLevel >= 50) return AppColors.teal;
    if (batteryLevel >= 20) return const Color(0xFFF59E0B); // Amber
    return AppColors.sosRed;
  }

  static IconData getIcon(int batteryLevel, {bool isCharging = false}) {
    if (batteryLevel < 0) return Icons.battery_unknown_rounded;
    if (isCharging) return Icons.battery_charging_full_rounded;
    if (batteryLevel >= 90) return Icons.battery_full_rounded;
    if (batteryLevel >= 60) return Icons.battery_5_bar_rounded;
    if (batteryLevel >= 40) return Icons.battery_4_bar_rounded;
    if (batteryLevel >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}
