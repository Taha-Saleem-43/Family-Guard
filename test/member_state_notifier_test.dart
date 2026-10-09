import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      expect(members.first.isStale, isTrue);
      expect(members.first.lastSeen.millisecondsSinceEpoch, 0);
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
