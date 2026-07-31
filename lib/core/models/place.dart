import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum PlaceCategory { home, school, work, custom }

class Place extends Equatable {
  final String id;
  final String name;
  final String address;
  final PlaceCategory category;
  final double radius; // in meters
  final double latitude;
  final double longitude;
  final Color color;

  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.radius,
    required this.latitude,
    required this.longitude,
    this.color = AppColors.teal,
  });

  Place copyWith({
    String? id,
    String? name,
    String? address,
    PlaceCategory? category,
    double? radius,
    double? latitude,
    double? longitude,
    Color? color,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      radius: radius ?? this.radius,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      color: color ?? this.color,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        category,
        radius,
        latitude,
        longitude,
        color,
      ];
}
