/// Reject unusable fixes before they reach UI or network storage.
class LocationFixPolicy {
  static bool accepts({
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime? capturedAt,
    required DateTime now,
  }) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 100 ||
        capturedAt == null) {
      return false;
    }
    return now.difference(capturedAt).inSeconds <= 120 &&
        capturedAt.difference(now).inSeconds <= 30;
  }
}
