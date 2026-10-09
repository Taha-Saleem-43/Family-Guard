import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';
import 'package:family_guard/features/sos/models/sos_alert.dart';
import 'package:family_guard/features/sos/providers/sos_provider.dart';
import 'package:family_guard/features/sos/services/sos_service.dart';
import 'package:family_guard/features/sos/services/sos_dismissal_store.dart';
import 'package:family_guard/features/sos/presentation/widgets/emergency_host.dart';

class StreamSOSService extends SOSService {
  final alerts = StreamController<List<SOSAlert>>.broadcast();
  @override
  Stream<List<SOSAlert>> streamActiveSOSAlerts(String circleId) =>
      alerts.stream;
}

class DeferredSOSService extends StreamSOSService {
  final result = Completer<String?>();
  @override
  Future<String?> triggerSOS({
    required String circleId,
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
    String address = 'Live Location Broadcast',
  }) => result.future;
}

SOSAlert alert(String id, String sender) => SOSAlert(
  id: id,
  senderId: sender,
  senderName: sender,
  circleId: 'circle',
  timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'dismissed receiver alert stays silent after provider recreation',
    () async {
      final service = StreamSOSService();
      var sounds = 0;
      ProviderContainer session() {
        final container = ProviderContainer(
          overrides: [
            sosProvider.overrideWith(
              (ref) => SOSNotifier(
                ref,
                service: service,
                receiverAlarm: () async {
                  sounds++;
                },
              ),
            ),
          ],
        );
        final app = container.read(appStateProvider.notifier);
        app.setUserId('self');
        app.setCircleId('circle');
        container.read(sosProvider);
        return container;
      }

      final first = session();
      service.alerts.add([alert('persisted', 'parent')]);
      await flush();
      expect(sounds, 1);
      first.read(sosProvider.notifier).dismissReceiverAlert('persisted');
      await flush();
      expect(
        await PreferencesSOSDismissalStore().load('self', 'circle'),
        contains('persisted'),
      );
      first.dispose();
      final second = session();
      addTearDown(() async {
        second.dispose();
        await service.alerts.close();
      });
      service.alerts.add([alert('persisted', 'parent')]);
      await flush();
      expect(second.read(sosProvider).unhandledCircleEmergency, isNull);
      expect(sounds, 1);
      expect(
        await PreferencesSOSDismissalStore().load('other', 'circle'),
        isEmpty,
      );
    },
  );

  test(
    'late send completion cannot restore an emergency after account switch',
    () async {
      final service = DeferredSOSService();
      final container = ProviderContainer(
        overrides: [
          sosProvider.overrideWith(
            (ref) =>
                SOSNotifier(ref, service: service, receiverAlarm: () async {}),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.alerts.close();
      });
      final app = container.read(appStateProvider.notifier);
      app.setUserId('first');
      app.setCircleId('circle');
      final send = container.read(sosProvider.notifier).triggerEmergency();
      app.setUserId('second');
      service.result.complete('first-alert');
      expect(await send, isFalse);
      expect(container.read(sosProvider).activeAlertId, isNull);
      expect(container.read(sosProvider).isSelfSosActive, isFalse);
    },
  );

  test(
    'confirmed stream restores own alert and clears it after server resolution',
    () async {
      final service = StreamSOSService();
      final container = ProviderContainer(
        overrides: [
          sosProvider.overrideWith(
            (ref) =>
                SOSNotifier(ref, service: service, receiverAlarm: () async {}),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.alerts.close();
      });
      final app = container.read(appStateProvider.notifier);
      app.setUserId('self');
      app.setCircleId('circle');
      container.read(sosProvider);
      service.alerts.add([alert('own', 'self')]);
      await flush();
      final restored = container.read(sosProvider);
      expect(restored.activeAlertId, 'own');
      expect(restored.isSelfSosActive, isTrue);
      expect(restored.activeDurationSeconds, greaterThanOrEqualTo(120));
      service.alerts.addError(StateError('connection lost'));
      await flush();
      expect(container.read(sosProvider).activeAlertId, 'own');
      expect(container.read(sosProvider).updatesUnavailable, isTrue);
      service.alerts.add([]);
      await flush();
      expect(container.read(sosProvider).isSelfSosActive, isFalse);
      expect(container.read(sosProvider).activeAlertId, isNull);
      expect(container.read(sosProvider).sosStartTime, isNull);
      expect(container.read(sosProvider).updatesUnavailable, isFalse);
    },
  );

  test(
    'repeated snapshots sound once and same-circle account switch resets identity',
    () async {
      final service = StreamSOSService();
      var sounds = 0;
      final container = ProviderContainer(
        overrides: [
          sosProvider.overrideWith(
            (ref) => SOSNotifier(
              ref,
              service: service,
              receiverAlarm: () async {
                sounds++;
              },
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await service.alerts.close();
      });
      final app = container.read(appStateProvider.notifier);
      app.setUserId('self');
      app.setCircleId('circle');
      container.read(sosProvider);
      service.alerts.add([alert('other', 'parent')]);
      await flush();
      service.alerts.add([alert('other', 'parent')]);
      await flush();
      expect(sounds, 1);
      container.read(sosProvider.notifier).dismissReceiverAlert('other');
      service.alerts.add([alert('other', 'parent')]);
      await flush();
      expect(container.read(sosProvider).unhandledCircleEmergency, isNull);
      expect(sounds, 1);
      app.setUserId('parent');
      service.alerts.add([alert('other', 'parent')]);
      await flush();
      expect(container.read(sosProvider).activeAlertId, 'other');
      expect(container.read(sosProvider).activeCircleAlerts, isEmpty);
      expect(container.read(sosProvider).handledAlertIds, isEmpty);
    },
  );

  testWidgets('receiver emergency remains above content when tabs change', (
    tester,
  ) async {
    final service = StreamSOSService();
    final container = ProviderContainer(
      overrides: [
        sosProvider.overrideWith(
          (ref) =>
              SOSNotifier(ref, service: service, receiverAlarm: () async {}),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await service.alerts.close();
    });
    final app = container.read(appStateProvider.notifier);
    app.setUserId('self');
    app.setCircleId('circle');
    Widget page(String tab) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: EmergencyHost(child: Scaffold(body: Text(tab))),
      ),
    );
    await tester.pumpWidget(page('Settings tab'));
    service.alerts.add([alert('incoming', 'parent')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('EMERGENCY SOS ALERT'), findsOneWidget);
    await tester.pumpWidget(page('History tab'));
    expect(find.text('EMERGENCY SOS ALERT'), findsOneWidget);
    expect(find.text('History tab'), findsOneWidget);
    await tester.tap(find.text('Dismiss Alarm'));
    await tester.pump();
    expect(find.text('EMERGENCY SOS ALERT'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
