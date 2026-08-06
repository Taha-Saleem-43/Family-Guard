import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/models/place.dart';
import 'package:family_guard/core/models/location_history_point.dart';
import 'package:family_guard/core/models/movement_activity.dart';

void main() {
  group('Place Model & Category Extension Tests', () {
    final homePlace = Place(
      id: 'p_home',
      circleId: 'circle_123',
      name: 'Family Home',
      address: '45 Park Avenue',
      category: PlaceCategory.home,
      radius: 200.0,
      latitude: 33.6844,
      longitude: 73.0479,
      color: Colors.teal,
      notifyArrive: true,
      notifyLeave: true,
      createdBy: 'parent_1',
    );

    final schoolPlace = Place(
      id: 'p_school',
      circleId: 'circle_123',
      name: 'City High School',
      address: '100 School Lane',
      category: PlaceCategory.school,
      radius: 300.0,
      latitude: 33.7000,
      longitude: 73.0600,
      color: Colors.blue,
      notifyArrive: true,
      notifyLeave: false,
      createdBy: 'parent_1',
    );

    final workPlace = Place(
      id: 'p_work',
      circleId: 'circle_123',
      name: 'Tech Office',
      address: 'Blue Area Tower',
      category: PlaceCategory.work,
      radius: 150.0,
      latitude: 33.7200,
      longitude: 73.0800,
      color: Colors.purple,
    );

    final customPlace = Place(
      id: 'p_custom',
      circleId: 'circle_123',
      name: 'Grandma\'s House',
      address: '78 Rose Street',
      category: PlaceCategory.custom,
      radius: 250.0,
      latitude: 33.6500,
      longitude: 73.0100,
      color: Colors.orange,
    );

    test('Category Extension Display Names, Icons, & Emojis', () {
      expect(PlaceCategory.home.displayName, equals('Home'));
      expect(PlaceCategory.home.emoji, equals('🏠'));
      expect(PlaceCategory.home.icon, equals(Icons.home_rounded));

      expect(PlaceCategory.school.displayName, equals('School'));
      expect(PlaceCategory.school.emoji, equals('🏫'));
      expect(PlaceCategory.school.icon, equals(Icons.school_rounded));

      expect(PlaceCategory.work.displayName, equals('Work'));
      expect(PlaceCategory.work.emoji, equals('💼'));
      expect(PlaceCategory.work.icon, equals(Icons.work_rounded));

      expect(PlaceCategory.custom.displayName, equals('Custom Place'));
      expect(PlaceCategory.custom.emoji, equals('📍'));
      expect(PlaceCategory.custom.icon, equals(Icons.place_rounded));
    });

    test('Distance Calculation & Geofence Boundary Checks', () {
      // Point at exact same location -> distance = ~0m (inside geofence)
      expect(homePlace.distanceToInMeters(33.6844, 73.0479), lessThan(1.0));
      expect(homePlace.isInsideGeofence(33.6844, 73.0479), isTrue);

      // Point ~100m away -> inside 200m geofence
      expect(homePlace.isInsideGeofence(33.6850, 73.0479), isTrue);

      // Point ~500m away -> outside 200m geofence
      expect(homePlace.isInsideGeofence(33.6900, 73.0479), isFalse);
    });

    test('Serialization toMap and fromMap Integrity', () {
      final map = homePlace.toMap();
      expect(map['id'], equals('p_home'));
      expect(map['circleId'], equals('circle_123'));
      expect(map['name'], equals('Family Home'));
      expect(map['category'], equals('home'));
      expect(map['radius'], equals(200.0));
      expect(map['latitude'], equals(33.6844));
      expect(map['longitude'], equals(73.0479));
      expect(map['notifyArrive'], isTrue);
      expect(map['notifyLeave'], isTrue);

      final restored = Place.fromMap(map, 'p_home');
      expect(restored.id, equals(homePlace.id));
      expect(restored.circleId, equals(homePlace.circleId));
      expect(restored.name, equals(homePlace.name));
      expect(restored.category, equals(PlaceCategory.home));
      expect(restored.radius, equals(200.0));
      expect(restored.latitude, equals(33.6844));
      expect(restored.longitude, equals(73.0479));
      expect(restored.notifyArrive, isTrue);
      expect(restored.notifyLeave, isTrue);
    });

    test('fromMap handles missing/null optional fields gracefully', () {
      final minimalMap = <String, dynamic>{
        'name': 'Test Place',
        'latitude': 33.0,
        'longitude': 73.0,
      };

      final placeFromMinimal = Place.fromMap(minimalMap, 'doc_xyz');
      expect(placeFromMinimal.id, equals('doc_xyz'));
      expect(placeFromMinimal.name, equals('Test Place'));
      expect(placeFromMinimal.category, equals(PlaceCategory.custom));
      expect(placeFromMinimal.radius, equals(200.0)); // default radius
      expect(placeFromMinimal.notifyArrive, isTrue);
      expect(placeFromMinimal.notifyLeave, isTrue);
    });

    test('copyWith updates fields correctly without side effects', () {
      final updated = schoolPlace.copyWith(
        name: 'New School Name',
        radius: 500.0,
        notifyLeave: true,
      );

      expect(updated.name, equals('New School Name'));
      expect(updated.radius, equals(500.0));
      expect(updated.notifyLeave, isTrue); // Changed from false
      expect(updated.notifyArrive, isTrue); // Unchanged
      expect(updated.id, equals(schoolPlace.id));
    });

    test('Matching History Points against Saved Places', () {
      final savedPlaces = [homePlace, schoolPlace, workPlace, customPlace];

      final now = DateTime.now();
      final expireAt = now.add(const Duration(days: 30));

      // Point at Home
      final homePoint = LocationHistoryPoint(
        id: 'hp_1',
        latitude: 33.6844,
        longitude: 73.0479,
        speedMph: 0.0,
        timestamp: now,
        expireAt: expireAt,
        movementActivity: MovementActivity.stationary,
      );

      // Point at School
      final schoolPoint = LocationHistoryPoint(
        id: 'hp_2',
        latitude: 33.7001,
        longitude: 73.0601,
        speedMph: 0.0,
        timestamp: now,
        expireAt: expireAt,
        movementActivity: MovementActivity.stationary,
      );

      // Point at Unknown location (outside all geofences)
      final unknownPoint = LocationHistoryPoint(
        id: 'hp_3',
        latitude: 33.8000,
        longitude: 73.2000,
        speedMph: 0.0,
        timestamp: now,
        expireAt: expireAt,
        movementActivity: MovementActivity.stationary,
      );

      Place? matchPoint(LocationHistoryPoint pt) {
        for (final p in savedPlaces) {
          if (p.isInsideGeofence(pt.latitude, pt.longitude)) {
            return p;
          }
        }
        return null;
      }

      final homeMatch = matchPoint(homePoint);
      expect(homeMatch, isNotNull);
      expect(homeMatch!.name, equals('Family Home'));
      expect(homeMatch.category, equals(PlaceCategory.home));

      final schoolMatch = matchPoint(schoolPoint);
      expect(schoolMatch, isNotNull);
      expect(schoolMatch!.name, equals('City High School'));

      final unknownMatch = matchPoint(unknownPoint);
      expect(unknownMatch, isNull);
    });

    test('Category Filtering Logic', () {
      final placesList = [homePlace, schoolPlace, workPlace, customPlace];

      final homeOnly = placesList.where((p) => p.category == PlaceCategory.home).toList();
      expect(homeOnly.length, equals(1));
      expect(homeOnly.first.name, equals('Family Home'));

      final schoolOnly = placesList.where((p) => p.category == PlaceCategory.school).toList();
      expect(schoolOnly.length, equals(1));
      expect(schoolOnly.first.name, equals('City High School'));

      final customOnly = placesList.where((p) => p.category == PlaceCategory.custom).toList();
      expect(customOnly.length, equals(1));
      expect(customOnly.first.name, equals('Grandma\'s House'));
    });
  });
}
