import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_guard/core/models/alert_event.dart';
import 'package:family_guard/features/alerts/presentation/alerts_screen.dart';
import 'package:family_guard/features/alerts/providers/place_events_provider.dart';
import 'package:family_guard/features/sos/models/sos_alert.dart';
import 'package:family_guard/features/sos/providers/sos_provider.dart';

void main() {
  testWidgets(
    'place activity merges with SOS and hides stale events after a stream error',
    (tester) async {
      final events = StreamController<List<AlertEvent>>();
      addTearDown(events.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            circlePlaceEventsProvider.overrideWith((ref) => events.stream),
            circleSosHistoryProvider.overrideWith(
              (ref) => Stream.value([
                SOSAlert(
                  id: 'sos',
                  senderId: 'child',
                  senderName: 'Child',
                  circleId: 'circle',
                  timestamp: DateTime.now(),
                  status: 'resolved',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: AlertsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      events.add([
        AlertEvent(
          id: 'arrival',
          memberId: 'child',
          memberName: 'Child',
          memberColor: Colors.teal,
          placeName: 'Home',
          type: AlertEventType.arrive,
          timestamp: DateTime.now(),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Child arrived at Home'), findsOneWidget);
      expect(find.text('Emergency Alert Resolved'), findsOneWidget);
      events.addError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Child arrived at Home'), findsNothing);
      expect(find.text('Emergency Alert Resolved'), findsOneWidget);
      expect(
        find.text('Place activity is temporarily unavailable.'),
        findsOneWidget,
      );
    },
  );
}
