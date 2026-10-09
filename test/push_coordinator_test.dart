import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:family_guard/core/providers/push_coordinator.dart';
import 'package:family_guard/core/services/push_registration_store.dart';
import 'package:family_guard/core/models/push_envelope.dart';
import 'package:family_guard/features/sos/models/push_delivery_summary.dart';

void main() {
  test('FCM acceptance is counted separately from receipt and opening', () {
    final summary = PushDeliverySummary.fromJobs([
      {'status': 'sent'},
      {
        'status': 'sent',
        'receivedAt': DateTime.utc(2026),
        'openedAt': DateTime.utc(2026),
      },
      {'status': 'pending'},
      {'status': 'failed'},
    ]);
    expect(summary.accepted, 2);
    expect(summary.received, 1);
    expect(summary.opened, 1);
    expect(summary.pending, 1);
    expect(summary.failed, 1);
  });
  test(
    'persistent revisions serialize across registration-store recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final results = await Future.wait(
        List.generate(20, (_) => PushRegistrationStore().next()),
      );
      expect(results.map((item) => item.installationId).toSet(), hasLength(1));
      expect(
        results.map((item) => item.version).toList(),
        List.generate(20, (index) => index + 1),
      );
    },
  );
  test(
    'invalid payloads are rejected and acknowledgements bind the recipient',
    () {
      final data = <String, dynamic>{
        'type': 'sos',
        'schemaVersion': '1',
        'alertId': 'alert',
        'circleId': 'circle',
        'recipientUid': 'user',
        'installationId': 'a' * 32,
        'registrationVersion': '1',
      };
      expect(
        PushEnvelope.parse(data)!.acknowledgement('opened')['expectedUid'],
        'user',
      );
      expect(PushEnvelope.parse({...data, 'type': 'place'})!.type, 'place');
      for (final change in [
        {'type': 'other'},
        {'registrationVersion': '0'},
        {'circleId': '../other'},
        {'recipientUid': null},
      ]) {
        expect(PushEnvelope.parse({...data, ...change}), isNull);
      }
    },
  );
  test('late token result cannot register an old account', () async {
    String? uid = 'old';
    final oldToken = Completer<String?>();
    var tokenCalls = 0;
    var version = 0;
    final registrations = <String>[];
    final coordinator = PushCoordinator(
      permission: () async => true,
      token: () =>
          ++tokenCalls == 1 ? oldToken.future : Future.value('new-token'),
      nextRegistration: () async => PushDeviceRegistration('a' * 32, ++version),
      register: (session, _, _) async => registrations.add(session.uid),
      unregister: (_, _) async {},
      deleteToken: () async {},
      currentUid: () => uid,
    );
    addTearDown(coordinator.dispose);
    final oldBind = coordinator.bind('old', 'circle');
    await Future<void>.delayed(Duration.zero);
    uid = 'new';
    await coordinator.bind('new', 'circle');
    oldToken.complete('old-token');
    await oldBind;
    expect(registrations, ['new']);
    expect(coordinator.state.status, PushStatus.ready);
  });
  test(
    'registration failure retries and unchanged tokens avoid repeated writes',
    () async {
      var attempts = 0;
      var version = 0;
      final coordinator = PushCoordinator(
        permission: () async => true,
        token: () async => 'token',
        nextRegistration: () async =>
            PushDeviceRegistration('a' * 32, ++version),
        register: (_, _, _) async {
          if (++attempts == 1) throw StateError('offline');
        },
        unregister: (_, _) async {},
        deleteToken: () async {},
        currentUid: () => 'user',
      );
      addTearDown(coordinator.dispose);
      await coordinator.bind('user', 'circle');
      expect(coordinator.state.status, PushStatus.unavailable);
      await coordinator.refresh();
      expect(coordinator.state.status, PushStatus.ready);
      await coordinator.refresh();
      expect(attempts, 2);
    },
  );
  test(
    'denied permission disables an older registration on cold startup',
    () async {
      var disables = 0;
      var version = 0;
      final coordinator = PushCoordinator(
        permission: () async => false,
        token: () async => throw StateError('must not fetch'),
        nextRegistration: () async =>
            PushDeviceRegistration('a' * 32, ++version),
        register: (_, _, _) async {},
        unregister: (_, _) async => disables++,
        deleteToken: () async {},
        currentUid: () => 'user',
      );
      addTearDown(coordinator.dispose);
      await coordinator.bind('user', 'circle');
      await coordinator.refresh();
      expect(coordinator.state.status, PushStatus.denied);
      expect(disables, 1);
    },
  );
  test('logout remains available when backend revocation fails', () async {
    var deletes = 0;
    var version = 0;
    final coordinator = PushCoordinator(
      permission: () async => true,
      token: () async => 'token',
      nextRegistration: () async => PushDeviceRegistration('a' * 32, ++version),
      register: (_, _, _) async {},
      unregister: (_, _) async => throw StateError('offline'),
      deleteToken: () async => deletes++,
      currentUid: () => 'user',
    );
    addTearDown(coordinator.dispose);
    await coordinator.bind('user', 'circle');
    await coordinator.detach('user');
    expect(coordinator.state.status, PushStatus.signedOut);
    expect(deletes, 1);
  });
}
