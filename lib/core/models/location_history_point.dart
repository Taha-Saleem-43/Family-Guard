import 'package:cloud_firestore/cloud_firestore.dart';
import 'movement_activity.dart';

/// Represents a single recorded location point in history
class LocationHistoryPoint {
  final String id;
  final double latitude;
  final double longitude;
  final double speedMph;
  final MovementActivity movementActivity;
  final DateTime timestamp;
  final DateTime expireAt;
  final String? address;
  final String? placeName;

  const LocationHistoryPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.speedMph,
    required this.movementActivity,
    required this.timestamp,
    required this.expireAt,
    this.address,
    this.placeName,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'speedMph': speedMph,
      'movementActivity': movementActivity.name,
      'timestamp': Timestamp.fromDate(timestamp.toUtc()),
      'lastSeen': Timestamp.fromDate(timestamp.toUtc()),
      'expireAt': Timestamp.fromDate(expireAt.toUtc()),
      if (address != null) 'address': address,
      if (placeName != null) 'placeName': placeName,
    };
  }

  factory LocationHistoryPoint.fromMap(String docId, Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final lat = (map['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (map['longitude'] as num?)?.toDouble() ?? 0.0;
    final speed = (map['speedMph'] as num?)?.toDouble() ?? 0.0;
    final activityStr = map['movementActivity'] as String? ?? 'stationary';
    final activity = MovementActivity.fromString(activityStr);
    final stamp = map['timestamp'] != null
        ? parseDate(map['timestamp'])
        : parseDate(map['lastSeen']);
    final expire = map['expireAt'] != null
        ? parseDate(map['expireAt'])
        : stamp.add(const Duration(days: 30));

    return LocationHistoryPoint(
      id: docId,
      latitude: lat,
      longitude: lng,
      speedMph: speed,
      movementActivity: activity,
      timestamp: stamp,
      expireAt: expire,
      address: map['address'] as String?,
      placeName: map['placeName'] as String?,
    );
  }

  LocationHistoryPoint copyWith({
    String? id,
    double? latitude,
    double? longitude,
    double? speedMph,
    MovementActivity? movementActivity,
    DateTime? timestamp,
    DateTime? expireAt,
    String? address,
    String? placeName,
  }) {
    return LocationHistoryPoint(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedMph: speedMph ?? this.speedMph,
      movementActivity: movementActivity ?? this.movementActivity,
      timestamp: timestamp ?? this.timestamp,
      expireAt: expireAt ?? this.expireAt,
      address: address ?? this.address,
      placeName: placeName ?? this.placeName,
    );
  }
}
