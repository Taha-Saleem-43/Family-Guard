import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/history_timeline_item.dart';
import '../../../core/models/location_history_point.dart';
import '../../../core/models/movement_activity.dart';
import '../../../core/models/place.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/services/firestore_location_service.dart';
import '../../../core/services/history_cron_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../places/providers/places_provider.dart';

/// Selected timeframe tab (0: Today, 1: 7 Days, 2: 30 Days)
final selectedHistoryTimeframeProvider = StateProvider<int>((ref) => 0);

/// Selected member for history viewing (defaults to current user)
final selectedHistoryMemberIdProvider = StateProvider<String?>((ref) => null);

/// Firestore location service instance
final firestoreLocationServiceProvider = Provider((ref) => FirestoreLocationService());

/// Cron purge status provider
final historyCronStatusProvider = FutureProvider<DateTime?>((ref) async {
  return await HistoryCronService.instance.getLastPurgeDate();
});

/// Raw location history points provider
final rawLocationHistoryProvider = FutureProvider<List<LocationHistoryPoint>>((ref) async {
  final appState = ref.watch(appStateProvider);
  final selectedMemberId = ref.watch(selectedHistoryMemberIdProvider) ?? appState.userId;
  final timeframeIndex = ref.watch(selectedHistoryTimeframeProvider);
  final service = ref.watch(firestoreLocationServiceProvider);

  if (selectedMemberId.isEmpty) return [];

  // Start client cron purge check on history view
  HistoryCronService.instance.runPurgeIfNeeded(uid: selectedMemberId);

  final now = DateTime.now();
  DateTime startDate;

  switch (timeframeIndex) {
    case 0: // Today
      startDate = DateTime(now.year, now.month, now.day);
      break;
    case 1: // 7 Days
      startDate = now.subtract(const Duration(days: 7));
      break;
    case 2: // 30 Days
      startDate = now.subtract(const Duration(days: 30));
      break;
    default:
      startDate = DateTime(now.year, now.month, now.day);
  }

  final remotePoints = await service.fetchLocationHistory(
    uid: selectedMemberId,
    startDate: startDate,
    endDate: now,
  );

  if (remotePoints.isNotEmpty) {
    return remotePoints;
  }

  // Fallback demo/mock data generation for testing/preview when no Firestore history exists
  return _generateMockPoints(now, timeframeIndex);
});

/// Computes aggregated timeline items (Stays & Trips) from history points, matching saved places
final historyTimelineProvider = Provider<List<HistoryTimelineItem>>((ref) {
  final asyncPoints = ref.watch(rawLocationHistoryProvider);
  final placesAsync = ref.watch(circlePlacesStreamProvider);
  final places = placesAsync.value ?? <Place>[];

  return asyncPoints.when(
    data: (points) => _aggregatePointsToTimeline(points, places),
    loading: () => [],
    error: (err, stack) => [],
  );
});

/// Route polyline points for the map header
final historyRoutePolylineProvider = Provider<List<LatLng>>((ref) {
  final asyncPoints = ref.watch(rawLocationHistoryProvider);

  return asyncPoints.when(
    data: (points) => points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    loading: () => [],
    error: (err, stack) => [],
  );
});

List<HistoryTimelineItem> _aggregatePointsToTimeline(
  List<LocationHistoryPoint> points,
  List<Place> savedPlaces,
) {
  if (points.isEmpty) return [];

  final items = <HistoryTimelineItem>[];

  // Group consecutive points by activity
  LocationHistoryPoint? currentGroupStart;
  LocationHistoryPoint? currentGroupEnd;
  MovementActivity? currentActivity;
  final groupPoints = <LocationHistoryPoint>[];

  Place? findMatchingSavedPlace(double lat, double lng) {
    for (final place in savedPlaces) {
      if (place.isInsideGeofence(lat, lng)) {
        return place;
      }
    }
    return null;
  }

  void finalizeGroup() {
    final startPt = currentGroupStart;
    final endPt = currentGroupEnd;
    final activity = currentActivity;

    if (startPt == null || endPt == null || activity == null) return;

    final start = startPt.timestamp;
    final end = endPt.timestamp;
    final diffMinutes = end.difference(start).inMinutes.abs();
    final durationStr = diffMinutes > 60 ? '${(diffMinutes / 60).toStringAsFixed(1)} hrs' : '${diffMinutes.clamp(5, 59)} mins';
    final timeRangeStr = '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    if (activity == MovementActivity.stationary) {
      final matchedPlace = findMatchingSavedPlace(startPt.latitude, startPt.longitude);

      final title = matchedPlace != null
          ? 'Stayed at ${matchedPlace.name}'
          : (startPt.placeName != null ? 'Stayed at ${startPt.placeName}' : 'Stationary Stay');

      final address = matchedPlace?.address ??
          startPt.address ??
          '${startPt.latitude.toStringAsFixed(4)}, ${startPt.longitude.toStringAsFixed(4)}';

      final icon = matchedPlace?.iconData ?? Icons.home_work_rounded;
      final color = matchedPlace?.color ?? AppColors.primary;

      items.add(
        HistoryTimelineItem(
          id: startPt.id,
          type: TimelineItemType.stay,
          title: title,
          address: address,
          startTime: start,
          endTime: end,
          durationText: '$durationStr ($timeRangeStr)',
          icon: icon,
          color: color,
          activity: MovementActivity.stationary,
          polylinePoints: groupPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        ),
      );
    } else {
      final isDriving = activity == MovementActivity.driving;
      final avgSpeed = groupPoints.fold(0.0, (sum, p) => sum + p.speedMph) / groupPoints.length;

      items.add(
        HistoryTimelineItem(
          id: startPt.id,
          type: TimelineItemType.trip,
          title: isDriving ? 'Driving Trip (${avgSpeed.toStringAsFixed(0)} mph)' : 'Walking Trip',
          address: 'From ${startPt.latitude.toStringAsFixed(3)}, ${startPt.longitude.toStringAsFixed(3)} to ${endPt.latitude.toStringAsFixed(3)}, ${endPt.longitude.toStringAsFixed(3)}',
          startTime: start,
          endTime: end,
          durationText: '$durationStr • $timeRangeStr',
          icon: isDriving ? Icons.directions_car_rounded : Icons.directions_walk_rounded,
          color: isDriving ? AppColors.teal : AppColors.pinWarning,
          activity: activity,
          distanceMiles: (diffMinutes * 0.4).clamp(0.5, 25.0),
          polylinePoints: groupPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
        ),
      );
    }
  }

  for (final pt in points) {
    if (currentActivity == null || currentActivity != pt.movementActivity) {
      finalizeGroup();
      currentGroupStart = pt;
      currentGroupEnd = pt;
      currentActivity = pt.movementActivity;
      groupPoints.clear();
      groupPoints.add(pt);
    } else {
      currentGroupEnd = pt;
      groupPoints.add(pt);
    }
  }

  finalizeGroup();
  return items;
}

List<LocationHistoryPoint> _generateMockPoints(DateTime now, int timeframeIndex) {
  const baseLat = 33.6844;
  const baseLng = 73.0479;

  final points = <LocationHistoryPoint>[];
  final count = timeframeIndex == 0 ? 6 : (timeframeIndex == 1 ? 12 : 20);

  for (int i = 0; i < count; i++) {
    final offsetHours = i * (timeframeIndex == 0 ? 2 : (timeframeIndex == 1 ? 12 : 36));
    final timestamp = now.subtract(Duration(hours: offsetHours));
    final activity = i % 3 == 0
        ? MovementActivity.stationary
        : (i % 3 == 1 ? MovementActivity.driving : MovementActivity.walking);

    points.add(
      LocationHistoryPoint(
        id: 'mock_$i',
        latitude: baseLat + (i * 0.003),
        longitude: baseLng + (i * 0.004),
        speedMph: activity == MovementActivity.driving ? 32.5 : (activity == MovementActivity.walking ? 3.2 : 0.0),
        movementActivity: activity,
        timestamp: timestamp,
        expireAt: timestamp.add(const Duration(days: 30)),
        address: activity == MovementActivity.stationary
            ? (i == 0 ? 'Home Base, Sector F-7' : 'Office Hub, Blue Area')
            : 'En route via Main Boulevard',
        placeName: activity == MovementActivity.stationary ? (i == 0 ? 'Home' : 'Work Place') : null,
      ),
    );
  }

  return points;
}
