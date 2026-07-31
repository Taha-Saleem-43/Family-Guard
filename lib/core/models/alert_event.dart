import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum AlertEventType { arrive, leave }

class AlertEvent extends Equatable {
  final String id;
  final String memberId;
  final String memberName;
  final Color memberColor;
  final String placeName;
  final AlertEventType type;
  final DateTime timestamp;

  const AlertEvent({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.memberColor,
    required this.placeName,
    required this.type,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [
        id,
        memberId,
        memberName,
        memberColor,
        placeName,
        type,
        timestamp,
      ];
}
