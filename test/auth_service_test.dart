import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/features/auth/domain/circle_model.dart';
import 'package:family_guard/features/auth/domain/user_account_model.dart';
import 'package:family_guard/features/auth/services/auth_service.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/services/user_session_service.dart';

void main() {
  group('Auth & Circle Engine Tests', () {
    test('generateInviteCode creates valid formatted invite codes', () {
      final parentCode = AuthService.generateInviteCode('PARENT');
      final childCode = AuthService.generateInviteCode('FAMILY');

      expect(parentCode.startsWith('PARENT-'), isTrue);
      expect(parentCode.length, equals(11)); // PARENT-XXXX

      expect(childCode.startsWith('FAMILY-'), isTrue);
      expect(childCode.length, equals(11)); // FAMILY-XXXX
    });

    test('UserAccountModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final user = UserAccountModel(
        uid: 'user123',
        email: 'alex@example.com',
        displayName: 'Alex Johnson',
        role: UserRole.parent,
        circleId: 'circle_abc',
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['role'], equals('parent'));
      expect(map['circleId'], equals('circle_abc'));

      final restored = UserAccountModel.fromMap(map, 'user123');
      expect(restored.uid, equals('user123'));
      expect(restored.role, equals(UserRole.parent));
      expect(restored.circleId, equals('circle_abc'));
    });

    test('CircleModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final circle = CircleModel(
        id: 'circle123',
        name: 'The Johnson Family',
        parentInviteCode: 'PARENT-8K2M',
        childInviteCode: 'FAMILY-7K4X',
        createdBy: 'user123',
        memberIds: const ['user123', 'user456'],
        createdAt: now,
      );

      final map = circle.toMap();
      expect(map['name'], equals('The Johnson Family'));
      expect(map['parentInviteCode'], equals('PARENT-8K2M'));
      expect(map['memberIds'].length, equals(2));

      final restored = CircleModel.fromMap(map, 'circle123');
      expect(restored.id, equals('circle123'));
      expect(restored.childInviteCode, equals('FAMILY-7K4X'));
    });

    test('UserSessionService saves session with JWT token and retrieves active session', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      const testUid = 'user_jwt_test_123';
      const mockJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test_token';

      await UserSessionService.saveUserSession(
        uid: testUid,
        role: 'parent',
        circleId: 'circle_jwt_99',
        email: 'jwt_user@familyguard.app',
        userName: 'JWT User',
        circleName: 'Test Circle',
        idToken: mockJwtToken,
      );

      final activeSession = await UserSessionService.getActiveSession();
      expect(activeSession, isNotNull);
      expect(activeSession!['uid'], equals(testUid));
      expect(activeSession['isLoggedIn'], isTrue);
      expect(activeSession['idToken'], equals(mockJwtToken));
      expect(activeSession['circleId'], equals('circle_jwt_99'));
    });

    test('UserSessionService clears session and invalidates JWT token on logout', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      const testUid = 'user_jwt_logout_456';
      const mockJwtToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.logout_token';

      await UserSessionService.saveUserSession(
        uid: testUid,
        role: 'child',
        circleId: 'circle_logout_88',
        idToken: mockJwtToken,
      );

      // Verify active before logout
      var session = await UserSessionService.getUserSession(testUid);
      expect(session, isNotNull);
      expect(session!['isLoggedIn'], isTrue);

      // Perform logout / clear session
      await UserSessionService.clearUserSession(testUid);

      // Verify invalidated after logout
      session = await UserSessionService.getUserSession(testUid);
      expect(session, isNull);

      final activeSession = await UserSessionService.getActiveSession();
      expect(activeSession, isNull);
    });

    test('AppStateNotifier checkRestoreSession automatically skips onboarding for logged in users', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      const testUid = 'user_auto_login_789';

      await UserSessionService.saveUserSession(
        uid: testUid,
        role: 'parent',
        circleId: 'circle_auto_11',
        userName: 'Auto User',
        circleName: 'Auto Family',
        idToken: 'test_id_token',
      );

      final notifier = AppStateNotifier();
      expect(notifier.state.stage, equals(AppStage.onboarding));

      final restored = await notifier.checkRestoreSession(testUid);
      expect(restored, isTrue);
      expect(notifier.state.stage, equals(AppStage.main));
      expect(notifier.state.userId, equals(testUid));
      expect(notifier.state.circleId, equals('circle_auto_11'));

      // Logout / reset
      notifier.resetToOnboarding();
      expect(notifier.state.stage, equals(AppStage.onboarding));
    });
  });
}


