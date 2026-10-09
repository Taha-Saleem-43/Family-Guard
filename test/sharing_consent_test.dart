import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/core/services/sharing_consent_service.dart';
import 'package:family_guard/core/services/user_session_service.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/auth/domain/user_account_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('consent belongs to the device account, circle and sign-in', () async {
    ConsentSession? session = (uid: 'child', signedInAt: 100);
    final service = SharingConsentService(session: () => session);
    expect(await service.accepted('child', 'family'), isFalse);
    await service.accept('child', 'family');
    expect(await service.accepted('child', 'family'), isTrue);
    expect(await service.accepted('child', 'other'), isFalse);
    session = (uid: 'other', signedInAt: 100);
    expect(await service.accepted('child', 'family'), isFalse);
    session = (uid: 'child', signedInAt: 101);
    expect(await service.accepted('child', 'family'), isFalse);
    session = null;
    await expectLater(service.accept('child', 'family'), throwsStateError);
  });
  test('logout clears consent without erasing a different account', () async {
    var session = (uid: 'child', signedInAt: 100);
    final service = SharingConsentService(session: () => session);
    await service.accept('child', 'family');
    session = (uid: 'other', signedInAt: 200);
    await service.accept('other', 'family');
    await UserSessionService.clearUserSession('child');
    expect(await service.accepted('other', 'family'), isTrue);
    session = (uid: 'child', signedInAt: 100);
    expect(await service.accepted('child', 'family'), isFalse);
  });
  test(
    'a restored child stays at disclosure until device consent exists',
    () async {
      final child = UserAccountModel(
        uid: 'child',
        email: 'child@example.com',
        displayName: 'Child',
        role: UserRole.child,
        circleId: 'family',
        createdAt: DateTime.utc(2026),
      );
      final state = AppStateNotifier(
        accountLoader: () async => child,
        sharingConsent: (_, _) async => false,
      );
      addTearDown(state.dispose);
      expect(await state.checkRestoreSession(), isFalse);
      expect(state.state.userId, 'child');
      expect(state.state.circleId, 'family');
      expect(state.state.stage, AppStage.onboarding);
    },
  );
}
