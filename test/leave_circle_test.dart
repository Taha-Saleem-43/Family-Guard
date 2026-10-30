import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/member.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/settings/presentation/leave_circle_control.dart';

Member member(String id, UserRole role) => Member(
  id: id,
  name: id,
  role: role,
  avatar: '',
  address: '',
  lastSeen: DateTime(2026),
  batteryLevel: -1,
  speedMph: 0,
  movementActivity: MovementActivity.stationary,
);

void main() {
  Future<void> setup(
    WidgetTester tester, {
    required List<Member> members,
    required LeaveCircleAction action,
    AppStateNotifier? notifier,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            (ref) =>
                notifier ??
                (AppStateNotifier()..setUserSession(
                  userId: 'owner',
                  circleId: 'circle',
                  role: UserRole.parent,
                )),
          ),
          leaveCircleActionProvider.overrideWithValue(action),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: LeaveCircleControl(members: members)),
          ),
        ),
      ),
    );
  }

  testWidgets('active SOS blocks the action before pausing sharing', (
    tester,
  ) async {
    var calls = 0;
    await setup(
      tester,
      members: [member('owner', UserRole.parent).copyWith(isSosActive: true)],
      action: (_, _, _) async {
        calls++;
      },
    );
    await tester.tap(find.text('Leave circle'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.text('Resolve your active SOS before leaving the circle.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'last parent cannot confirm leaving children without a co-parent',
    (tester) async {
      var calls = 0;
      await setup(
        tester,
        members: [
          member('owner', UserRole.parent),
          member('child', UserRole.child),
        ],
        action: (_, _, _) async {
          calls++;
        },
      );
      await tester.tap(find.text('Leave circle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You are the last parent'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    },
  );

  testWidgets(
    'handoff needs an explicit co-parent selection and prevents duplicate requests',
    (tester) async {
      var calls = 0;
      final pending = Completer<void>();
      await setup(
        tester,
        members: [
          member('owner', UserRole.parent),
          member('co-parent', UserRole.parent),
          member('child', UserRole.child),
        ],
        action: (uid, circle, successor) {
          expect((uid, circle, successor), ('owner', 'circle', 'co-parent'));
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.text('Leave circle'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('co-parent'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave circle'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not confirm that you left'),
        findsOneWidget,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('account switch while confirming cancels the action', (
    tester,
  ) async {
    var calls = 0;
    final notifier = AppStateNotifier()
      ..setUserSession(
        userId: 'owner',
        circleId: 'circle',
        role: UserRole.parent,
      );
    await setup(
      tester,
      notifier: notifier,
      members: [member('owner', UserRole.parent)],
      action: (_, _, _) async {
        calls++;
      },
    );
    await tester.tap(find.text('Leave circle'));
    await tester.pumpAndSettle();
    notifier.setUserSession(
      userId: 'other',
      circleId: 'new',
      role: UserRole.parent,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Leave circle'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('confirmation scrolls at narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setup(
      tester,
      textScale: 2,
      members: [
        member('owner', UserRole.parent),
        member('co-parent', UserRole.parent),
      ],
      action: (_, _, _) async {},
    );
    await tester.tap(find.text('Leave circle'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel'), findsOneWidget);
  });

  test(
    'finishing departure clears private circle state and preserves the signed-in identity',
    () {
      final notifier = AppStateNotifier()
        ..setUserSession(
          userId: 'owner',
          userName: 'Owner',
          circleId: 'circle',
          role: UserRole.parent,
          parentCode: 'private-parent',
          childCode: 'private-child',
        );
      addTearDown(notifier.dispose);
      notifier.finishLeavingCircle('other', 'circle');
      expect(notifier.state.circleId, 'circle');
      notifier.finishLeavingCircle('owner', 'circle');
      expect(notifier.state.userId, 'owner');
      expect(notifier.state.userName, 'Owner');
      expect(notifier.state.stage, AppStage.onboarding);
      expect(notifier.state.circleId, isEmpty);
      expect(notifier.state.parentInviteCode, isEmpty);
      expect(notifier.state.childInviteCode, isEmpty);
      notifier.setUserSession(userId: 'owner', circleId: 'next');
      notifier.finishLeavingCircle('owner', 'circle');
      expect(notifier.state.circleId, 'next');
    },
  );
}
