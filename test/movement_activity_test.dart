import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/theme/app_colors.dart';

void main() {
  group('MovementActivity & BatteryHelper Domain Tests', () {
    test('fromSpeed correctly categorizes activities based on speed and raw string', () {
      expect(MovementActivity.fromSpeed(0.0), equals(MovementActivity.stationary));
      expect(MovementActivity.fromSpeed(3.0), equals(MovementActivity.walking));
      expect(MovementActivity.fromSpeed(25.0), equals(MovementActivity.driving));

      expect(
        MovementActivity.fromSpeed(0.0, rawActivity: 'IN_VEHICLE'),
        equals(MovementActivity.driving),
      );
      expect(
        MovementActivity.fromSpeed(0.0, rawActivity: 'ON_FOOT'),
        equals(MovementActivity.walking),
      );
    });

    test('fromString safely parses string representation', () {
      expect(MovementActivity.fromString('walking'), equals(MovementActivity.walking));
      expect(MovementActivity.fromString('DRIVING'), equals(MovementActivity.driving));
      expect(MovementActivity.fromString('stationary'), equals(MovementActivity.stationary));
      expect(MovementActivity.fromString(null), equals(MovementActivity.stationary));
      expect(MovementActivity.fromString('unknown_state'), equals(MovementActivity.stationary));
    });

    test('BatteryHelper returns appropriate colors and icons for levels', () {
      expect(BatteryHelper.getColor(85), equals(AppColors.teal));
      expect(BatteryHelper.getColor(35), equals(const Color(0xFFF59E0B)));
      expect(BatteryHelper.getColor(10), equals(AppColors.sosRed));

      expect(BatteryHelper.getIcon(90), equals(Icons.battery_full_rounded));
      expect(BatteryHelper.getIcon(50, isCharging: true), equals(Icons.battery_charging_full_rounded));
    });
  });
}
