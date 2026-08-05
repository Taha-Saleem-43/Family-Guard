import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/movement_activity.dart';
import '../theme/app_colors.dart';

class FirestoreLocationService {
  final FirebaseFirestore? _firestore;

  DateTime? _lastUploadTime;
  double? _lastUploadedLat;
  double? _lastUploadedLng;
  MovementActivity? _lastUploadedActivity;
  int? _lastUploadedBattery;
  bool? _lastUploadedCharging;

  FirestoreLocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  DateTime? get lastUploadTime => _lastUploadTime;
  double? get lastUploadedLat => _lastUploadedLat;
  double? get lastUploadedLng => _lastUploadedLng;
  MovementActivity? get lastUploadedActivity => _lastUploadedActivity;
  int? get lastUploadedBattery => _lastUploadedBattery;
  bool? get lastUploadedCharging => _lastUploadedCharging;

  /// Uploads user location and status to Firestore with 3-layer throttling
  Future<void> updateUserLocation({
    required String uid,
    required double latitude,
    required double longitude,
    required double speedMph,
    required MovementActivity activity,
    required int batteryLevel,
    required bool isCharging,
  }) async {
    if (uid.isEmpty) return;

    final now = DateTime.now();

    // 1. Check instant triggers (activity change, charging state change, or >=5% battery drop / crossing <=20% threshold)
    final bool activityChanged = _lastUploadedActivity == null || _lastUploadedActivity != activity;
    final bool chargingChanged = _lastUploadedCharging == null || _lastUploadedCharging != isCharging;
    final bool batteryLevelChanged = _lastUploadedBattery == null ||
        (_lastUploadedBattery! - batteryLevel).abs() >= 5 ||
        (batteryLevel <= 20 && _lastUploadedBattery! > 20);

    final bool isInstantTrigger = activityChanged || chargingChanged || batteryLevelChanged;

    // 2. Check distance delta (meters)
    double distanceMovedMeters = 0.0;
    if (_lastUploadedLat != null && _lastUploadedLng != null) {
      distanceMovedMeters = _calculateDistanceMeters(_lastUploadedLat!, _lastUploadedLng!, latitude, longitude);
    } else {
      distanceMovedMeters = 999.0; // Force first write
    }

    // 3. Check time delta (seconds)
    final timeElapsedSeconds = _lastUploadTime == null ? 999 : now.difference(_lastUploadTime!).inSeconds;

    // Throttle rule: upload if instant trigger, OR periodic heartbeat (>=180s), OR (timeElapsed >= 45s AND distanceMoved >= 50m)
    final bool timeHeartbeat = timeElapsedSeconds >= 180;
    final bool distanceMoved = timeElapsedSeconds >= 45 && distanceMovedMeters >= 50.0;
    final bool shouldUpload = isInstantTrigger || timeHeartbeat || distanceMoved;

    if (!shouldUpload) return;

    try {
      if (_firestore != null) {
        await _firestore.collection('users').doc(uid).set({
          'latitude': latitude,
          'longitude': longitude,
          'speedMph': speedMph,
          'movementActivity': activity.name,
          'batteryLevel': batteryLevel,
          'isCharging': isCharging,
          'lastSeen': now.toIso8601String(),
          'expireAt': now.add(const Duration(days: 30)).toIso8601String(),
        }, SetOptions(merge: true));

        // Auto purge expired documents directly from client-side
        await purgeExpiredDocuments(uid: uid);
      }

      _lastUploadTime = now;
      _lastUploadedLat = latitude;
      _lastUploadedLng = longitude;
      _lastUploadedActivity = activity;
      _lastUploadedBattery = batteryLevel;
      _lastUploadedCharging = isCharging;
    } catch (e) {
      debugPrint('[FirestoreLocationService] Error updating location: $e');
    }
  }

  /// Purges expired documents (older than [retentionDays] days or expired by [expireAt]) directly via client-side Firestore batch delete.
  Future<int> purgeExpiredDocuments({
    required String uid,
    int retentionDays = 30,
  }) async {
    final firestore = _firestore;
    if (firestore == null || uid.isEmpty) return 0;

    try {
      final nowIso = DateTime.now().toIso8601String();
      final cutoffIso = DateTime.now()
          .subtract(Duration(days: retentionDays))
          .toIso8601String();

      int deletedCount = 0;
      final batch = firestore.batch();

      // 1. Query locationHistory points where lastSeen <= cutoffIso
      final historyLastSeenQuery = await firestore
          .collection('locationHistory')
          .doc(uid)
          .collection('points')
          .where('lastSeen', isLessThanOrEqualTo: cutoffIso)
          .get();

      for (final doc in historyLastSeenQuery.docs) {
        batch.delete(doc.reference);
        deletedCount++;
      }

      // 2. Query locationHistory points where expireAt <= nowIso
      final historyExpireQuery = await firestore
          .collection('locationHistory')
          .doc(uid)
          .collection('points')
          .where('expireAt', isLessThanOrEqualTo: nowIso)
          .get();

      for (final doc in historyExpireQuery.docs) {
        if (!historyLastSeenQuery.docs.any((d) => d.id == doc.id)) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      // 3. Query locations collection where lastSeen <= cutoffIso
      final locationQuery = await firestore
          .collection('locations')
          .where('lastSeen', isLessThanOrEqualTo: cutoffIso)
          .get();

      for (final doc in locationQuery.docs) {
        if (doc.id == uid || doc.data()['uid'] == uid) {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
      }

      return deletedCount;
    } catch (e) {
      debugPrint('[FirestoreLocationService] Error purging expired documents: $e');
      return 0;
    }
  }

  /// Streams circle members from Firestore
  Stream<List<Member>> streamCircleMembers({required String circleId, required String currentUid}) {
    if (circleId.isEmpty || _firestore == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .where('circleId', isEqualTo: circleId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final isSelf = doc.id == currentUid;
        final name = data['displayName'] as String? ?? 'Family Member';
        final roleStr = data['role'] as String? ?? 'child';
        final role = roleStr == 'parent' ? UserRole.parent : UserRole.child;

        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        final speed = (data['speedMph'] as num?)?.toDouble() ?? 0.0;
        final activityStr = data['movementActivity'] as String? ?? 'stationary';
        final activity = MovementActivity.fromString(activityStr);
        final battery = (data['batteryLevel'] as num?)?.toInt() ?? 100;
        final isCharging = data['isCharging'] as bool? ?? false;

        DateTime lastSeen = DateTime.now();
        if (data['lastSeen'] != null) {
          try {
            lastSeen = DateTime.parse(data['lastSeen'] as String);
          } catch (_) {}
        }

        final isStale = DateTime.now().difference(lastSeen).inMinutes > 15;

        return Member(
          id: doc.id,
          name: isSelf ? '$name (You)' : name,
          avatar: role == UserRole.parent ? '👨' : '👩‍🦰',
          role: role,
          latitude: lat,
          longitude: lng,
          address: lat != null && lng != null ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}' : 'Location Pending',
          lastSeen: lastSeen,
          batteryLevel: battery,
          isCharging: isCharging,
          speedMph: speed,
          movementActivity: activity,
          pinColor: isSelf ? AppColors.primary : (role == UserRole.parent ? AppColors.primary : AppColors.teal),
          isStale: isStale,
        );
      }).toList();
    });
  }

  static double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }
}
