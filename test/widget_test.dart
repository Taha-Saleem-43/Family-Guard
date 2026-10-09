// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:family_guard/main.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';

class _BlockedAccount extends AppStateNotifier {
  _BlockedAccount() {
    state = state.copyWith(userId: 'blocked', accountUnavailable: true);
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('FamilyGuardApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FamilyGuardApp()));

    await tester.pumpAndSettle();
    expect(find.text('FamilyGuard'), findsOneWidget);
  });

  testWidgets('unavailable accounts retain deletion and sign-out controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStateProvider.overrideWith((ref) => _BlockedAccount())],
        child: const FamilyGuardApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
  });

  testWidgets('verification failures retain account management controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier(
              accountLoader: () async => throw StateError('offline'),
            ),
          ),
        ],
        child: const FamilyGuardApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
