import 'dart:async';
import 'package:family_guard/core/models/location_history_page.dart';
import 'package:family_guard/core/models/location_history_point.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/services/firestore_location_service.dart';
import 'package:family_guard/features/history/providers/history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:family_guard/features/history/presentation/history_screen.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptedPages extends FirestoreLocationService {
  final List<Future<LocationHistoryPage> Function()> responses;
  final requests =
      <
        ({
          String uid,
          String? circle,
          DateTime start,
          DateTime end,
          HistoryCursor? cursor,
        })
      >[];
  ScriptedPages(this.responses);
  @override
  Future<LocationHistoryPage> fetchHistoryPage({
    required String uid,
    String? circleId,
    required DateTime startDate,
    required DateTime endDate,
    HistoryCursor? cursor,
    int pageSize = 200,
  }) {
    requests.add((
      uid: uid,
      circle: circleId,
      start: startDate,
      end: endDate,
      cursor: cursor,
    ));
    return responses[requests.length - 1]();
  }
}

LocationHistoryPoint point(String id) => LocationHistoryPoint(
  id: id,
  latitude: 33,
  longitude: 73,
  speedMph: 0,
  movementActivity: MovementActivity.stationary,
  timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
  expireAt: DateTime.now().add(const Duration(days: 30)),
);
LocationHistoryPage page(String id, {bool more = false}) {
  final value = point(id);
  return LocationHistoryPage(
    points: [value],
    nextCursor: more ? HistoryCursor(value.timestamp, id) : null,
  );
}

ProviderContainer session(ScriptedPages service) {
  final container = ProviderContainer(
    overrides: [firestoreLocationServiceProvider.overrideWithValue(service)],
  );
  container.read(appStateProvider.notifier).setUserId('first');
  return container;
}

void main() {
  testWidgets(
    'load older history keeps data visible on failure and allows retry',
    (tester) async {
      final gate = Completer<LocationHistoryPage>();
      final service = ScriptedPages([
        () async => page('newest', more: true),
        () => gate.future,
        () async => page('older'),
      ]);
      final container = session(service);
      var disposed = false;
      addTearDown(() {
        if (!disposed) container.dispose();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Load older history'));
      await tester.tap(find.text('Load older history'));
      await tester.pump();
      expect(find.text('Loading older history…'), findsOneWidget);
      gate.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load older history. Try again.'),
        findsOneWidget,
      );
      expect(
        container.read(rawLocationHistoryProvider).requireValue.single.id,
        'newest',
      );
      await tester.tap(find.text('Load older history'));
      await tester.pumpAndSettle();
      expect(find.text('Load older history'), findsNothing);
      expect(container.read(rawLocationHistoryProvider).requireValue.length, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      disposed = true;
    },
  );
  test(
    'older-page failure retains loaded data, retries the same cursor and deduplicates points',
    () async {
      final service = ScriptedPages([
        () async => page('newest', more: true),
        () async => throw StateError('offline'),
        () async =>
            LocationHistoryPage(points: [point('newest'), point('older')]),
      ]);
      final container = session(service);
      addTearDown(container.dispose);
      await container.read(rawLocationHistoryProvider.future);
      final pager = container.read(rawLocationHistoryProvider.notifier);
      await pager.loadMore();
      expect(
        container
            .read(rawLocationHistoryProvider)
            .requireValue
            .map((p) => p.id),
        ['newest'],
      );
      expect(pager.moreError, isNotNull);
      expect(container.read(rawLocationHistoryProvider).hasError, false);
      await pager.loadMore();
      expect(
        container
            .read(rawLocationHistoryProvider)
            .requireValue
            .map((p) => p.id),
        ['newest', 'older'],
      );
      expect(pager.hasMore, false);
      expect(pager.moreError, isNull);
      expect(
        identical(service.requests[1].cursor, service.requests[2].cursor),
        true,
      );
      expect(service.requests[2].end, service.requests[0].end);
    },
  );
  test(
    'late older-page results cannot restore history after an account change',
    () async {
      final oldMore = Completer<LocationHistoryPage>();
      final newInitial = Completer<LocationHistoryPage>();
      final service = ScriptedPages([
        () async => page('old', more: true),
        () => oldMore.future,
        () => newInitial.future,
      ]);
      final container = session(service);
      addTearDown(container.dispose);
      await container.read(rawLocationHistoryProvider.future);
      final oldRequest = container
          .read(rawLocationHistoryProvider.notifier)
          .loadMore();
      container.read(appStateProvider.notifier).setUserId('second');
      final newRequest = container.read(rawLocationHistoryProvider.future);
      expect(container.read(historyRoutePolylineProvider), isEmpty);
      expect(container.read(historyTimelineProvider), isEmpty);
      newInitial.complete(page('current'));
      await newRequest;
      oldMore.complete(page('late-old', more: true));
      await oldRequest;
      expect(
        container.read(rawLocationHistoryProvider).requireValue.single.id,
        'current',
      );
      expect(
        container.read(rawLocationHistoryProvider.notifier).hasMore,
        false,
      );
      expect(service.requests.last.uid, 'second');
    },
  );
  test(
    'repeated load-more actions issue only one request while a page is pending',
    () async {
      final gate = Completer<LocationHistoryPage>();
      final service = ScriptedPages([
        () async => page('first', more: true),
        () => gate.future,
      ]);
      final container = session(service);
      addTearDown(container.dispose);
      await container.read(rawLocationHistoryProvider.future);
      final pager = container.read(rawLocationHistoryProvider.notifier);
      final pending = pager.loadMore();
      await pager.loadMore();
      expect(service.requests.length, 2);
      gate.complete(page('second'));
      await pending;
      expect(pager.loadingMore, false);
      expect(container.read(rawLocationHistoryProvider).requireValue.length, 2);
    },
  );
}
