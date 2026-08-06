import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'movement_activity.dart';

enum TimelineItemType { stay, trip }

/// Aggregated representation of user location history (Stay vs. Trip)
class HistoryTimelineItem {
  final String id;
  final TimelineItemType type;
  final String title;
  final String address;
  final DateTime startTime;
  final DateTime endTime;
  final String durationText;
  final IconData icon;
  final Color color;
  final MovementActivity activity;
  final double distanceMiles;
  final List<LatLng> polylinePoints;

  const HistoryTimelineItem({
    required this.id,
    required this.type,
    required this.title,
    required this.address,
    required this.startTime,
    required this.endTime,
    required this.durationText,
    required this.icon,
    required this.color,
    required this.activity,
    this.distanceMiles = 0.0,
    this.polylinePoints = const [],
  });
}
