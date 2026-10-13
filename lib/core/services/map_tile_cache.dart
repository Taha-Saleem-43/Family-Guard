import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class CachedMapTile {
  final Uint8List bytes;
  final Map<String, String> headers;
  final DateTime expires;
  const CachedMapTile(this.bytes, this.headers, this.expires);
}

abstract interface class MapTileStore {
  int get generation;
  Future<CachedMapTile?> read(String url);
  Future<void> write(String url, CachedMapTile tile);
  Future<void> remove(String url);
  Future<void> clear();
}

/// Public basemap images only: never stores family markers, routes or names.
/// URL hashes avoid writing readable viewport coordinates to the database.
class MapTileCache implements MapTileStore {
  static final shared = MapTileCache();
  final DatabaseFactory? factory;
  final String? databasePath;
  final int maxBytes;
  Future<Database>? _database;
  int _generation = 0;
  @override
  int get generation => _generation;

  MapTileCache({
    this.factory,
    this.databasePath,
    this.maxBytes = 128 * 1024 * 1024,
  });

  String _key(String url) => sha256.convert(utf8.encode(url)).toString();
  Future<Database> _open() =>
      _database ??= _create().catchError((Object error, StackTrace stack) {
        _database = null;
        Error.throwWithStackTrace(error, stack);
      });
  Future<Database> _create() async {
    final target =
        databasePath ??
        path.join(await getDatabasesPath(), 'public_map_tiles.db');
    return (factory ?? databaseFactory).openDatabase(
      target,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA secure_delete = ON');
        },
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE tiles (key TEXT PRIMARY KEY, bytes BLOB NOT NULL, headers TEXT NOT NULL, expires INTEGER NOT NULL, stored INTEGER NOT NULL, size INTEGER NOT NULL)',
          );
        },
      ),
    );
  }

  @override
  Future<CachedMapTile?> read(String url) async {
    final db = await _open();
    final rows = await db.query(
      'tiles',
      where: 'key = ?',
      whereArgs: [_key(url)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    try {
      return CachedMapTile(
        row['bytes'] as Uint8List,
        Map<String, String>.from(jsonDecode(row['headers'] as String) as Map),
        DateTime.fromMillisecondsSinceEpoch(row['expires'] as int, isUtc: true),
      );
    } catch (_) {
      await db.delete('tiles', where: 'key = ?', whereArgs: [_key(url)]);
      return null;
    }
  }

  @override
  Future<void> write(String url, CachedMapTile tile) async {
    final generation = _generation;
    final db = await _open();
    await db.transaction((txn) async {
      if (generation != _generation || tile.bytes.length > maxBytes) return;
      await txn.insert('tiles', {
        'key': _key(url),
        'bytes': tile.bytes,
        'headers': jsonEncode(tile.headers),
        'expires': tile.expires.millisecondsSinceEpoch,
        'stored': DateTime.now().millisecondsSinceEpoch,
        'size': tile.bytes.length,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      var size =
          (await txn.rawQuery(
                'SELECT COALESCE(SUM(size), 0) AS total FROM tiles',
              )).single['total']
              as int;
      if (size <= maxBytes) return;
      final oldest = await txn.query(
        'tiles',
        columns: ['key', 'size'],
        orderBy: 'stored ASC, key ASC',
      );
      for (final row in oldest) {
        if (size <= maxBytes) break;
        await txn.delete('tiles', where: 'key = ?', whereArgs: [row['key']]);
        size -= row['size'] as int;
      }
    });
  }

  @override
  Future<void> remove(String url) async {
    final db = await _open();
    await db.delete('tiles', where: 'key = ?', whereArgs: [_key(url)]);
  }

  @override
  Future<void> clear() async {
    _generation++;
    final db = await _open();
    await db.delete('tiles');
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) await (await db).close();
  }
}
