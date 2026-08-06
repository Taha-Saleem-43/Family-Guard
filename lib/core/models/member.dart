import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'movement_activity.dart';

enum UserRole { parent, child }

class Member extends Equatable {
  final String id;
  final String name;
  final String avatar;
  final UserRole role;
  final double? latitude;
  final double? longitude;
  final String address;
  final DateTime lastSeen;
  final int batteryLevel;
  final bool isCharging;
  final double speedMph;
  final MovementActivity movementActivity;
  final Color pinColor;
  final bool isStale;
  final bool isSosActive;

  const Member({
    required this.id,
    required this.name,
    required this.avatar,
    required this.role,
    this.latitude,
    this.longitude,
    required this.address,
    required this.lastSeen,
    required this.batteryLevel,
    this.isCharging = false,
    required this.speedMph,
    required this.movementActivity,
    this.pinColor = AppColors.primary,
    this.isStale = false,
    this.isSosActive = false,
  });

  Member copyWith({
    String? id,
    String? name,
    String? avatar,
    UserRole? role,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? lastSeen,
    int? batteryLevel,
    bool? isCharging,
    double? speedMph,
    MovementActivity? movementActivity,
    Color? pinColor,
    bool? isStale,
    bool? isSosActive,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      lastSeen: lastSeen ?? this.lastSeen,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      speedMph: speedMph ?? this.speedMph,
      movementActivity: movementActivity ?? this.movementActivity,
      pinColor: pinColor ?? this.pinColor,
      isStale: isStale ?? this.isStale,
      isSosActive: isSosActive ?? this.isSosActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatar,
        role,
        latitude,
        longitude,
        address,
        lastSeen,
        batteryLevel,
        isCharging,
        speedMph,
        movementActivity,
        pinColor,
        isStale,
        isSosActive,
      ];
}
