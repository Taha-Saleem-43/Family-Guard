import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/sos_alert.dart';
import 'sos_request_store.dart';

typedef SOSCallable =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    );

class SOSService {
  final FirebaseFirestore? _firestore;
  final SOSCallable? _call;
  final SOSRequestStore _requests;
  SOSService({
    FirebaseFirestore? firestore,
    SOSCallable? callable,
    SOSRequestStore? requests,
  }) : _firestore =
           firestore ??
           (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null),
       _call = callable ?? (Firebase.apps.isNotEmpty ? _firebaseCall : null),
       _requests = requests ?? PreferencesSOSRequestStore();

  static Future<Map<String, dynamic>> _firebaseCall(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<String?> triggerSOS({
    required String circleId,
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
    String address = 'Location unavailable',
  }) async {
    if (_call == null || circleId.isEmpty || userId.isEmpty) return null;
    try {
      // Resolution on another device can leave a resolved key in this device's store.
      // A deliberate send may discard that old key and create one new request.
      for (var attempt = 0; attempt < 2; attempt++) {
        final requestId = await _requests.getOrCreate(userId, circleId);
        final result = await _call('triggerSos', {
          'expectedUid': userId,
          'requestId': requestId,
          'circleId': circleId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        });
        final alertId = result['alertId'];
        if (result['status'] == 'active' &&
            alertId is String &&
            alertId.isNotEmpty) {
          return alertId;
        }
        if (result['status'] != 'resolved') return null;
        await _requests.clear(userId, circleId);
      }
    } catch (error) {
      // A timeout may arrive after the server committed; retain the request key.
      debugPrint('[SOSService] Sending failed: $error');
    }
    return null;
  }

  Future<bool> resolveSOS({
    required String alertId,
    required String userId,
    String? circleId,
  }) async {
    if (_call == null ||
        alertId.isEmpty ||
        userId.isEmpty ||
        circleId == null ||
        circleId.isEmpty) {
      return false;
    }
    try {
      final result = await _call('resolveSos', {
        'alertId': alertId,
        'expectedUid': userId,
      });
      if (result['resolved'] != true || result['alertId'] != alertId) {
        return false;
      }
      // Local cleanup failure does not undo confirmed server resolution.
      try {
        await _requests.clear(userId, circleId);
      } catch (error) {
        debugPrint('[SOSService] Request cleanup failed: $error');
      }
      return true;
    } catch (error) {
      debugPrint('[SOSService] Resolution failed: $error');
      return false;
    }
  }

  Stream<List<SOSAlert>> streamActiveSOSAlerts(String circleId) {
    if (_firestore == null || circleId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('sos_alerts')
        .where('circleId', isEqualTo: circleId)
        .where('status', isEqualTo: 'active')
        .snapshots(includeMetadataChanges: true)
        .where(
          (snapshot) =>
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        )
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SOSAlert.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<SOSAlert>> streamCircleSOSHistory(String circleId) {
    if (_firestore == null || circleId.isEmpty) return Stream.value([]);
    return _firestore
        .collection('sos_alerts')
        .where('circleId', isEqualTo: circleId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SOSAlert.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }
}
