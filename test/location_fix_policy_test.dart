import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/services/location_fix_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9);
  bool accepts({
    double lat = 33,
    double lng = 73,
    double accuracy = 10,
    Duration age = Duration.zero,
  }) => LocationFixPolicy.accepts(
    latitude: lat,
    longitude: lng,
    accuracy: accuracy,
    capturedAt: now.subtract(age),
    now: now,
  );
  test('accepts fresh valid fixes including boundary coordinates', () {
    expect(accepts(), isTrue);
    expect(
      accepts(
        lat: -90,
        lng: 180,
        accuracy: 100,
        age: const Duration(seconds: 120),
      ),
      isTrue,
    );
  });
  test('rejects drift, malformed coordinates and stale or future fixes', () {
    expect(accepts(lat: double.nan), isFalse);
    expect(accepts(lng: 181), isFalse);
    expect(accepts(accuracy: -1), isFalse);
    expect(accepts(accuracy: 101), isFalse);
    expect(accepts(age: const Duration(seconds: 121)), isFalse);
    expect(accepts(age: const Duration(seconds: -31)), isFalse);
    expect(
      LocationFixPolicy.accepts(
        latitude: 0,
        longitude: 0,
        accuracy: 1,
        capturedAt: null,
        now: now,
      ),
      isFalse,
    );
  });
}
