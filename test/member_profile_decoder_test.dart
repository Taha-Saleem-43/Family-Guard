import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_guard/core/services/member_profile_decoder.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9);
  test('accuracy is optional, bounded and belongs to valid coordinates', () {
    for (final accuracy in [null, -1, 101, double.nan, 'precise', 12.5]) {
      final member = MemberProfileDecoder.decode(
        'child',
        {
          'latitude': 33,
          'longitude': 73,
          'accuracyMeters': accuracy,
          'lastSeen': now.toIso8601String(),
        },
        currentUid: 'parent',
        now: now,
      );
      expect(member.accuracyMeters, accuracy == 12.5 ? 12.5 : null);
      expect(
        member.copyWith(batteryLevel: 90).accuracyMeters,
        member.accuracyMeters,
      );
    }
    expect(
      MemberProfileDecoder.decode(
        'child',
        {'accuracyMeters': 12},
        currentUid: 'parent',
        now: now,
      ).accuracyMeters,
      null,
    );
  });
  test('freshness checks preserve state unless a stale status changes', () {
    final first = MemberProfileDecoder.decode(
      'first',
      {'latitude': 33, 'longitude': 73, 'lastSeen': now.toIso8601String()},
      currentUid: 'first',
      now: now,
    );
    final second = MemberProfileDecoder.decode(
      'second',
      {
        'latitude': 34,
        'longitude': 74,
        'lastSeen': now.add(const Duration(minutes: 5)).toIso8601String(),
      },
      currentUid: 'first',
      now: now.add(const Duration(minutes: 5)),
    );
    final members = [first, second];
    expect(
      identical(
        MemberProfileDecoder.ageMembers(
          members,
          now.add(const Duration(minutes: 10)),
        ),
        members,
      ),
      true,
    );
    final aged = MemberProfileDecoder.ageMembers(
      members,
      now.add(const Duration(minutes: 16)),
    );
    expect(identical(aged, members), false);
    expect(aged.first.isStale, true);
    expect(identical(aged.last, second), true);
    expect(
      identical(
        MemberProfileDecoder.ageMembers(
          aged,
          now.add(const Duration(minutes: 17)),
        ),
        aged,
      ),
      true,
    );
  });
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
