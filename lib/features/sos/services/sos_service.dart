import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/sos_alert.dart';

class SOSService {
  final FirebaseFirestore? _firestore;

  SOSService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  /// Triggers an emergency SOS alert in Firestore
  Future<String?> triggerSOS({
    required String circleId,
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
    String address = 'Live Location Broadcast',
  }) async {
    if (_firestore == null || circleId.isEmpty || userId.isEmpty) return null;

    final now = DateTime.now();

    try {
      // 1. Create SOS Alert record in sos_alerts collection
      final docRef = _firestore.collection('sos_alerts').doc();
      final batch = _firestore.batch();
      batch.set(docRef, {
        'circleId': circleId,
        'senderId': userId,
        'senderName': userName,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': now.toIso8601String(),
        'status': 'active',
        'resolvedAt': null,
        'resolvedBy': null,
        'durationSeconds': 0,
      });

      // 2. Update user status to isSosActive = true
      batch.set(_firestore.collection('users').doc(userId), {
        'isSosActive': true,
        'activeSosId': docRef.id,
        'lastSosAt': now.toIso8601String(),
      }, SetOptions(merge: true));
      await batch.commit();

      debugPrint('[SOSService] SOS triggered successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[SOSService] Error triggering SOS: $e');
      return null;
    }
  }

  /// Resolves an active SOS alert in Firestore and calculates total duration
  Future<bool> resolveSOS({
    required String alertId,
    required String userId,
    String? circleId,
  }) async {
    if (_firestore == null || alertId.isEmpty) return false;

    final now = DateTime.now();

    try {
      // Fetch document to calculate exact duration
      final docSnap = await _firestore
          .collection('sos_alerts')
          .doc(alertId)
          .get();
      int durationSeconds = 0;
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data['timestamp'] != null) {
          try {
            final start = DateTime.parse(data['timestamp'] as String);
            durationSeconds = now.difference(start).inSeconds;
          } catch (_) {}
        }
      }

      // Update SOS record
      final batch = _firestore.batch();
      batch.update(_firestore.collection('sos_alerts').doc(alertId), {
        'status': 'resolved',
        'resolvedAt': now.toIso8601String(),
        'resolvedBy': userId,
        'durationSeconds': durationSeconds > 0 ? durationSeconds : 1,
      });

      // Clear user's active SOS flag
      if (userId.isNotEmpty) {
        batch.set(_firestore.collection('users').doc(userId), {
          'isSosActive': false,
          'activeSosId': null,
        }, SetOptions(merge: true));
      }
      await batch.commit();

      debugPrint(
        '[SOSService] SOS resolved successfully: $alertId (Duration: ${durationSeconds}s)',
      );
      return true;
    } catch (e) {
      debugPrint('[SOSService] Error resolving SOS: $e');
      return false;
    }
  }

  /// Real-time stream of active SOS alerts for a circle
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
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SOSAlert.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  /// Stream of all circle SOS history (both active and resolved)
  Stream<List<SOSAlert>> streamCircleSOSHistory(String circleId) {
    if (_firestore == null || circleId.isEmpty) return Stream.value([]);

    return _firestore
        .collection('sos_alerts')
        .where('circleId', isEqualTo: circleId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => SOSAlert.fromMap(doc.id, doc.data()))
              .toList();
          // Sort newest first
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }
}
