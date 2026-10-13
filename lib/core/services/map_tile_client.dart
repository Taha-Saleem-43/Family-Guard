import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'map_tile_cache.dart';

/// Fetches only requested viewport tiles; no prefetch or offline-download API.
class MapTileClient extends http.BaseClient {
  final http.Client network;
  final MapTileStore store;
  final DateTime Function() clock;
  final _pending = <String, Future<http.Response>>{};
  int _generation = 0;
  bool _closed = false;

  MapTileClient({
    http.Client? network,
    MapTileStore? store,
    DateTime Function()? clock,
  }) : network = network ?? http.Client(),
       store = store ?? MapTileCache.shared,
       clock = clock ?? DateTime.now;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Map client is closed.');
    if (request.method != 'GET' ||
        request.url.host != 'tile.openstreetmap.org') {
      return network.send(request);
    }
    final key = request.url.toString();
    final response = await (_pending[key] ??= _load(request).whenComplete(() {
      _pending.remove(key);
    }));
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      contentLength: response.bodyBytes.length,
      request: request,
    );
  }

  Future<http.Response> _load(http.BaseRequest original) async {
    final generation = _generation;
    final storeGeneration = store.generation;
    final key = original.url.toString();
    CachedMapTile? cached;
    try {
      cached = await store.read(key);
    } catch (_) {
      /* Cache failures allow network retry. */
    }
    final now = clock().toUtc();
    if (cached != null && cached.expires.isAfter(now)) {
      return http.Response.bytes(cached.bytes, 200, headers: cached.headers);
    }
    final request = http.Request('GET', original.url);
    request.headers.addAll(original.headers);
    request.headers['User-Agent'] =
        'FamilyGuard/1.0 (+https://github.com/Taha-Saleem-43/Family-Guard)';
    if (cached != null) {
      final etag = cached.headers['etag'];
      final modified = cached.headers['last-modified'];
      if (etag != null) request.headers['If-None-Match'] = etag;
      if (modified != null) request.headers['If-Modified-Since'] = modified;
    }
    final result = await http.Response.fromStream(
      await network.send(request),
    ).timeout(const Duration(seconds: 20));
    final headers = {...?cached?.headers, ...result.headers};
    final bytes = result.statusCode == 304 && cached != null
        ? cached.bytes
        : result.bodyBytes;
    final status = result.statusCode == 304 && cached != null
        ? 200
        : result.statusCode;
    if (status == 200 &&
        _isPng(bytes) &&
        bytes.length <= 1024 * 1024 &&
        generation == _generation &&
        storeGeneration == store.generation &&
        !_closed) {
      final expires = expiry(headers, now);
      if (expires != null) {
        try {
          await store.write(key, CachedMapTile(bytes, headers, expires));
        } catch (_) {
          /* Storage may be full. */
        }
      } else {
        try {
          await store.remove(key);
        } catch (_) {
          /* Keep the network response usable if local storage is unavailable. */
        }
      }
    }
    return http.Response.bytes(bytes, status, headers: headers);
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71 &&
      bytes[4] == 13 &&
      bytes[5] == 10 &&
      bytes[6] == 26 &&
      bytes[7] == 10;

  static DateTime? expiry(Map<String, String> headers, DateTime now) {
    final control = headers['cache-control']?.toLowerCase() ?? '';
    final directives = control.split(',').map((value) => value.trim()).toSet();
    if (directives.contains('no-store')) return null;
    if (directives.contains('no-cache')) return now;
    var age = int.tryParse(headers['age'] ?? '') ?? 0;
    final date = headers['date'];
    if (date != null) {
      try {
        final apparentAge = now.difference(HttpDate.parse(date)).inSeconds;
        if (apparentAge > age) age = apparentAge;
      } catch (_) {
        /* A missing/invalid Date still uses the Age header. */
      }
    }
    if (age < 0) age = 0;
    final maxAge = RegExp(
      r'(?:^|,)\s*max-age\s*=\s*"?(\d+)',
    ).firstMatch(control);
    if (maxAge != null) {
      return now.add(Duration(seconds: int.parse(maxAge[1]!) - age));
    }
    final expires = headers['expires'];
    if (expires != null) {
      try {
        return HttpDate.parse(expires);
      } catch (_) {
        /* Use the policy fallback. */
      }
    }
    return now.add(const Duration(days: 7));
  }

  @override
  void close() {
    _closed = true;
    _generation++;
    network.close();
  }
}
