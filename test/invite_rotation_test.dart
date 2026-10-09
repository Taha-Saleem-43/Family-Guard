import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/settings/presentation/invite_rotation_control.dart';

void main() {
  test('invite expiry can clear and private codes reset across identities', () {
    final notifier = AppStateNotifier();
    addTearDown(notifier.dispose);
    notifier.setUserSession(
      userId: 'parent',
      circleId: 'a',
      role: UserRole.parent,
      childCode: 'child-secret',
      parentCode: 'parent-secret',
    );
    final withExpiry = notifier.state.copyWith(inviteExpiresAt: DateTime(2026));
    expect(withExpiry.copyWith(inviteExpiresAt: null).inviteExpiresAt, isNull);
    notifier.setUserId('other');
    expect(notifier.state.childInviteCode, isEmpty);
    expect(notifier.state.parentInviteCode, isEmpty);
    notifier.setInviteCodes(
      childCode: 'child-secret',
      parentCode: 'parent-secret',
    );
    notifier.setCircleId('b');
    expect(notifier.state.childInviteCode, isEmpty);
    expect(notifier.state.parentInviteCode, isEmpty);
  });

  testWidgets(
    'replacement requires confirmation and reports successful rotation',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith(
              (ref) => AppStateNotifier()
                ..setUserSession(
                  userId: 'parent',
                  circleId: 'circle',
                  role: UserRole.parent,
                ),
            ),
            inviteRotationProvider.overrideWithValue((circle) async {
              expect(circle, 'circle');
              calls++;
              return DateTime.now().add(const Duration(days: 7));
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: InviteRotationControl()),
          ),
        ),
      );
      await tester.tap(find.text('Replace invite codes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Replace invite codes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace codes'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text(
          'Previous codes are invalid. New codes expire in seven days.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('failed rotation offers honest retry feedback', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier()
              ..setUserSession(
                userId: 'parent',
                circleId: 'circle',
                role: UserRole.parent,
              ),
          ),
          inviteRotationProvider.overrideWithValue(
            (circle) async => throw StateError('timeout'),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: InviteRotationControl())),
      ),
    );
    await tester.tap(find.text('Replace invite codes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace codes'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not confirm code replacement'),
      findsOneWidget,
    );
    expect(
      find.text('Previous codes are invalid. New codes expire in seven days.'),
      findsNothing,
    );
  });
}
