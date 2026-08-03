import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/features/auth/domain/circle_model.dart';
import 'package:family_guard/features/auth/domain/user_account_model.dart';
import 'package:family_guard/features/auth/services/auth_service.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';

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
  });
}
