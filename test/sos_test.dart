import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_guard/core/models/member.dart';
import 'package:family_guard/core/models/movement_activity.dart';
import 'package:family_guard/features/sos/models/sos_alert.dart';
import 'package:family_guard/features/sos/providers/sos_provider.dart';
import 'package:family_guard/features/sos/services/sos_service.dart';
import 'package:family_guard/core/providers/app_state_provider.dart';

class FailingSOSService extends SOSService {
  @override
  Future<String?> triggerSOS({
    required String circleId,
    required String userId,
    required String userName,
    double? latitude,
    double? longitude,
    String address = 'Live Location Broadcast',
  }) async => null;
  @override
  Future<bool> resolveSOS({
    required String alertId,
    required String userId,
    String? circleId,
  }) async => false;
  @override
  Stream<List<SOSAlert>> streamActiveSOSAlerts(String circleId) =>
      const Stream.empty();
}

class TestSOSNotifier extends SOSNotifier {
  TestSOSNotifier(super.ref) : super(service: FailingSOSService());
  void restoreActiveForTest() {
    state = SOSState(
      isSelfSosActive: true,
      activeAlertId: 'active',
      sosStartTime: DateTime(2026),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SOSAlert Model Unit Tests', () {
    test('fromMap and toMap serialize correctly', () {
      final now = DateTime.now();
      final alertMap = {
        'senderId': 'user_123',
        'senderName': 'Sarah',
        'circleId': 'circle_abc',
        'latitude': 33.6844,
        'longitude': 73.0479,
        'address': 'Main St, Sector F-6',
        'timestamp': now.toIso8601String(),
        'status': 'active',
        'resolvedAt': null,
        'resolvedBy': null,
        'durationSeconds': 0,
      };

      final alert = SOSAlert.fromMap('alert_1', alertMap);

      expect(alert.id, equals('alert_1'));
      expect(alert.senderId, equals('user_123'));
      expect(alert.senderName, equals('Sarah'));
      expect(alert.circleId, equals('circle_abc'));
      expect(alert.latitude, equals(33.6844));
      expect(alert.longitude, equals(73.0479));
      expect(alert.address, equals('Main St, Sector F-6'));
      expect(alert.isActive, isTrue);

      final reSerialized = alert.toMap();
      expect(reSerialized['senderId'], equals('user_123'));
      expect(reSerialized['status'], equals('active'));
    });

    test('currentDurationSeconds and formatting compute properly', () {
      final pastTime = DateTime.now().subtract(
        const Duration(minutes: 2, seconds: 15),
      );
      final alert = SOSAlert(
        id: 'alert_2',
        senderId: 'user_123',
        senderName: 'Alex',
        circleId: 'circle_abc',
        timestamp: pastTime,
        status: 'active',
      );

      expect(alert.currentDurationSeconds, greaterThanOrEqualTo(134));
      expect(alert.formattedDuration, contains('m'));
      expect(alert.formattedTicker, matches(r'^\d{2}:\d{2}$'));
    });

    test('resolved alert uses stored durationSeconds', () {
      final alert = SOSAlert(
        id: 'alert_3',
        senderId: 'user_123',
        senderName: 'Alex',
        circleId: 'circle_abc',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        status: 'resolved',
        resolvedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        durationSeconds: 300,
      );

      expect(alert.isActive, isFalse);
      expect(alert.currentDurationSeconds, equals(300));
      expect(alert.formattedDuration, equals('5m 0s'));
      expect(alert.formattedTicker, equals('05:00'));
    });
  });

  group('Member Model SOS Property Unit Tests', () {
    test(
      'Member defaults to isSosActive = false and updates with copyWith',
      () {
        final member = Member(
          id: 'm1',
          name: 'John',
          avatar: '👨',
          role: UserRole.parent,
          address: 'Home',
          lastSeen: DateTime.now(),
          batteryLevel: 90,
          speedMph: 0.0,
          movementActivity: MovementActivity.stationary,
        );

        expect(member.isSosActive, isFalse);

        final sosMember = member.copyWith(isSosActive: true);
        expect(sosMember.isSosActive, isTrue);
        expect(sosMember.id, equals('m1'));

        final resetMember = sosMember.copyWith(isSosActive: false);
        expect(resetMember.isSosActive, isFalse);
      },
    );
  });

  group('SOSState & SOSNotifier State Management Unit Tests', () {
    test(
      'failed sending stays inactive and failed resolution preserves alert',
      () async {
        final container = ProviderContainer(
          overrides: [sosProvider.overrideWith((ref) => TestSOSNotifier(ref))],
        );
        addTearDown(container.dispose);
        container.read(appStateProvider.notifier).setUserId('user');
        container.read(appStateProvider.notifier).setCircleId('circle');
        final notifier = container.read(sosProvider.notifier);
        expect(await notifier.triggerEmergency(), isFalse);
        expect(container.read(sosProvider).isSelfSosActive, isFalse);
        (notifier as TestSOSNotifier).restoreActiveForTest();
        expect(await notifier.resolveEmergency(), isFalse);
        expect(container.read(sosProvider).isSelfSosActive, isTrue);
        expect(container.read(sosProvider).activeAlertId, 'active');
      },
    );
    test(
      'resolution clears nullable alert fields while omitted fields persist',
      () {
        final active = SOSState(
          activeAlertId: 'a1',
          sosStartTime: DateTime(2026),
        );
        expect(active.copyWith(activeDurationSeconds: 1).activeAlertId, 'a1');
        final resolved = active.copyWith(
          activeAlertId: null,
          sosStartTime: null,
        );
        expect(resolved.activeAlertId, isNull);
        expect(resolved.sosStartTime, isNull);
      },
    );
    test('Initial SOSState defaults are clean', () {
      const state = SOSState();
      expect(state.isSelfSosActive, isFalse);
      expect(state.activeAlertId, isNull);
      expect(state.activeCircleAlerts, isEmpty);
      expect(state.activeDurationSeconds, equals(0));
      expect(state.handledAlertIds, isEmpty);
      expect(state.unhandledCircleEmergency, isNull);
    });

    test('unhandledCircleEmergency ignores handled alert IDs', () {
      final now = DateTime.now();
      final alert1 = SOSAlert(
        id: 'a1',
        senderId: 'user_2',
        senderName: 'Sarah',
        circleId: 'c1',
        timestamp: now,
      );
      final alert2 = SOSAlert(
        id: 'a2',
        senderId: 'user_3',
        senderName: 'Tom',
        circleId: 'c1',
        timestamp: now,
      );

      final state = SOSState(
        activeCircleAlerts: [alert1, alert2],
        handledAlertIds: {'a1'},
      );

      final unhandled = state.unhandledCircleEmergency;
      expect(unhandled, isNotNull);
      expect(unhandled!.id, equals('a2'));
      expect(unhandled.senderName, equals('Tom'));
    });

    test(
      'dismissReceiverAlert adds alert ID to handledAlertIds in SOSNotifier',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(sosProvider.notifier);
        expect(container.read(sosProvider).handledAlertIds, isEmpty);

        notifier.dismissReceiverAlert('a123');
        expect(container.read(sosProvider).handledAlertIds, contains('a123'));
      },
    );

    test(
      'SOSState.formattedActiveDuration formats minutes and seconds correctly',
      () {
        const state = SOSState(activeDurationSeconds: 125);
        expect(state.formattedActiveDuration, equals('02:05'));
      },
    );
  });
}
