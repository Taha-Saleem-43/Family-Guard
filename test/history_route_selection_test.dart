import 'package:family_guard/core/models/location_history_page.dart';
import 'package:family_guard/core/models/location_history_point.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/history/providers/history_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'history_pagination_test.dart' show ScriptedPages, session;

void main() {
  LocationHistoryPoint fix(String id, int seconds, MovementActivity activity) =>
      LocationHistoryPoint(
        id: id,
        latitude: 33 + seconds / 10000,
        longitude: 73,
        speedMph: 2,
        movementActivity: activity,
        timestamp: DateTime(2026, 10, 13, 12).add(Duration(seconds: seconds)),
        expireAt: DateTime(2026, 11, 12),
      );

  test(
    'selected segment filters route; Show all restores chronological points',
    () async {
      final points = [
        fix('last', 90, MovementActivity.walking),
        fix('middle', 30, MovementActivity.walking),
        fix('first', 0, MovementActivity.stationary),
      ];
      final container = session(
        ScriptedPages([() async => LocationHistoryPage(points: points)]),
      );
      addTearDown(container.dispose);
      await container.read(rawLocationHistoryProvider.future);
      expect(container.read(historyRoutePolylineProvider).first.latitude, 33);
      container.read(selectedHistoryTimelineIdProvider.notifier).state =
          'middle';
      expect(container.read(historyRoutePolylineProvider), hasLength(2));
      container.read(selectedHistoryTimelineIdProvider.notifier).state = null;
      expect(container.read(historyRoutePolylineProvider), hasLength(3));
    },
  );

  test(
    'single stationary capture is not labelled an arrival or zero-minute stay',
    () async {
      final container = session(
        ScriptedPages([
          () async => LocationHistoryPage(
            points: [fix('first', 0, MovementActivity.stationary)],
          ),
        ]),
      );
      addTearDown(container.dispose);
      await container.read(rawLocationHistoryProvider.future);
      final label = container.read(historyTimelineProvider).single.durationText;
      expect(label, contains('< 1 min'));
      expect(label, contains('Captured at'));
      expect(label, isNot(contains('Arrived')));
    },
  );

  test('selection resets on timeframe and identity changes', () async {
    final container = session(
      ScriptedPages(
        List.generate(
          3,
          (_) =>
              () async => LocationHistoryPage(
                points: [fix('first', 0, MovementActivity.stationary)],
              ),
        ),
      ),
    );
    addTearDown(container.dispose);
    await container.read(rawLocationHistoryProvider.future);
    container.read(selectedHistoryTimelineIdProvider.notifier).state = 'first';
    container.read(selectedHistoryTimeframeProvider.notifier).state = 1;
    expect(container.read(selectedHistoryTimelineIdProvider), isNull);
    await container.read(rawLocationHistoryProvider.future);
    container.read(selectedHistoryTimelineIdProvider.notifier).state = 'first';
    container.read(appStateProvider.notifier).setUserId('replacement');
    expect(container.read(selectedHistoryTimelineIdProvider), isNull);
    await container.read(rawLocationHistoryProvider.future);
  });
}
