import 'package:cloud_firestore/cloud_firestore.dart';
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
    final docRef = place.id.isNotEmpty
        ? _firestore.collection('places').doc(place.id)
        : _firestore.collection('places').doc();

    final newPlace = place.copyWith(id: docRef.id);
    await docRef.set(newPlace.toMap());
    return docRef.id;
  }

  /// Update existing place details
  Future<void> updatePlace(Place place) async {
    if (place.id.isEmpty) return;
    await _firestore.collection('places').doc(place.id).update(place.toMap());
  }

  /// Toggle notification options for arrival or departure
  Future<void> toggleNotifications({
    required String placeId,
    bool? notifyArrive,
    bool? notifyLeave,
  }) async {
    if (placeId.isEmpty) return;
    final updates = <String, dynamic>{};
    if (notifyArrive != null) updates['notifyArrive'] = notifyArrive;
    if (notifyLeave != null) updates['notifyLeave'] = notifyLeave;

    if (updates.isNotEmpty) {
      await _firestore.collection('places').doc(placeId).update(updates);
    }
  }

  /// Delete a saved place
  Future<void> deletePlace(String placeId) async {
    if (placeId.isEmpty) return;
    await _firestore.collection('places').doc(placeId).delete();
  }
}
