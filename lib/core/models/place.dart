import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PlaceCategory { home, school, work, custom }

extension PlaceCategoryExtension on PlaceCategory {
  String get displayName {
    switch (this) {
      case PlaceCategory.home:
        return 'Home';
      case PlaceCategory.school:
        return 'School';
      case PlaceCategory.work:
        return 'Work';
      case PlaceCategory.custom:
        return 'Custom Place';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.home:
        return Icons.home_rounded;
      case PlaceCategory.school:
        return Icons.school_rounded;
      case PlaceCategory.work:
        return Icons.work_rounded;
      case PlaceCategory.custom:
        return Icons.place_rounded;
    }
  }

  String get emoji {
    switch (this) {
      case PlaceCategory.home:
        return '🏠';
      case PlaceCategory.school:
        return '🏫';
      case PlaceCategory.work:
        return '💼';
      case PlaceCategory.custom:
        return '📍';
    }
  }
}

class Place extends Equatable {
  final String id;
  final String circleId;
  final String name;
  final String address;
  final PlaceCategory category;
  final double radius; // in meters (e.g. 100 to 1000)
  final double latitude;
  final double longitude;
  final Color color;
  final bool notifyArrive;
  final bool notifyLeave;
  final String createdBy;
  final DateTime createdAt;

  Place({
    required this.id,
    required this.circleId,
    required this.name,
    required this.address,
    required this.category,
    required this.radius,
    required this.latitude,
    required this.longitude,
    this.color = AppColors.teal,
    this.notifyArrive = true,
    this.notifyLeave = true,
    this.createdBy = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  IconData get iconData => category.icon;

  double distanceToInMeters(double lat, double lng) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat - latitude) * p) / 2 +
        cos(latitude * p) * cos(lat * p) * (1 - cos((lng - longitude) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // Earth diameter in meters (12742 km * 1000)
  }

  bool isInsideGeofence(double lat, double lng) {
    return distanceToInMeters(lat, lng) <= radius;
  }

  Place copyWith({
    String? id,
    String? circleId,
    String? name,
    String? address,
    PlaceCategory? category,
    double? radius,
    double? latitude,
    double? longitude,
    Color? color,
    bool? notifyArrive,
    bool? notifyLeave,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Place(
      id: id ?? this.id,
      circleId: circleId ?? this.circleId,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      radius: radius ?? this.radius,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      color: color ?? this.color,
      notifyArrive: notifyArrive ?? this.notifyArrive,
      notifyLeave: notifyLeave ?? this.notifyLeave,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'circleId': circleId,
      'name': name,
      'address': address,
      'category': category.name,
      'radius': radius,
      'latitude': latitude,
      'longitude': longitude,
      'colorValue': color.toARGB32(),
      'notifyArrive': notifyArrive,
      'notifyLeave': notifyLeave,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Place.fromMap(Map<String, dynamic> map, String docId) {
    final catName = map['category'] as String? ?? 'custom';
    final category = PlaceCategory.values.firstWhere(
      (e) => e.name == catName,
      orElse: () => PlaceCategory.custom,
    );

    final colorVal = map['colorValue'] as int?;
    final color = colorVal != null ? Color(colorVal) : AppColors.teal;

    final createdAtRaw = map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    }

    return Place(
      id: docId.isNotEmpty ? docId : (map['id'] as String? ?? ''),
      circleId: map['circleId'] as String? ?? '',
      name: map['name'] as String? ?? 'Saved Place',
      address: map['address'] as String? ?? '',
      category: category,
      radius: (map['radius'] as num?)?.toDouble() ?? 200.0,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      color: color,
      notifyArrive: map['notifyArrive'] as bool? ?? true,
      notifyLeave: map['notifyLeave'] as bool? ?? true,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: createdAt,
    );
  }

  factory Place.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Place.fromMap(data, doc.id);
  }

  @override
  List<Object?> get props => [
        id,
        circleId,
        name,
        address,
        category,
        radius,
        latitude,
        longitude,
        color,
        notifyArrive,
        notifyLeave,
        createdBy,
        createdAt,
      ];
}

