import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/auth/domain/user_account_model.dart';

void main() {
  final account = UserAccountModel(
    uid: 'verified',
    email: 'user@example.com',
    displayName: 'Member',
    role: UserRole.child,
    circleId: 'circle',
    createdAt: DateTime.utc(2026),
  );
  test(
    'restores only the verified account returned by the identity boundary',
    () async {
      final notifier = AppStateNotifier(accountLoader: () async => account);
      addTearDown(notifier.dispose);
      expect(await notifier.checkRestoreSession(), isTrue);
      expect(notifier.state.userId, 'verified');
      expect(notifier.state.role, UserRole.child);
      expect(notifier.state.stage, AppStage.main);
    },
  );
  test('logout during restoration cannot resurrect a session', () async {
    final pending = Completer<UserAccountModel?>();
    final notifier = AppStateNotifier(accountLoader: () => pending.future);
    addTearDown(notifier.dispose);
    final restore = notifier.checkRestoreSession();
    notifier.resetToOnboarding();
    pending.complete(account);
    expect(await restore, isFalse);
    expect(notifier.state.userId, isEmpty);
  });
  test('rejects a requested UID mismatch', () async {
    final notifier = AppStateNotifier(accountLoader: () async => account);
    addTearDown(notifier.dispose);
    expect(await notifier.checkRestoreSession('someone-else'), isFalse);
  });
}
