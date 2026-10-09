import 'dart:math';
import 'dart:async';
import 'package:stream_transform/stream_transform.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/location_history_point.dart';
import '../models/location_history_page.dart';
import '../models/member.dart';
import '../models/circle_roster.dart';
import '../models/movement_activity.dart';
import 'member_profile_decoder.dart';
import 'latest_value_queue.dart';

typedef _ProfileDocuments = List<DocumentSnapshot<Map<String, dynamic>>>;

typedef _LocationUpload = ({
  String uid,
  double latitude,
  double longitude,
  double speedMph,
  MovementActivity activity,
  int batteryLevel,
  bool isCharging,
  DateTime capturedAt,
});

class FirestoreLocationService {
  final FirebaseFirestore? _firestore;

  late final _uploads = LatestValueQueue<_LocationUpload>(
    (fix) => _updateUserLocation(
      uid: fix.uid,
      latitude: fix.latitude,
      longitude: fix.longitude,
      speedMph: fix.speedMph,
      activity: fix.activity,
      batteryLevel: fix.batteryLevel,
      isCharging: fix.isCharging,
      capturedAt: fix.capturedAt,
    ),
  );
  String? _lastReceivedUid;
  DateTime? _lastReceivedAt;
  DateTime? _lastUploadedCapturedAt;
  DateTime? _lastUploadTime;
  String? _lastUploadedUid;
  String? _circleLookupUid;
  String? _uploadCircleId;
  double? _lastUploadedLat;
  double? _lastUploadedLng;
  MovementActivity? _lastUploadedActivity;
  int? _lastUploadedBattery;
  bool? _lastUploadedCharging;

  FirestoreLocationService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  DateTime? get lastUploadTime => _lastUploadTime;
  DateTime? get lastUploadedCapturedAt => _lastUploadedCapturedAt;
  String? get lastUploadedUid => _lastUploadedUid;
  double? get lastUploadedLat => _lastUploadedLat;
  double? get lastUploadedLng => _lastUploadedLng;
  MovementActivity? get lastUploadedActivity => _lastUploadedActivity;
  int? get lastUploadedBattery => _lastUploadedBattery;
  bool? get lastUploadedCharging => _lastUploadedCharging;

  /// Serialize writes while coalescing waiting callbacks to the newest fix.
  Future<void> updateUserLocation({
    required String uid,
    required double latitude,
    required double longitude,
    required double speedMph,
    required MovementActivity activity,
    required int batteryLevel,
    required bool isCharging,
    DateTime? capturedAt,
  }) {
    final capture = (capturedAt ?? DateTime.now()).toUtc();
    final age = DateTime.now().toUtc().difference(capture);
    if (uid.isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        age > const Duration(minutes: 2) ||
        age < const Duration(seconds: -30) ||
        (_lastReceivedUid == uid &&
            _lastReceivedAt != null &&
            capture.isBefore(_lastReceivedAt!))) {
      return Future.value();
    }
    _lastReceivedUid = uid;
    _lastReceivedAt = capture;
    return _uploads.submit((
      uid: uid,
      latitude: latitude,
      longitude: longitude,
      speedMph: speedMph.isFinite && speedMph >= 0 && speedMph <= 1000
          ? speedMph
          : 0,
      activity: activity,
      batteryLevel: batteryLevel >= -1 && batteryLevel <= 100
          ? batteryLevel
          : -1,
      isCharging: isCharging,
      capturedAt: capture,
    ));
  }

  /// Uploads user location and status to Firestore with 3-layer throttling
  Future<void> _updateUserLocation({
    required String uid,
    required double latitude,
    required double longitude,
    required double speedMph,
    required MovementActivity activity,
    required int batteryLevel,
    required bool isCharging,
    required DateTime capturedAt,
  }) async {
    if (uid.isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }

    final now = DateTime.now().toUtc();
    if (_lastUploadedUid != uid) {
      _lastUploadTime = null;
      _lastUploadedLat = null;
      _lastUploadedLng = null;
      _lastUploadedActivity = null;
      _lastUploadedBattery = null;
      _lastUploadedCharging = null;
    }

    // 1. Check instant triggers (activity change, charging state change, or >=5% battery drop / crossing <=20% threshold)
    final bool activityChanged =
        _lastUploadedActivity == null || _lastUploadedActivity != activity;
    final bool chargingChanged =
        _lastUploadedCharging == null || _lastUploadedCharging != isCharging;
    final bool batteryLevelChanged =
        _lastUploadedBattery == null ||
        (_lastUploadedBattery! - batteryLevel).abs() >= 5 ||
        (batteryLevel <= 20 && _lastUploadedBattery! > 20);

    final bool isInstantTrigger =
        activityChanged || chargingChanged || batteryLevelChanged;

    // 2. Check distance delta (meters)
    double distanceMovedMeters = 0.0;
    if (_lastUploadedLat != null && _lastUploadedLng != null) {
      distanceMovedMeters = _calculateDistanceMeters(
        _lastUploadedLat!,
        _lastUploadedLng!,
        latitude,
        longitude,
      );
    } else {
      distanceMovedMeters = 999.0; // Force first write
    }

    // 3. Check time delta (seconds)
    final timeElapsedSeconds = _lastUploadTime == null
        ? 999
        : now.difference(_lastUploadTime!).inSeconds;

    // Throttle rule: upload if instant trigger, OR periodic heartbeat (>=180s), OR (timeElapsed >= 45s AND distanceMoved >= 50m)
    final bool timeHeartbeat = timeElapsedSeconds >= 180;
    final bool distanceMoved =
        timeElapsedSeconds >= 45 && distanceMovedMeters >= 50.0;
    final bool shouldUpload =
        isInstantTrigger || timeHeartbeat || distanceMoved;

    if (!shouldUpload) return;

    try {
      if (_firestore != null) {
        // Resolve once per account/process. Rules check membership again on every write.
        if (_circleLookupUid != uid || _uploadCircleId == null) {
          final profile = await _firestore
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.server));
          final circle = profile.data()?['circleId'];
          if (circle is! String || circle.isEmpty) return;
          _circleLookupUid = uid;
          _uploadCircleId = circle;
        }
        final fields = <String, Object>{
          'capturedAt': capturedAt.millisecondsSinceEpoch,
          'latitude': latitude,
          'longitude': longitude,
          'speedMph': speedMph,
          'movementActivity': activity.name,
          'batteryLevel': batteryLevel,
          'isCharging': isCharging,
        };
        final id = sha256
            .convert(utf8.encode(jsonEncode([uid, _uploadCircleId, fields])))
            .toString();
        await FirebaseFunctions.instance.httpsCallable('ingestLocations').call({
          'expectedUid': uid,
          'circleId': _uploadCircleId,
          'sharingStartedAt': capturedAt.millisecondsSinceEpoch,
          'fixes': [
            {'id': id, ...fields},
          ],
        });
      }

      _lastUploadTime = now;
      _lastUploadedCapturedAt = capturedAt;
      _lastUploadedUid = uid;
      _lastUploadedLat = latitude;
      _lastUploadedLng = longitude;
      _lastUploadedActivity = activity;
      _lastUploadedBattery = batteryLevel;
      _lastUploadedCharging = isCharging;
    } catch (e) {
      if (e is FirebaseException &&
          ['permission-denied', 'failed-precondition'].contains(e.code)) {
        _circleLookupUid = null;
        _uploadCircleId = null;
      }
      debugPrint('[FirestoreLocationService] Error updating location: $e');
    }
  }

  /// Fetches location history points for a user within a specified date range
  Future<List<LocationHistoryPoint>> fetchLocationHistory({
    required String uid,
    String? circleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => (await fetchHistoryPage(
    uid: uid,
    circleId: circleId,
    startDate: startDate,
    endDate: endDate,
    pageSize: 1000,
  )).points;

  Future<LocationHistoryPage> fetchHistoryPage({
    required String uid,
    String? circleId,
    required DateTime startDate,
    required DateTime endDate,
    HistoryCursor? cursor,
    int pageSize = 200,
  }) async {
    if (pageSize < 1 || pageSize > 1000) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be between 1 and 1000',
      );
    }
    final firestore = _firestore;
    if (firestore == null || uid.isEmpty) return const LocationHistoryPage();

    try {
      final startIso = Timestamp.fromDate(startDate.toUtc());
      final endIso = Timestamp.fromDate(endDate.toUtc());

      Query<Map<String, dynamic>> query = firestore
          .collection('locationHistory')
          .doc(uid)
          .collection('points');
      if (circleId != null) {
        if (circleId.isEmpty) return const LocationHistoryPage();
        query = query.where('circleId', isEqualTo: circleId);
      }
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: startIso)
          .where('timestamp', isLessThanOrEqualTo: endIso)
          .orderBy('timestamp', descending: true)
          .orderBy(FieldPath.documentId, descending: true);
      if (cursor != null) {
        query = query.startAfter([
          Timestamp.fromDate(cursor.timestamp.toUtc()),
          cursor.documentId,
        ]);
      }
      final snapshot = await query.limit(pageSize + 1).get();
      final included = snapshot.docs.take(pageSize).toList();
      final points = included
          .map((doc) => LocationHistoryPoint.fromMap(doc.id, doc.data()))
          .toList();

      return LocationHistoryPage(
        points: points,
        nextCursor: snapshot.docs.length > pageSize && points.isNotEmpty
            ? HistoryCursor(points.last.timestamp, included.last.id)
            : null,
      );
    } catch (e) {
      debugPrint(
        '[FirestoreLocationService] Error fetching location history: $e',
      );
      rethrow;
    }
  }

  /// Retention is server-owned. Kept until older callers are removed.
  Future<int> purgeExpiredDocuments({
    required String uid,
    int retentionDays = 30,
  }) async => 0;

  /// Streams circle members from Firestore
  Stream<List<Member>> streamCircleMembers({
    required String circleId,
    required String currentUid,
    required UserRole currentRole,
  }) {
    if (circleId.isEmpty || currentUid.isEmpty || _firestore == null) {
      return Stream.value([]);
    }

    final profiles = currentRole == UserRole.parent
        ? _streamParentProfiles(circleId, currentUid)
        : _firestore
              .collection('users')
              .doc(currentUid)
              .snapshots()
              .map(
                (doc) => doc.exists
                    ? [doc]
                    : <DocumentSnapshot<Map<String, dynamic>>>[],
              );
    return profiles.map((documents) {
      final now = DateTime.now();
      return documents
          .map(
            (doc) => MemberProfileDecoder.decode(
              doc.id,
              doc.data()!,
              currentUid: currentUid,
              now: now,
            ),
          )
          .toList();
    });
  }

  Stream<_ProfileDocuments> _streamParentProfiles(String circleId, String uid) {
    final db = _firestore!;
    return db
        .collection('circles')
        .doc(circleId)
        .snapshots()
        .transform(
          StreamTransformer<
            DocumentSnapshot<Map<String, dynamic>>,
            Stream<_ProfileDocuments>
          >.fromHandlers(
            handleData: (circle, sink) {
              try {
                final ids = CircleRoster.memberIds(circle.data(), uid);
                sink.add(
                  ids.isEmpty
                      ? Stream.value(
                          const <DocumentSnapshot<Map<String, dynamic>>>[],
                        )
                      : db
                            .collection('users')
                            .where('circleId', isEqualTo: circleId)
                            .where(FieldPath.documentId, whereIn: ids)
                            .snapshots()
                            .map((snapshot) => snapshot.docs),
                );
              } catch (error, stack) {
                sink.add(Stream.error(error, stack));
              }
            },
            // Turn authority errors into replacement streams so the old query is cancelled.
            handleError: (error, stack, sink) =>
                sink.add(Stream.error(error, stack)),
          ),
        )
        .switchLatest();
  }

  static double _calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }
}
