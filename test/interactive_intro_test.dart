import 'package:family_guard/features/onboarding/presentation/interactive_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demos are local and account actions stay directly reachable', (
    tester,
  ) async {
    var starts = 0;
    var signIns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: InteractiveIntro(
              onStart: () => starts++,
              onSignIn: () => signIns++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'SOS'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'SOS'));
    await tester.pumpAndSettle();
    final preview = find.text('Preview an SOS alert');
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await tester.pumpAndSettle();
    expect(find.text('DEMO · NO LIVE DATA'), findsOneWidget);
    expect(starts, 0);
    expect(signIns, 0);
    expect(find.byTooltip('Pause introduction'), findsNothing);
    final start = find.widgetWithText(ElevatedButton, 'Get started');
    await tester.ensureVisible(start);
    await tester.tap(start);
    expect(starts, 1);
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    expect(signIns, 1);
    expect(tester.takeException(), isNull);
  });
}
