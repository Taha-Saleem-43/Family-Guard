import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/services/tracking_lifecycle.dart';

void main() {
  test('a hung verification cannot indefinitely block a queued stop', () async {
    final pending = Completer<bool>();
    var stops = 0;
    final tracker = TrackingLifecycle(
      currentUid: () => 'child',
      verifyScope: (_, _) => pending.future,
      activate: (_, _) async {},
      deactivate: (_) async {},
      startNative: () async {},
      stopNative: () async {
        stops++;
      },
      operationTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(
      tracker.start('child', 'family'),
      throwsA(isA<TimeoutException>()),
    );
    await tracker.stop('child');
    expect(stops, 1);
  });
  test(
    'a pending old start is stopped before the replacement account starts',
    () async {
      var uid = 'old';
      final entered = Completer<void>(), release = Completer<void>();
      final events = <String>[];
      final tracker = TrackingLifecycle(
        currentUid: () => uid,
        verifyScope: (_, _) async => true,
        activate: (id, _) async => events.add('activate:$id'),
        deactivate: (id) async => events.add('deactivate:$id'),
        startNative: () async {
          events.add('start:$uid');
          if (uid == 'old') {
            entered.complete();
            await release.future;
          }
        },
        stopNative: () async => events.add('stop'),
      );
      final old = tracker.start('old', 'one');
      await entered.future;
      uid = 'new';
      final next = tracker.start('new', 'two');
      release.complete();
      await Future.wait([old, next]);
      expect(events, [
        'activate:old',
        'start:old',
        'deactivate:old',
        'stop',
        'activate:new',
        'start:new',
      ]);
      expect(tracker.activeScope, (uid: 'new', circleId: 'two'));
    },
  );
  test(
    'late cleanup for an old account leaves the new native tracker running',
    () async {
      var stops = 0;
      final removed = <String>[];
      final tracker = TrackingLifecycle(
        currentUid: () => 'new',
        verifyScope: (_, _) async => true,
        activate: (_, _) async {},
        deactivate: (uid) async => removed.add(uid),
        startNative: () async {},
        stopNative: () async {
          stops++;
        },
      );
      await tracker.start('new', 'two');
      await tracker.stop('old');
      expect(stops, 0);
      expect(removed, ['old']);
      expect(tracker.activeScope, (uid: 'new', circleId: 'two'));
    },
  );
  test(
    'failed local cleanup still attempts native stop and does not poison later starts',
    () async {
      var uid = 'old', stops = 0;
      final tracker = TrackingLifecycle(
        currentUid: () => uid,
        verifyScope: (_, _) async => true,
        activate: (_, _) async {},
        deactivate: (id) async {
          if (id == 'old') throw StateError('database unavailable');
        },
        startNative: () async {},
        stopNative: () async {
          stops++;
        },
      );
      await expectLater(tracker.stop('old'), throwsStateError);
      expect(stops, 1);
      uid = 'new';
      await tracker.start('new', 'two');
      expect(tracker.activeScope, (uid: 'new', circleId: 'two'));
    },
  );
  test('account changes during verification cannot activate sharing', () async {
    var uid = 'old', activations = 0, starts = 0;
    final pending = Completer<bool>(), entered = Completer<void>();
    final tracker = TrackingLifecycle(
      currentUid: () => uid,
      verifyScope: (_, _) {
        entered.complete();
        return pending.future;
      },
      activate: (_, _) async {
        activations++;
      },
      deactivate: (_) async {},
      startNative: () async {
        starts++;
      },
      stopNative: () async {},
    );
    final request = tracker.start('old', 'one');
    await entered.future;
    uid = 'new';
    pending.complete(true);
    await request;
    expect(activations, 0);
    expect(starts, 0);
  });
  test(
    'revoked membership stops existing sharing without starting a new context',
    () async {
      var starts = 0, stops = 0;
      final tracker = TrackingLifecycle(
        currentUid: () => 'child',
        verifyScope: (_, _) async => false,
        activate: (_, _) async => fail('Must not activate a revoked context'),
        deactivate: (_) async {},
        startNative: () async {
          starts++;
        },
        stopNative: () async {
          stops++;
        },
      );
      await tracker.start('child', 'family');
      expect(starts, 0);
      expect(stops, 1);
      expect(tracker.activeScope, isNull);
    },
  );
}
