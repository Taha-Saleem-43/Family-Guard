import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum UserRole { parent, child }

class Member extends Equatable {
  final String id;
  final String name;
  final String initials;
  final UserRole role;
  final double? latitude;
  final double? longitude;
  final String address;
  final DateTime lastSeen;
  final int batteryLevel;
  final double speed;
  final Color pinColor;
  final bool isMoving;
  final bool isStale;

  const Member({
    required this.id,
    required this.name,
    required this.initials,
    required this.role,
    this.latitude,
    this.longitude,
    required this.address,
    required this.lastSeen,
    required this.batteryLevel,
    required this.speed,
    this.pinColor = AppColors.pinBlue,
    this.isMoving = false,
    this.isStale = false,
  });

  Member copyWith({
    String? id,
    String? name,
    String? initials,
    UserRole? role,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? lastSeen,
    int? batteryLevel,
    double? speed,
    Color? pinColor,
    bool? isMoving,
    bool? isStale,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      initials: initials ?? this.initials,
      role: role ?? this.role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      lastSeen: lastSeen ?? this.lastSeen,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      speed: speed ?? this.speed,
      pinColor: pinColor ?? this.pinColor,
      isMoving: isMoving ?? this.isMoving,
      isStale: isStale ?? this.isStale,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        initials,
        role,
        latitude,
        longitude,
        address,
        lastSeen,
        batteryLevel,
        speed,
        pinColor,
        isMoving,
        isStale,
      ];
}
