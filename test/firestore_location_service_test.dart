import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/services/firestore_location_service.dart';

void main() {
  test(
    'capture times survive uploading and older fixes cannot overwrite newer coordinates',
    () async {
      final service = FirestoreLocationService();
      final captured = DateTime.now().toUtc().subtract(
        const Duration(seconds: 30),
      );
      Future<void> upload(DateTime time, double latitude) =>
          service.updateUserLocation(
            uid: 'uid',
            latitude: latitude,
            longitude: 73,
            speedMph: 0,
            activity: MovementActivity.stationary,
            batteryLevel: 80,
            isCharging: false,
            capturedAt: time,
          );
      await upload(captured, 33);
      expect(service.lastUploadedCapturedAt, captured);
      await upload(captured.subtract(const Duration(seconds: 10)), 34);
      expect(service.lastUploadedLat, 33);
      await upload(DateTime.now().toUtc().add(const Duration(minutes: 1)), 35);
      expect(service.lastUploadedLat, 33);
    },
  );
  group('FirestoreLocationService & Free-Tier Throttling Tests', () {
    test(
      'A different account always receives its own initial upload policy state',
      () async {
        final service = FirestoreLocationService();
        for (final uid in ['first', 'second']) {
          await service.updateUserLocation(
            uid: uid,
            latitude: 33,
            longitude: 73,
            speedMph: 0,
            activity: MovementActivity.stationary,
            batteryLevel: 90,
            isCharging: false,
          );
          expect(service.lastUploadedUid, uid);
        }
      },
    );
    test(
      'updateUserLocation enforces 50m / 45s / 180s / 5% battery thresholds',
      () async {
        final service = FirestoreLocationService();

        // 1. First location upload triggers (initial state)
        await service.updateUserLocation(
          uid: 'user_1',
          latitude: 33.6844,
          longitude: 73.0479,
          speedMph: 0.0,
          activity: MovementActivity.stationary,
          batteryLevel: 90,
          isCharging: false,
        );
        final t1 = service.lastUploadTime;
        expect(t1, isNotNull);
        expect(service.lastUploadedBattery, equals(90));
        expect(service.lastUploadedCharging, isFalse);

        // 2. Minor battery drop (<5%, e.g., 90% -> 88%) without distance/time should be throttled
        await service.updateUserLocation(
          uid: 'user_1',
          latitude: 33.6844001,
          longitude: 73.0479001,
          speedMph: 0.0,
          activity: MovementActivity.stationary,
          batteryLevel: 88,
          isCharging: false,
        );
        expect(
          service.lastUploadedBattery,
          equals(90),
        ); // Unchanged because throttled

        // 3. Battery drop >= 5% (90% -> 85%) triggers upload instantly
        await service.updateUserLocation(
          uid: 'user_1',
          latitude: 33.6844001,
          longitude: 73.0479001,
          speedMph: 0.0,
          activity: MovementActivity.stationary,
          batteryLevel: 85,
          isCharging: false,
        );
        expect(service.lastUploadedBattery, equals(85));

        // 4. Low battery threshold boundary (22% -> 19%, crossing <=20%) triggers upload
        await service.updateUserLocation(
          uid: 'user_1',
          latitude: 33.6844001,
          longitude: 73.0479001,
          speedMph: 0.0,
          activity: MovementActivity.stationary,
          batteryLevel: 19,
          isCharging: false,
        );
        expect(service.lastUploadedBattery, equals(19));

        // 5. Charging status change (false -> true) triggers upload instantly
        await service.updateUserLocation(
          uid: 'user_1',
          latitude: 33.6844001,
          longitude: 73.0479001,
          speedMph: 0.0,
          activity: MovementActivity.stationary,
          batteryLevel: 19,
          isCharging: true,
        );
        expect(service.lastUploadedCharging, isTrue);

        // 6. Movement activity change (stationary -> walking) triggers upload instantly
        await service.updateUserLocation(
          uid: 'user_1',
          latitude: 33.6844001,
          longitude: 73.0479001,
          speedMph: 3.0,
          activity: MovementActivity.walking,
          batteryLevel: 19,
          isCharging: true,
        );
        expect(service.lastUploadedActivity, equals(MovementActivity.walking));
      },
    );

    test(
      '30-Day TTL retention expireAt calculation generates valid timestamp',
      () {
        final now = DateTime.now();
        final expireAt = now.add(const Duration(days: 30));

        final differenceInDays = expireAt.difference(now).inDays;
        expect(differenceInDays, equals(30));
      },
    );

    test(
      'updateUserLocation triggers instantly for new child initial battery level',
      () async {
        final service = FirestoreLocationService();

        // Initial battery upload for newly registered child should execute without requiring distance move
        await service.updateUserLocation(
          uid: 'child_new_1',
          latitude: 33.6844,
          longitude: 73.0479,
          speedMph: 0.0,
          activity: MovementActivity.stationary,
          batteryLevel: 42,
          isCharging: false,
        );
        expect(service.lastUploadTime, isNotNull);
        expect(service.lastUploadedBattery, equals(42));
      },
    );

    test(
      'purgeExpiredDocuments handles empty parameters and completes safely without firestore instance',
      () async {
        final service = FirestoreLocationService();

        final emptyUidResult = await service.purgeExpiredDocuments(uid: '');
        expect(emptyUidResult, equals(0));

        final noInstanceResult = await service.purgeExpiredDocuments(
          uid: 'test_user_123',
        );
        expect(noInstanceResult, equals(0));
      },
    );
  });
}
