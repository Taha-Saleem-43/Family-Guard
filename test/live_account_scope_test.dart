import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/account_scope.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';

void main() {
  test(
    'live role changes clear private scope and pause sharing before re-consent',
    () async {
      final stream = StreamController<AccountScope>();
      final stopped = <String>[];
      final notifier = AppStateNotifier(
        profileStream: (_) => stream.stream,
        currentUid: () => 'member',
        stopSharing: (uid) async => stopped.add(uid),
      );
      notifier.setUserSession(
        userId: 'member',
        circleId: 'family',
        role: UserRole.parent,
        childCode: 'private-child',
        parentCode: 'private-parent',
      );
      notifier.completeOnboarding(UserRole.parent);
      notifier.setActiveTab(AppTab.history);
      stream.add(
        const AccountScope(
          uid: 'member',
          role: UserRole.child,
          circleId: 'family',
          name: 'Child',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.stage, AppStage.onboarding);
      expect(notifier.state.role, UserRole.child);
      expect(notifier.state.parentInviteCode, isEmpty);
      expect(notifier.state.activeTab, AppTab.map);
      expect(stopped, ['member']);
      notifier.dispose();
      await stream.close();
    },
  );
  test(
    'old account and signed-out snapshots cannot mutate a newer session',
    () async {
      final streams = {
        'old': StreamController<AccountScope>(),
        'new': StreamController<AccountScope>(),
      };
      String? uid = 'old';
      final stopped = <String>[];
      final notifier = AppStateNotifier(
        profileStream: (id) => streams[id]!.stream,
        currentUid: () => uid,
        stopSharing: (id) async => stopped.add(id),
      );
      notifier.setUserSession(
        userId: 'old',
        circleId: 'one',
        role: UserRole.child,
      );
      notifier.completeOnboarding(UserRole.child);
      uid = 'new';
      notifier.setUserSession(
        userId: 'new',
        circleId: 'two',
        role: UserRole.parent,
      );
      notifier.completeOnboarding(UserRole.parent);
      streams['old']!.add(
        const AccountScope(
          uid: 'old',
          role: UserRole.child,
          circleId: '',
          name: 'Old',
          available: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.userId, 'new');
      expect(notifier.state.stage, AppStage.main);
      uid = null;
      streams['new']!.add(
        const AccountScope(
          uid: 'new',
          role: UserRole.parent,
          circleId: '',
          name: 'New',
          available: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.stage, AppStage.main);
      expect(stopped, isEmpty);
      notifier.dispose();
      for (final stream in streams.values) {
        await stream.close();
      }
    },
  );
  test(
    'deleted profiles block access while a name change preserves the active page',
    () async {
      final stream = StreamController<AccountScope>();
      final notifier = AppStateNotifier(
        profileStream: (_) => stream.stream,
        currentUid: () => 'member',
        stopSharing: (_) async {},
      );
      notifier.setUserSession(
        userId: 'member',
        circleId: 'family',
        role: UserRole.child,
      );
      notifier.completeOnboarding(UserRole.child);
      notifier.setActiveTab(AppTab.settings);
      stream.add(
        const AccountScope(
          uid: 'member',
          role: UserRole.child,
          circleId: 'family',
          name: 'Updated',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.userName, 'Updated');
      expect(notifier.state.activeTab, AppTab.settings);
      stream.add(AccountScope.fromServer('member', null));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.accountUnavailable, true);
      expect(notifier.state.circleId, isEmpty);
      notifier.dispose();
      await stream.close();
    },
  );
}
