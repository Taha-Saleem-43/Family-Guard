import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:tracelet/tracelet.dart' as tl;
import '../models/movement_activity.dart';
import 'firestore_location_service.dart';
import 'location_fix_policy.dart';
import 'location_outbox.dart';

/// Shared by native foreground callbacks and the headless isolate.
class LocationSyncService {
  static final uploader = FirestoreLocationService();
  static final outbox = LocationOutbox();

  static Future<void> ingest(
    tl.Location location, {
    bool recovery = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final captured = DateTime.tryParse(location.timestamp)?.toUtc();
    final now = DateTime.now().toUtc();
    if (!LocationFixPolicy.accepts(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      accuracy: location.coords.accuracy,
      capturedAt: captured,
      now: recovery && captured != null ? captured : now,
    )) {
      return;
    }
    if (captured == null ||
        now.difference(captured) > const Duration(days: 7) ||
        captured.isAfter(now.add(const Duration(seconds: 30)))) {
      return;
    }
    final context = await outbox.context(user.uid);
    if (context == null || FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }
    final signedInAt = user.metadata.lastSignInTime?.millisecondsSinceEpoch;
    if (signedInAt == null || (context['started'] as int) < signedInAt) return;
    final circle = context['circle'] as String;
    final speed = location.coords.speed < 0
        ? 0.0
        : location.coords.speed * 2.23694;
    final fix = <String, Object>{
      'id': sha256
          .convert(
            utf8.encode(
              '${user.uid}:$circle:${context['started']}:${location.uuid}:${captured.millisecondsSinceEpoch}',
            ),
          )
          .toString(),
      'capturedAt': captured.millisecondsSinceEpoch,
      'latitude': location.coords.latitude,
      'longitude': location.coords.longitude,
      'accuracyMeters': location.coords.accuracy,
      'speedMph': speed.isFinite && speed <= 1000 ? speed : 0.0,
      'movementActivity': MovementActivity.fromSpeed(
        speed,
        rawActivity: location.activity.type.toString(),
      ).name,
      'batteryLevel': location.battery.level < 0
          ? -1
          : (location.battery.level * 100).round(),
      'isCharging': location.battery.isCharging,
    };
    final saved = await outbox.enqueue(
      user.uid,
      circle,
      fix,
      now.millisecondsSinceEpoch,
      recovery: recovery,
    );
    if (saved && location.uuid.isNotEmpty) {
      await tl.Tracelet.destroyLocation(location.uuid);
    }
    if (!recovery) await flush();
  }

  static Future<void> recover() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || await outbox.context(uid) == null) return;
    final locations = await tl.Tracelet.getLocations(
      const tl.SQLQuery(limit: 200),
    );
    for (final location in locations) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      await ingest(location, recovery: true);
      if (location.uuid.isNotEmpty) {
        await tl.Tracelet.destroyLocation(location.uuid);
      }
    }
    await flush();
  }

  static Future<void> flush() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    final signedInAt = user?.metadata.lastSignInTime?.millisecondsSinceEpoch;
    final context = await outbox.context(uid);
    if (signedInAt == null ||
        context == null ||
        (context['started'] as int) < signedInAt) {
      return;
    }
    for (var batch = 0; batch < 3; batch++) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      final lease = await outbox.claim(
        uid,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (lease == null) return;
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable(
              'ingestLocations',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 30),
              ),
            )
            .call({
              'expectedUid': uid,
              'circleId': lease.circle,
              'sharingStartedAt': lease.startedAt,
              'fixes': lease.fixes,
            });
        final data = result.data;
        if (data is! Map || data['acceptedIds'] is! List) {
          throw StateError('Missing upload acknowledgement.');
        }
        await outbox.acknowledge(
          lease,
          (data['acceptedIds'] as List).whereType<String>().toList(),
        );
      } on FirebaseFunctionsException catch (error) {
        if ([
          'failed-precondition',
          'permission-denied',
          'invalid-argument',
          'already-exists',
        ].contains(error.code)) {
          // Stale membership, expired data and conflicting IDs cannot become valid through retry.
          await outbox.acknowledge(
            lease,
            lease.fixes.map((fix) => fix['id'] as String).toList(),
          );
        } else {
          await outbox.retry(lease, DateTime.now().millisecondsSinceEpoch);
        }
        return;
      } catch (_) {
        await outbox.retry(lease, DateTime.now().millisecondsSinceEpoch);
        return;
      }
    }
  }
}
