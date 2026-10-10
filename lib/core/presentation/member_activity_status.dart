import '../models/member.dart';
import '../models/movement_activity.dart';
import '../services/member_profile_decoder.dart';
import '../services/navigation_service.dart';

extension MemberActivityStatus on Member {
  /// Historical movement remains stored, but is not presented as current.
  MovementActivity? get currentActivity =>
      !isStale &&
          MemberProfileDecoder.isFresh(lastSeen, DateTime.now()) &&
          NavigationService.hasValidCoordinates(latitude, longitude)
      ? movementActivity
      : null;
}
