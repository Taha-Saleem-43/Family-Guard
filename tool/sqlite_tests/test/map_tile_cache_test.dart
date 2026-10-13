import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:family_guard/core/services/map_tile_cache.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late MapTileCache store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('family-guard-tiles-');
    store = MapTileCache(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/tiles.db',
      maxBytes: 24,
    );
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  CachedMapTile tile(int value) => CachedMapTile(
    Uint8List.fromList(List.filled(12, value)),
    {'etag': 'v$value'},
    DateTime.utc(2026, 10, 20),
  );

  test(
    'persists bytes, validators and expiry across restart and erases on clear',
    () async {
      await store.write('https://tile.openstreetmap.org/1/2/3.png', tile(1));
      await store.close();
      final restored = await store.read(
        'https://tile.openstreetmap.org/1/2/3.png',
      );
      expect(restored!.bytes, tile(1).bytes);
      expect(restored.headers, {'etag': 'v1'});
      expect(restored.expires, tile(1).expires);
      final epoch = store.generation;
      await store.clear();
      expect(store.generation, greaterThan(epoch));
      await store.close();
      expect(
        await store.read('https://tile.openstreetmap.org/1/2/3.png'),
        isNull,
      );
    },
  );

  test(
    'storage remains bounded and updates replace rather than duplicate tiles',
    () async {
      await store.write('a', tile(1));
      await store.write('a', tile(2));
      await store.write('b', tile(3));
      expect((await store.read('a'))!.headers['etag'], 'v2');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.write('c', tile(4));
      expect(await store.read('a'), isNull);
      expect(await store.read('b'), isNotNull);
      expect(await store.read('c'), isNotNull);
    },
  );
}
