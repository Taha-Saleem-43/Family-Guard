import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:family_guard/core/services/location_outbox.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late LocationOutbox store;
  final now = DateTime.now().millisecondsSinceEpoch;
  Map<String, Object> fix(String id, int time) => {
    'id': id,
    'capturedAt': time,
    'accuracyMeters': 12.5,
  };
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('family-guard-outbox-');
    store = LocationOutbox(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/queue.db',
    );
    await store.activate('one', 'circle', now);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  test(
    'durable fixes survive restart and duplicates remain single records',
    () async {
      await store.enqueue('one', 'circle', fix('a', now), now);
      await store.enqueue('one', 'circle', fix('a', now), now);
      await store.close();
      final lease = await store.claim('one', now);
      expect(lease!.fixes.length, 1);
      expect(lease.fixes.single['accuracyMeters'], 12.5);
      await store.acknowledge(lease, ['a']);
      expect(await store.claim('one', now), isNull);
    },
  );
  test('only one claimant proceeds and an expired lease can recover', () async {
    await store.enqueue('one', 'circle', fix('a', now), now);
    final claims = await Future.wait([
      store.claim('one', now),
      store.claim('one', now),
    ]);
    expect(claims.whereType<LocationLease>().length, 1);
    final original = claims.whereType<LocationLease>().single;
    final recovered = (await store.claim('one', now + 120001))!;
    await store.acknowledge(original, ['a']);
    expect(await store.claim('one', now + 120002), isNull);
    await store.acknowledge(recovered, ['a']);
    expect(await store.claim('one', now + 240002), isNull);
  });
  test(
    'logout fences enqueue and late retry cannot recreate erased data',
    () async {
      await store.activate('two', 'other', now);
      await store.enqueue('two', 'other', fix('b', now), now);
      await store.enqueue('one', 'circle', fix('a', now), now);
      final lease = (await store.claim('one', now))!;
      await store.deactivate('one');
      await store.retry(lease, now);
      expect(await store.enqueue('one', 'circle', fix('c', now), now), false);
      expect(await store.claim('one', now + 1000000), isNull);
      expect((await store.claim('two', now))!.fixes.single['id'], 'b');
    },
  );
  test(
    'new circle and session reject captures from an earlier account session',
    () async {
      await store.enqueue('one', 'circle', fix('old', now), now);
      await store.activate('one', 'new-circle', now + 100);
      expect(
        await store.enqueue('one', 'circle', fix('a', now + 200), now + 200),
        false,
      );
      expect(
        await store.enqueue('one', 'new-circle', fix('b', now), now + 200),
        false,
      );
      expect(await store.claim('one', now + 200), isNull);
    },
  );
  test('failed delivery backs off before becoming claimable again', () async {
    await store.enqueue('one', 'circle', fix('a', now), now);
    final lease = (await store.claim('one', now))!;
    await store.retry(lease, now);
    expect(await store.claim('one', now + 14999), isNull);
    expect(await store.claim('one', now + 15000), isNotNull);
  });
  test(
    'sampling persists after acknowledgement and older recovery preserves history',
    () async {
      Map<String, Object> position(String id, int time, double latitude) => {
        ...fix(id, time),
        'latitude': latitude,
        'longitude': 2.0,
        'movementActivity': 'stationary',
        'batteryLevel': 80,
        'isCharging': false,
      };
      await store.enqueue(
        'one',
        'circle',
        position('first', now + 10000, 1),
        now + 10000,
      );
      final initial = (await store.claim('one', now + 10000))!;
      await store.acknowledge(initial, ['first']);
      await store.close();
      await store.enqueue(
        'one',
        'circle',
        position('minor', now + 20000, 1.000001),
        now + 20000,
      );
      expect(await store.claim('one', now + 20000), isNull);
      await store.enqueue(
        'one',
        'circle',
        position('recovered', now + 5000, 1),
        now + 20000,
        recovery: true,
      );
      expect(
        (await store.claim('one', now + 20000))!.fixes.single['id'],
        'recovered',
      );
    },
  );
  test(
    'a newer sign-in invalidates even an enabled session left by failed cleanup',
    () async {
      await store.enqueue('one', 'circle', fix('prior-login', now), now);
      final started = await store.activate(
        'one',
        'circle',
        now + 1000,
        minimumStartedAt: now + 500,
      );
      expect(started, now + 1000);
      expect(await store.claim('one', now + 1000), isNull);
      expect(
        await store.enqueue(
          'one',
          'circle',
          fix('signed-out-time', now + 700),
          now + 1000,
        ),
        false,
      );
    },
  );
}
