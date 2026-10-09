import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/place.dart';
import '../../../core/providers/app_state_provider.dart';
import '../services/places_service.dart';

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});

/// Real-time stream of Saved Places for the user's active Circle
final circlePlacesStreamProvider = StreamProvider.autoDispose<List<Place>>((
  ref,
) {
  final circleId = ref.watch(
    appStateProvider.select((state) => state.circleId),
  );

  if (circleId.isEmpty || Firebase.apps.isEmpty) {
    return Stream.value([]);
  }

  final service = ref.watch(placesServiceProvider);
  return service.streamCirclePlaces(circleId);
});

/// Selected place category filter for Places Screen (null = All)
final selectedPlaceCategoryFilterProvider = StateProvider<PlaceCategory?>(
  (ref) => null,
);

class PlacesController {
  final Ref _ref;

  PlacesController(this._ref);

  Future<String> addPlace(Place place) async {
    final appState = _ref.read(appStateProvider);
    final placeWithCircle = place.copyWith(
      circleId: appState.circleId,
      createdBy: appState.userId,
    );
    final service = _ref.read(placesServiceProvider);
    return await service.addPlace(placeWithCircle);
  }

  Future<void> updatePlace(Place place) async {
    final service = _ref.read(placesServiceProvider);
    await service.updatePlace(place);
  }

  Future<void> toggleArrivalNotification(Place place) async {
    final service = _ref.read(placesServiceProvider);
    await service.toggleNotifications(
      placeId: place.id,
      notifyArrive: !place.notifyArrive,
    );
  }

  Future<void> toggleDepartureNotification(Place place) async {
    final service = _ref.read(placesServiceProvider);
    await service.toggleNotifications(
      placeId: place.id,
      notifyLeave: !place.notifyLeave,
    );
  }

  Future<void> deletePlace(String placeId) async {
    final service = _ref.read(placesServiceProvider);
    await service.deletePlace(placeId);
  }
}

final placesControllerProvider = Provider<PlacesController>((ref) {
  return PlacesController(ref);
});
