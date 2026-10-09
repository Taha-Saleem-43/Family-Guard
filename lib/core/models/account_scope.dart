import 'member.dart';

/// Only construct from a confirmed server profile, never preferences.
class AccountScope {
  const AccountScope({
    required this.uid,
    required this.role,
    required this.circleId,
    required this.name,
    this.available = true,
  });
  final String uid;
  final UserRole role;
  final String circleId;
  final String name;
  final bool available;
  factory AccountScope.fromServer(String uid, Map<String, dynamic>? data) {
    final role = data?['role'];
    final circle = data?['circleId'];
    final valid =
        data != null &&
        ['parent', 'child'].contains(role) &&
        (circle == null ||
            (circle is String &&
                circle.length <= 128 &&
                !circle.contains('/'))) &&
        data['deletionRequested'] != true;
    return AccountScope(
      uid: uid,
      role: role == 'parent' ? UserRole.parent : UserRole.child,
      circleId: valid && circle is String ? circle : '',
      name: data?['displayName'] is String
          ? data!['displayName']
          : 'Family Member',
      available: valid,
    );
  }
}
