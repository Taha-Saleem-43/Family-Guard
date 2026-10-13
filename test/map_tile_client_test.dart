import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:family_guard/core/services/map_tile_cache.dart';
import 'package:family_guard/core/services/map_tile_client.dart';

class MemoryTiles implements MapTileStore {
  final values = <String, CachedMapTile>{};
  @override
  int generation = 0;
  @override
  Future<CachedMapTile?> read(String url) async => values[url];
  @override
  Future<void> write(String url, CachedMapTile tile) async {
    values[url] = tile;
  }

  @override
  Future<void> remove(String url) async {
    values.remove(url);
  }

  @override
  Future<void> clear() async {
    generation++;
    values.clear();
  }
}

void main() {
  final tile = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
  final url = Uri.parse('https://tile.openstreetmap.org/12/1/2.png');
  final now = DateTime.utc(2026, 10, 13);

  test('fresh tiles survive a new client and avoid network requests', () async {
    final store = MemoryTiles();
    var calls = 0;
    final network = MockClient((request) async {
      calls++;
      expect(request.headers['User-Agent'], startsWith('FamilyGuard/'));
      expect(request.headers['Cache-Control'], isNull);
      return http.Response.bytes(
        tile,
        200,
        headers: {'cache-control': 'max-age=604800', 'etag': 'v1'},
      );
    });
    final client = MapTileClient(
      network: network,
      store: store,
      clock: () => now,
    );
    expect((await client.get(url)).bodyBytes, tile);
    final restarted = MapTileClient(
      network: network,
      store: store,
      clock: () => now.add(const Duration(days: 1)),
    );
    expect((await restarted.get(url)).bodyBytes, tile);
    expect(calls, 1);
  });

  test(
    'expired tiles revalidate, reuse 304 bytes, and renew cache lifetime',
    () async {
      final store = MemoryTiles();
      store.values[url.toString()] = CachedMapTile(tile, {
        'etag': 'v1',
        'last-modified': 'Mon, 12 Oct 2026 00:00:00 GMT',
      }, now.subtract(const Duration(days: 1)));
      final client = MapTileClient(
        store: store,
        clock: () => now,
        network: MockClient((request) async {
          expect(request.headers['If-None-Match'], 'v1');
          expect(request.headers['If-Modified-Since'], isNotNull);
          return http.Response(
            '',
            304,
            headers: {'cache-control': 'max-age=3600', 'etag': 'v1'},
          );
        }),
      );
      final result = await client.get(url);
      expect(result.statusCode, 200);
      expect(result.bodyBytes, tile);
      expect(
        store.values[url.toString()]!.expires,
        now.add(const Duration(hours: 1)),
      );
    },
  );

  test(
    'concurrent requests coalesce and deletion fences pending writes',
    () async {
      final store = MemoryTiles();
      final pending = Completer<http.Response>();
      var calls = 0;
      final client = MapTileClient(
        store: store,
        clock: () => now,
        network: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      final first = client.get(url);
      final second = client.get(url);
      await Future<void>.delayed(Duration.zero);
      await store.clear();
      pending.complete(http.Response.bytes(tile, 200));
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(store.values, isEmpty);
    },
  );

  test(
    'HTTP failure, invalid image and no-store response are never cached',
    () async {
      for (final response in [
        http.Response('error', 500),
        http.Response('not a tile', 200),
        http.Response.bytes(tile, 200, headers: {'cache-control': 'no-store'}),
      ]) {
        final store = MemoryTiles();
        final client = MapTileClient(
          store: store,
          clock: () => now,
          network: MockClient((_) async => response),
        );
        await client.get(url);
        expect(store.values, isEmpty);
      }
    },
  );

  test(
    'expiry honours max-age, age, no-cache, expires and seven-day fallback',
    () {
      expect(
        MapTileClient.expiry({
          'cache-control': 'public, max-age=120',
          'age': '20',
        }, now),
        now.add(const Duration(seconds: 100)),
      );
      expect(MapTileClient.expiry({'cache-control': 'no-cache'}, now), now);
      expect(MapTileClient.expiry({'cache-control': 'no-store'}, now), isNull);
      expect(
        MapTileClient.expiry({'expires': 'Wed, 14 Oct 2026 00:00:00 GMT'}, now),
        DateTime.utc(2026, 10, 14),
      );
      expect(MapTileClient.expiry({}, now), now.add(const Duration(days: 7)));
    },
  );

  test('a new no-store response removes previously persisted data', () async {
    final store = MemoryTiles();
    store.values[url.toString()] = CachedMapTile(tile, {'etag': 'old'}, now);
    final client = MapTileClient(
      store: store,
      clock: () => now,
      network: MockClient(
        (_) async => http.Response.bytes(
          tile,
          200,
          headers: {'cache-control': 'no-store'},
        ),
      ),
    );
    await client.get(url);
    expect(store.values, isEmpty);
    expect(
      MapTileClient.expiry({
        'cache-control': 'max-age=120',
        'date': 'Mon, 12 Oct 2026 23:59:30 GMT',
      }, now),
      now.add(const Duration(seconds: 90)),
    );
  });

  test(
    'a stalled connection times out, can retry, and cannot save a late response',
    () async {
      final store = MemoryTiles();
      final stalled = Completer<http.Response>();
      var calls = 0;
      final client = MapTileClient(
        store: store,
        clock: () => now,
        requestTimeout: const Duration(milliseconds: 20),
        network: MockClient((_) {
          calls++;
          return calls == 1
              ? stalled.future
              : Future.value(http.Response.bytes(tile, 200));
        }),
      );
      await expectLater(client.get(url), throwsA(isA<TimeoutException>()));
      expect(store.values, isEmpty);
      expect((await client.get(url)).bodyBytes, tile);
      await store.clear();
      stalled.complete(http.Response.bytes(tile, 200));
      await Future<void>.delayed(Duration.zero);
      expect(store.values, isEmpty);
      expect(calls, 2);
    },
  );
}
