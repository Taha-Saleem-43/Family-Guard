import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/core/services/user_session_service.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/settings/presentation/account_deletion_control.dart';
import 'package:family_guard/features/auth/services/account_deletion_service.dart';

void main() {
  testWidgets('an account switch during confirmation cancels deletion', (
    tester,
  ) async {
    final state = AppStateNotifier();
    state.setUserSession(userId: 'first', circleId: '');
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith((ref) => state),
          accountDeletionActionProvider.overrideWithValue((
            uid,
            password,
          ) async {
            requests++;
            return const AccountDeletionReceipt(localCleanupComplete: true);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AccountDeletionControl()),
        ),
      ),
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    state.setUserSession(userId: 'second', circleId: '');
    await tester.tap(find.text('Request deletion'));
    await tester.pumpAndSettle();
    expect(requests, 0);
  });
  test('local deletion preserves similarly prefixed accounts', () async {
    SharedPreferences.setMockInitialValues({
      'fg_active_user_uid': 'a_b',
      'fg_push_token_account_uid': 'a_b',
      'fg_user_session_a_role': 'parent',
      'fg_user_session_a_b_role': 'child',
      'sos.dismissed.a.circle': ['old'],
      'sos.dismissed.a.b.circle': ['keep'],
    });
    await UserSessionService.deleteUserSession('a');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('fg_user_session_a_role'), false);
    expect(prefs.containsKey('sos.dismissed.a.circle'), false);
    expect(prefs.getString('fg_user_session_a_b_role'), 'child');
    expect(prefs.getStringList('sos.dismissed.a.b.circle'), ['keep']);
    expect(prefs.getString('fg_active_user_uid'), 'a_b');
    expect(prefs.getString('fg_push_token_account_uid'), 'a_b');
  });
  testWidgets('cancel does not request deletion; confirmation verifies once', (
    tester,
  ) async {
    final state = AppStateNotifier(accountLoader: () async => null);
    state.setUserSession(userId: 'test-user', circleId: '');
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith((ref) => state),
          accountDeletionActionProvider.overrideWithValue((
            uid,
            password,
          ) async {
            expect(uid, 'test-user');
            expect(password, 'secret');
            requests++;
            return const AccountDeletionReceipt(localCleanupComplete: true);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AccountDeletionControl()),
        ),
      ),
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('Request deletion'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.textContaining('Account deletion requested.'), findsOneWidget);
  });
  test(
    'verification failure never stops sharing or submits deletion',
    () async {
      final calls = <String>[];
      final service = AccountDeletionService(
        verify: (_, _) async => throw StateError('private credential error'),
        pauseSharing: (_) async => calls.add('pause'),
        enqueue: (_) async {
          calls.add('enqueue');
          return true;
        },
        clearLocal: (_) async => calls.add('clear'),
        signOut: (_) async => calls.add('signOut'),
      );
      await expectLater(
        service.request('uid', 'password'),
        throwsA(isA<AccountDeletionFailure>()),
      );
      expect(calls, isEmpty);
    },
  );
  test(
    'accepted deletion survives local cleanup failure and attempts sign-out',
    () async {
      final calls = <String>[];
      final service = AccountDeletionService(
        verify: (_, _) async => calls.add('verify'),
        pauseSharing: (_) async => calls.add('pause'),
        enqueue: (_) async {
          calls.add('enqueue');
          return true;
        },
        clearLocal: (_) async {
          calls.add('clear');
          throw StateError('disk');
        },
        signOut: (_) async => calls.add('signOut'),
      );
      final receipt = await service.request('uid', 'password');
      expect(receipt.localCleanupComplete, false);
      expect(calls, ['verify', 'pause', 'enqueue', 'clear', 'signOut']);
    },
  );
}
