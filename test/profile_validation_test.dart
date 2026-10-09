import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_guard/features/auth/domain/user_account_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy malformed profile fields do not crash session restoration', () {
    final account = UserAccountModel.fromMap({
      'email': 42,
      'displayName': [],
      'circleId': false,
      'createdAt': 'invalid',
    }, 'uid');
    expect(account.email, '');
    expect(account.displayName, '');
    expect(account.circleId, isNull);
    expect(account.createdAt.millisecondsSinceEpoch, 0);
  });
  test('profile timestamps accept Firestore and legacy ISO values', () {
    final date = DateTime.utc(2026, 1, 1);
    for (final value in [Timestamp.fromDate(date), date.toIso8601String()]) {
      expect(
        UserAccountModel.fromMap({'createdAt': value}, 'uid').createdAt.toUtc(),
        date,
      );
    }
  });
}
