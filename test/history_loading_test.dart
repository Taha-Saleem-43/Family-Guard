import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_guard/core/models/location_history_point.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/services/firestore_location_service.dart';
import 'package:family_guard/features/history/providers/history_provider.dart';
import 'package:family_guard/features/history/presentation/history_screen.dart';

class ControlledHistoryService extends FirestoreLocationService {
  final pending = Completer<List<LocationHistoryPoint>>();
  int calls = 0;
  bool failFirst = false;
  String? queriedUid;
  @override
  Future<List<LocationHistoryPoint>> fetchLocationHistory({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    queriedUid = uid;
    calls++;
    if (failFirst && calls == 1) throw StateError('Network unavailable');
    return pending.future;
  }
}

void main() {
  test('member selection resets when the account or circle changes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final app = container.read(appStateProvider.notifier);
    app.setUserId('first');
    app.setCircleId('a');
    container.read(selectedHistoryMemberIdProvider.notifier).state = 'relative';
    app.setUserId('second');
    expect(container.read(selectedHistoryMemberIdProvider), isNull);
    container.read(selectedHistoryMemberIdProvider.notifier).state = 'relative';
    app.setCircleId('b');
    expect(container.read(selectedHistoryMemberIdProvider), isNull);
  });

  test('a child selection cannot request another member history', () async {
    final service = ControlledHistoryService()..pending.complete([]);
    final container = ProviderContainer(
      overrides: [firestoreLocationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(appStateProvider.notifier).setUserId('child');
    container.read(selectedHistoryMemberIdProvider.notifier).state = 'parent';
    await container.read(rawLocationHistoryProvider.future);
    expect(service.queriedUid, 'child');
  });

  testWidgets('loading history does not claim there are no recorded points', (
    tester,
  ) async {
    final service = ControlledHistoryService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreLocationServiceProvider.overrideWithValue(service),
          appStateProvider.overrideWith(
            (ref) => AppStateNotifier()..setUserId('user'),
          ),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No Location History Yet'), findsNothing);
    service.pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No Location History Yet'), findsOneWidget);
  });

  testWidgets(
    'history error offers retry and successful retry shows actual empty state',
    (tester) async {
      final service = ControlledHistoryService()..failFirst = true;
      service.pending.complete([]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreLocationServiceProvider.overrideWithValue(service),
            appStateProvider.overrideWith(
              (ref) => AppStateNotifier()..setUserId('user'),
            ),
          ],
          child: const MaterialApp(home: HistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load location history.'), findsOneWidget);
      expect(find.text('No Location History Yet'), findsNothing);
      await tester.tap(find.text('Retry history'));
      await tester.pumpAndSettle();
      expect(service.calls, 2);
      expect(find.text('Could not load location history.'), findsNothing);
      expect(find.text('No Location History Yet'), findsOneWidget);
    },
  );
}
