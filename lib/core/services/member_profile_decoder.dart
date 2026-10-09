import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import '../models/movement_activity.dart';
import '../theme/app_colors.dart';

/// Decodes legacy profiles defensively; database rules validate new writes.
class MemberProfileDecoder {
  /// Preserve list identity when no freshness changed, avoiding map rebuilds.
  static List<Member> ageMembers(List<Member> members, DateTime now) {
    List<Member>? updated;
    for (var index = 0; index < members.length; index++) {
      final member = members[index];
      final stale =
          member.latitude == null ||
          member.longitude == null ||
          !isFresh(member.lastSeen, now);
      if (stale != member.isStale) {
        updated ??= List.of(members);
        updated[index] = member.copyWith(isStale: stale);
      }
    }
    return updated ?? members;
  }

  static bool isFresh(DateTime lastSeen, DateTime now) {
    final age = now.difference(lastSeen);
    return age >= const Duration(seconds: -30) &&
        age <= const Duration(minutes: 15);
  }

  static Member decode(
    String id,
    Map<String, dynamic> data, {
    required String currentUid,
    required DateTime now,
  }) {
    final isSelf = id == currentUid;
    final rawName = data['displayName'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : 'Family Member';
    final role = data['role'] == 'parent' ? UserRole.parent : UserRole.child;
    double? number(String key) {
      final value = data[key];
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    var latitude = number('latitude');
    var longitude = number('longitude');
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      latitude = null;
      longitude = null;
    }
    final rawSeen = data['lastSeen'];
    final lastSeen =
        (rawSeen is Timestamp
            ? rawSeen.toDate()
            : rawSeen is String
            ? DateTime.tryParse(rawSeen)
            : null) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final battery = number('batteryLevel');
    final speed = number('speedMph');
    final activity = data['movementActivity'];
    final sos = data['isSosActive'] == true;
    return Member(
      id: id,
      name: isSelf ? '$name (You)' : name,
      avatar: role == UserRole.parent ? '👨' : '👩‍🦰',
      role: role,
      latitude: latitude,
      longitude: longitude,
      address: latitude != null && longitude != null
          ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
          : 'Location Pending',
      lastSeen: lastSeen,
      batteryLevel: battery != null && battery >= 0 && battery <= 100
          ? battery.toInt()
          : -1,
      isCharging: data['isCharging'] == true,
      speedMph: speed != null && speed >= 0 && speed <= 1000 ? speed : 0,
      movementActivity: MovementActivity.fromString(
        activity is String ? activity : 'stationary',
      ),
      pinColor: sos
          ? AppColors.sosRed
          : isSelf || role == UserRole.parent
          ? AppColors.primary
          : AppColors.teal,
      isStale: latitude == null || !isFresh(lastSeen, now),
      isSosActive: sos,
    );
  }
}
