import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/services/sharing_consent_service.dart';
import 'package:family_guard/features/onboarding/presentation/onboarding_screen.dart';
import 'package:family_guard/features/onboarding/presentation/permission_gate_screen.dart';

void main() {
  testWidgets('existing child confirms disclosure before permissions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = SharingConsentService(
      session: () => (uid: 'child', signedInAt: 100),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier()
              ..setUserSession(
                userId: 'child',
                circleId: 'family',
                role: UserRole.child,
              ),
          ),
        ],
        child: MaterialApp(home: OnboardingScreen(consentService: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Before sharing your location'), findsOneWidget);
    expect(find.byType(PermissionGateScreen), findsNothing);
    expect(await service.accepted('child', 'family'), isFalse);
    await tester.ensureVisible(find.text('I understand — Continue'));
    await tester.tap(find.text('I understand — Continue'));
    await tester.pumpAndSettle();
    expect(await service.accepted('child', 'family'), isTrue);
    expect(find.byType(PermissionGateScreen), findsOneWidget);
  });
}
