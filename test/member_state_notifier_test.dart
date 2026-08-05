import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/member_status_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemberStateNotifier Unit Tests', () {
    test('Initial state contains self member', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final members = container.read(memberStateProvider);
      expect(members.length, greaterThanOrEqualTo(1));
      expect(members.first.id, equals('m_self'));
    });

    test('cycleMemberActivity toggles activity states correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(memberStateProvider.notifier);
      final initialMember = container.read(memberStateProvider).first;
      expect(initialMember.movementActivity, equals(MovementActivity.stationary));

      notifier.cycleMemberActivity(initialMember.id);
      final walkingMember = container.read(memberStateProvider).first;
      expect(walkingMember.movementActivity, equals(MovementActivity.walking));

      notifier.cycleMemberActivity(initialMember.id);
      final drivingMember = container.read(memberStateProvider).first;
      expect(drivingMember.movementActivity, equals(MovementActivity.driving));

      notifier.cycleMemberActivity(initialMember.id);
      final resetMember = container.read(memberStateProvider).first;
      expect(resetMember.movementActivity, equals(MovementActivity.stationary));
    });

    test('setMemberBattery updates target member battery level', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(memberStateProvider.notifier);
      notifier.setMemberBattery('m_self', 14, isCharging: true);

      final updated = container.read(memberStateProvider).first;
      expect(updated.batteryLevel, equals(14));
      expect(updated.isCharging, isTrue);
    });
  });
}
