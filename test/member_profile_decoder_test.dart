import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_guard/core/services/member_profile_decoder.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9);
  test(
    'malformed legacy member values remain readable without invented coordinates or battery',
    () {
      final member = MemberProfileDecoder.decode(
        'child',
        {
          'displayName': [],
          'latitude': double.nan,
          'longitude': 'invalid',
          'speedMph': double.infinity,
          'batteryLevel': 101,
          'isCharging': 'yes',
          'movementActivity': 42,
          'lastSeen': false,
          'isSosActive': 'true',
        },
        currentUid: 'parent',
        now: now,
      );
      expect(member.name, 'Family Member');
      expect(member.latitude, isNull);
      expect(member.longitude, isNull);
      expect(member.batteryLevel, -1);
      expect(BatteryHelper.label(member.batteryLevel), 'Unknown');
      expect(member.isCharging, false);
      expect(member.isSosActive, false);
      expect(member.isStale, true);
    },
  );
  test(
    'coordinate pairs are rejected together when incomplete or outside Earth bounds',
    () {
      for (final data in [
        {'latitude': 10},
        {'latitude': 91, 'longitude': 10},
      ]) {
        final member = MemberProfileDecoder.decode(
          'uid',
          data,
          currentUid: 'uid',
          now: now,
        );
        expect(member.latitude, isNull);
        expect(member.longitude, isNull);
      }
    },
  );
  test(
    'clock-ahead and aging locations become stale without additional database reads',
    () {
      expect(MemberProfileDecoder.isFresh(now, now), true);
      expect(
        MemberProfileDecoder.isFresh(now, now.add(const Duration(minutes: 16))),
        false,
      );
      expect(
        MemberProfileDecoder.isFresh(now.add(const Duration(minutes: 2)), now),
        false,
      );
      for (final value in [Timestamp.fromDate(now), now.toIso8601String()]) {
        final member = MemberProfileDecoder.decode(
          'uid',
          {
            'latitude': 33,
            'longitude': 73,
            'lastSeen': value,
            'batteryLevel': 80,
          },
          currentUid: 'uid',
          now: now,
        );
        expect(member.isStale, false);
        expect(member.batteryLevel, 80);
      }
    },
  );
}
