import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/place.dart';

class PlacesService {
  final FirebaseFirestore _firestore;

  PlacesService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Stream saved places for a specific circle
  Stream<List<Place>> streamCirclePlaces(String circleId) {
    if (circleId.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('places')
        .where('circleId', isEqualTo: circleId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Place.fromFirestore(doc)).toList();
        });
  }

  /// Add a new place to Firestore
  Future<String> addPlace(Place place) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    final fields = place.toMap()..remove('createdAt');
    final result = await FirebaseFunctions.instance
        .httpsCallable('savePlace')
        .call({
          'expectedUid': uid,
          'circleId': place.circleId,
          if (place.id.isNotEmpty) 'placeId': place.id,
          'place': fields,
        });
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Your account changed.');
    }
    return (result.data as Map)['id'] as String;
  }

  /// Update existing place details
  Future<void> updatePlace(Place place) async {
    if (place.id.isEmpty) return;
    await addPlace(place);
  }

  /// Toggle notification options for arrival or departure
  Future<void> toggleNotifications({
    required String placeId,
    required String circleId,
    bool? notifyArrive,
    bool? notifyLeave,
  }) async {
    if (placeId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    final settings = <String, Object>{};
    if (notifyArrive != null) settings['notifyArrive'] = notifyArrive;
    if (notifyLeave != null) settings['notifyLeave'] = notifyLeave;
    await FirebaseFunctions.instance
        .httpsCallable('togglePlaceNotifications')
        .call({
          'expectedUid': uid,
          'circleId': circleId,
          'placeId': placeId,
          ...settings,
        });
  }

  /// Delete a saved place
  Future<void> deletePlace(String placeId, {required String circleId}) async {
    if (placeId.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in.');
    await FirebaseFunctions.instance.httpsCallable('deletePlace').call({
      'expectedUid': uid,
      'circleId': circleId,
      'placeId': placeId,
    });
  }
}
