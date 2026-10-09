import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/history_timeline_item.dart';
import '../../../core/models/location_history_point.dart';
import '../../../core/models/location_history_page.dart';
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
final selectedHistoryMemberIdProvider = StateProvider<String?>((ref) {
  ref.watch(appStateProvider.select((state) => (state.userId, state.circleId)));
  return null;
});

/// Firestore location service instance
final firestoreLocationServiceProvider = Provider(
  (ref) => FirestoreLocationService(),
);

/// Cron purge status provider
final historyCronStatusProvider = FutureProvider<DateTime?>((ref) async {
  return await HistoryCronService.instance.getLastPurgeDate();
});

/// Cursor pages retain a fixed time window and reject stale session results.
final rawLocationHistoryProvider =
    AsyncNotifierProvider<HistoryPager, List<LocationHistoryPoint>>(
      HistoryPager.new,
    );

typedef _HistoryWindow = ({
  String uid,
  String? circleId,
  DateTime start,
  DateTime end,
  FirestoreLocationService service,
});

class HistoryPager extends AsyncNotifier<List<LocationHistoryPoint>> {
  _HistoryWindow? _window;
  HistoryCursor? _cursor;
  int _generation = 0;
  bool _disposed = false;
  bool hasMore = false;
  bool loadingMore = false;
  String? moreError;

  @override
  Future<List<LocationHistoryPoint>> build() async {
    final generation = ++_generation;
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      ++_generation;
    });
    _cursor = null;
    _window = null;
    hasMore = false;
    loadingMore = false;
    moreError = null;
    final uid = ref.watch(appStateProvider.select((state) => state.userId));
    final circleId = ref.watch(
      appStateProvider.select((state) => state.circleId),
    );
    final role = ref.watch(appStateProvider.select((state) => state.role));
    final selection = ref.watch(selectedHistoryMemberIdProvider);
    final selectedMemberId = role == UserRole.parent ? selection ?? uid : uid;
    final timeframe = ref.watch(selectedHistoryTimeframeProvider);
    final service = ref.watch(firestoreLocationServiceProvider);
    if (selectedMemberId.isEmpty) return [];
    final now = DateTime.now();
    final start = timeframe == 1
        ? now.subtract(const Duration(days: 7))
        : timeframe == 2
        ? now.subtract(const Duration(days: 30))
        : DateTime(now.year, now.month, now.day);
    final window = (
      uid: selectedMemberId,
      circleId: selectedMemberId == uid ? null : circleId,
      start: start,
      end: now,
      service: service,
    );
    _window = window;
    final page = await service.fetchHistoryPage(
      uid: window.uid,
      circleId: window.circleId,
      startDate: window.start,
      endDate: window.end,
    );
    if (_disposed || generation != _generation) return [];
    _cursor = page.nextCursor;
    hasMore = page.hasMore;
    return page.points;
  }

  Future<void> loadMore() async {
    final window = _window;
    final cursor = _cursor;
    if (_disposed ||
        window == null ||
        cursor == null ||
        !hasMore ||
        loadingMore ||
        state.isLoading ||
        state.hasError) {
      return;
    }
    final generation = _generation;
    final current = state.requireValue;
    loadingMore = true;
    moreError = null;
    state = AsyncData(List.of(current));
    try {
      final page = await window.service.fetchHistoryPage(
        uid: window.uid,
        circleId: window.circleId,
        startDate: window.start,
        endDate: window.end,
        cursor: cursor,
      );
      if (_disposed || generation != _generation) return;
      _cursor = page.nextCursor;
      hasMore = page.hasMore;
      loadingMore = false;
      final byId = {for (final point in current) point.id: point};
      for (final point in page.points) {
        byId[point.id] = point;
      }
      state = AsyncData(byId.values.toList());
    } catch (_) {
      if (_disposed || generation != _generation) return;
      loadingMore = false;
      moreError = 'Could not load older history. Try again.';
      state = AsyncData(List.of(current));
    }
  }
}

/// Computes aggregated timeline items (Stays & Trips) from history points, matching saved places
final historyTimelineProvider = Provider<List<HistoryTimelineItem>>((ref) {
  final asyncPoints = ref.watch(rawLocationHistoryProvider);
  if (asyncPoints.isLoading || asyncPoints.hasError) return [];
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
  if (asyncPoints.isLoading || asyncPoints.hasError) return [];

  return asyncPoints.when(
    data: (points) =>
        points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
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
    final durationStr = diffMinutes > 60
        ? '${(diffMinutes / 60).toStringAsFixed(1)} hrs'
        : '$diffMinutes mins';
    final timeRangeStr =
        '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';

    if (activity == MovementActivity.stationary) {
      final matchedPlace = findMatchingSavedPlace(
        startPt.latitude,
        startPt.longitude,
      );

      final title = matchedPlace != null
          ? 'Stayed at ${matchedPlace.name}'
          : (startPt.placeName != null
                ? 'Stayed at ${startPt.placeName}'
                : 'Stationary Stay');

      final address =
          matchedPlace?.address ??
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
          polylinePoints: groupPoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
        ),
      );
    } else {
      final isDriving = activity == MovementActivity.driving;
      final avgSpeed =
          groupPoints.fold(0.0, (sum, p) => sum + p.speedMph) /
          groupPoints.length;

      items.add(
        HistoryTimelineItem(
          id: startPt.id,
          type: TimelineItemType.trip,
          title: isDriving
              ? 'Driving Trip (${avgSpeed.toStringAsFixed(0)} mph)'
              : 'Walking Trip',
          address:
              'From ${startPt.latitude.toStringAsFixed(3)}, ${startPt.longitude.toStringAsFixed(3)} to ${endPt.latitude.toStringAsFixed(3)}, ${endPt.longitude.toStringAsFixed(3)}',
          startTime: start,
          endTime: end,
          durationText: '$durationStr • $timeRangeStr',
          icon: isDriving
              ? Icons.directions_car_rounded
              : Icons.directions_walk_rounded,
          color: isDriving ? AppColors.teal : AppColors.pinWarning,
          activity: activity,
          distanceMiles: List.generate(
            groupPoints.length - 1,
            (i) => const Distance().as(
              LengthUnit.Mile,
              LatLng(groupPoints[i].latitude, groupPoints[i].longitude),
              LatLng(groupPoints[i + 1].latitude, groupPoints[i + 1].longitude),
            ),
          ).fold<double>(0.0, (total, distance) => total + distance),
          polylinePoints: groupPoints
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(),
        ),
      );
    }
  }

  final chronological = [...points]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  for (final pt in chronological) {
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
