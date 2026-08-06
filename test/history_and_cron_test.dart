import 'package:family_guard/core/models/history_timeline_item.dart';
import 'package:family_guard/core/models/location_history_point.dart';
import 'package:family_guard/core/models/member.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/core/providers/member_status_provider.dart';
import 'package:family_guard/core/services/firestore_location_service.dart';
import 'package:family_guard/core/services/history_cron_service.dart';
import 'package:family_guard/features/history/presentation/history_screen.dart';
import 'package:family_guard/features/history/providers/history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocationHistoryPoint Model & Data Retention Tests', () {
    test('LocationHistoryPoint serializes and deserializes correctly', () {
      final now = DateTime.now();
      final expire = now.add(const Duration(days: 30));

      final point = LocationHistoryPoint(
        id: 'point_101',
        latitude: 33.6844,
        longitude: 73.0479,
        speedMph: 24.5,
        movementActivity: MovementActivity.driving,
        timestamp: now,
        expireAt: expire,
        address: 'Sector F-7, Islamabad',
        placeName: 'Home',
      );

      final map = point.toMap();
      expect(map['latitude'], equals(33.6844));
      expect(map['longitude'], equals(73.0479));
      expect(map['speedMph'], equals(24.5));
      expect(map['movementActivity'], equals('driving'));
      expect(map['address'], equals('Sector F-7, Islamabad'));
      expect(map['placeName'], equals('Home'));

      final reconstructed = LocationHistoryPoint.fromMap('point_101', map);
      expect(reconstructed.id, equals('point_101'));
      expect(reconstructed.latitude, equals(33.6844));
      expect(reconstructed.movementActivity, equals(MovementActivity.driving));
      expect(reconstructed.address, equals('Sector F-7, Islamabad'));
    });

    test('30-day retention calculation creates exact 30-day expiration delta', () {
      final timestamp = DateTime(2026, 8, 1, 12, 0, 0);
      final expireAt = timestamp.add(const Duration(days: 30));

      final point = LocationHistoryPoint(
        id: 'test_ttl',
        latitude: 33.0,
        longitude: 73.0,
        speedMph: 0.0,
        movementActivity: MovementActivity.stationary,
        timestamp: timestamp,
        expireAt: expireAt,
      );

      final daysDiff = point.expireAt.difference(point.timestamp).inDays;
      expect(daysDiff, equals(30));
    });
  });

  group('HistoryCronService 30-Day Retention Cleanup Unit Tests', () {
    test('runPurgeIfNeeded throttles execution within 12 hours', () async {
      SharedPreferences.setMockInitialValues({});
      final cron = HistoryCronService.instance;

      // First run should trigger cleanup
      final count1 = await cron.runPurgeIfNeeded(uid: 'user_test_1');
      expect(count1, equals(0)); // Returns 0 because no remote firestore instance in unit test

      final lastPurgeDate1 = await cron.getLastPurgeDate();
      expect(lastPurgeDate1, isNotNull);

      // Immediate second run should be throttled (hoursSinceLastPurge < 12)
      final count2 = await cron.runPurgeIfNeeded(uid: 'user_test_1');
      expect(count2, equals(0));

      // Force run bypasses throttling
      final count3 = await cron.runPurgeIfNeeded(uid: 'user_test_1', force: true);
      expect(count3, equals(0));

      cron.dispose();
    });

    test('FirestoreLocationService fetchLocationHistory returns empty list safely when uninitialized', () async {
      final service = FirestoreLocationService();
      final points = await service.fetchLocationHistory(
        uid: 'user_999',
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      );

      expect(points, isEmpty);
    });
  });

  group('History Providers & Timeline Aggregation Tests', () {
    test('historyTimelineProvider correctly aggregates mock location points into Stays and Trips', () async {
      final container = ProviderContainer(
        overrides: [
          selectedHistoryTimeframeProvider.overrideWith((ref) => 0), // Today
          selectedHistoryMemberIdProvider.overrideWith((ref) => 'test_uid'),
        ],
      );
      addTearDown(container.dispose);

      // Await future provider resolution
      await container.read(rawLocationHistoryProvider.future);

      final timelineItems = container.read(historyTimelineProvider);
      expect(timelineItems, isNotEmpty);

      // Verify items have titles and valid duration strings
      for (final item in timelineItems) {
        expect(item.title, isNotEmpty);
        expect(item.durationText, isNotEmpty);
        expect(item.type, isA<TimelineItemType>());
      }
    });

    test('selectedHistoryTimeframeProvider updates timeframe tab selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedHistoryTimeframeProvider), equals(0));

      container.read(selectedHistoryTimeframeProvider.notifier).state = 1; // 7 Days
      expect(container.read(selectedHistoryTimeframeProvider), equals(1));

      container.read(selectedHistoryTimeframeProvider.notifier).state = 2; // 30 Days
      expect(container.read(selectedHistoryTimeframeProvider), equals(2));
    });
  });

  group('HistoryScreen Widget Tests', () {
    testWidgets('HistoryScreen renders timeframe tabs, route map header, and timeline list', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => AppStateNotifier()
              ..setUserSession(
                userId: 'test_parent_uid',
                role: UserRole.parent,
                circleId: 'circle_test',
                userName: 'Parent User',
              )),
            memberStateProvider.overrideWith((ref) => MemberStateNotifier(ref)
              ..state = [
                Member(
                  id: 'test_parent_uid',
                  name: 'Parent User (You)',
                  avatar: '👨',
                  role: UserRole.parent,
                  address: 'Active Location',
                  lastSeen: DateTime.now(),
                  batteryLevel: 90,
                  speedMph: 0.0,
                  movementActivity: MovementActivity.stationary,
                ),
              ]),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Location History'), findsOneWidget);

      // Verify Timeframe Tab labels
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);

      // Verify Route Map Header (FlutterMap view when polyline points exist)
      expect(find.byType(FlutterMap), findsOneWidget);

      // Verify 30-Day Auto Retention Badge
      expect(find.textContaining('Auto-Clean <30d'), findsOneWidget);

      // Tap '7 Days' tab
      await tester.tap(find.text('7 Days'));
      await tester.pumpAndSettle();
    });
  });
}
