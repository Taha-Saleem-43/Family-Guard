import 'package:firebase_auth/firebase_auth.dart';
import 'package:tracelet/tracelet.dart' as tl;
import '../models/movement_activity.dart';
import 'firestore_location_service.dart';
import 'location_fix_policy.dart';

/// Shared by native foreground callbacks and the headless isolate.
class LocationSyncService {
  static final uploader = FirestoreLocationService();

  static Future<void> ingest(tl.Location location) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final captured = DateTime.tryParse(location.timestamp)?.toUtc();
    final now = DateTime.now().toUtc();
    if (!LocationFixPolicy.accepts(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      accuracy: location.coords.accuracy,
      capturedAt: captured,
      now: now,
    )) {
      return;
    }
    final speed = location.coords.speed < 0
        ? 0.0
        : location.coords.speed * 2.23694;
    await uploader.updateUserLocation(
      uid: user.uid,
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      speedMph: speed,
      activity: MovementActivity.fromSpeed(
        speed,
        rawActivity: location.activity.type.toString(),
      ),
      batteryLevel: location.battery.level < 0
          ? -1
          : (location.battery.level * 100).round(),
      isCharging: location.battery.isCharging,
      capturedAt: captured,
    );
  }
}
