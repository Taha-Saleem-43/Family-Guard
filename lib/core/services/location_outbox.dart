import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// SQLite transactions coordinate foreground and headless isolates.
class LocationOutbox {
  LocationOutbox({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _path = databasePath;
  final DatabaseFactory _factory;
  final String? _path;
  Future<Database>? _opening;
  Future<Database> get database => _opening ??= _open();
  Future<Database> _open() async => _factory.openDatabase(
    _path ??
        path.join(
          await _factory.getDatabasesPath(),
          'family_guard_locations.db',
        ),
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE sharing (uid TEXT PRIMARY KEY, circle TEXT NOT NULL, started INTEGER NOT NULL, enabled INTEGER NOT NULL, sample TEXT)',
        );
        await db.execute(
          'CREATE TABLE fixes (id TEXT PRIMARY KEY, uid TEXT NOT NULL, circle TEXT NOT NULL, captured INTEGER NOT NULL, payload TEXT NOT NULL, lease TEXT, due INTEGER NOT NULL DEFAULT 0, attempts INTEGER NOT NULL DEFAULT 0)',
        );
        await db.execute(
          'CREATE INDEX fixes_queue ON fixes(uid, due, captured)',
        );
      },
    ),
  );
  Future<int> activate(String uid, String circle, int now) async {
    final db = await database;
    return db.transaction((tx) async {
      final rows = await tx.query(
        'sharing',
        where: 'uid = ?',
        whereArgs: [uid],
      );
      if (rows.isNotEmpty &&
          rows.first['enabled'] == 1 &&
          rows.first['circle'] == circle) {
        return rows.first['started'] as int;
      }
      await tx.delete('fixes', where: 'uid = ?', whereArgs: [uid]);
      await tx.insert('sharing', {
        'uid': uid,
        'circle': circle,
        'started': now,
        'enabled': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return now;
    });
  }

  Future<Map<String, Object?>?> context(String uid) async {
    final rows = await (await database).query(
      'sharing',
      where: 'uid = ? AND enabled = 1',
      whereArgs: [uid],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> enqueue(
    String uid,
    String circle,
    Map<String, Object> fix,
    int now, {
    bool recovery = false,
  }) async {
    return (await database).transaction((tx) async {
      final sharing = await tx.query(
        'sharing',
        where: 'uid = ? AND circle = ? AND enabled = 1',
        whereArgs: [uid, circle],
      );
      if (sharing.isEmpty ||
          (fix['capturedAt'] as int) < (sharing.first['started'] as int)) {
        return false;
      }
      await tx.delete(
        'fixes',
        where: 'captured < ?',
        whereArgs: [now - const Duration(days: 7).inMilliseconds],
      );
      final previousJson = sharing.first['sample'];
      if (previousJson is String && fix['latitude'] is num) {
        final previous = jsonDecode(previousJson) as Map;
        final elapsed =
            (fix['capturedAt'] as int) - (previous['capturedAt'] as int);
        if (elapsed <= 0 && !recovery) {
          return true;
        }
        final deltaLat =
            ((fix['latitude'] as num) - (previous['latitude'] as num)) *
            pi /
            180;
        final deltaLng =
            ((fix['longitude'] as num) - (previous['longitude'] as num)) *
            pi /
            180;
        final a =
            pow(sin(deltaLat / 2), 2) +
            cos((fix['latitude'] as num) * pi / 180) *
                cos((previous['latitude'] as num) * pi / 180) *
                pow(sin(deltaLng / 2), 2);
        final distance = 12742000 * asin(sqrt(a.clamp(0, 1)));
        final instant =
            fix['movementActivity'] != previous['movementActivity'] ||
            fix['isCharging'] != previous['isCharging'] ||
            ((fix['batteryLevel'] as num) - (previous['batteryLevel'] as num))
                    .abs() >=
                5 ||
            ((fix['batteryLevel'] as num) <= 20 &&
                (previous['batteryLevel'] as num) > 20);
        if (elapsed > 0 &&
            !instant &&
            elapsed < 180000 &&
            !(elapsed >= 45000 && distance >= 50)) {
          return true;
        }
      }
      await tx.insert('fixes', {
        'id': fix['id'],
        'uid': uid,
        'circle': circle,
        'captured': fix['capturedAt'],
        'payload': jsonEncode(fix),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (previousJson is! String ||
          (fix['capturedAt'] as int) >
              (jsonDecode(previousJson)['capturedAt'] as int)) {
        await tx.update(
          'sharing',
          {'sample': jsonEncode(fix)},
          where: 'uid = ?',
          whereArgs: [uid],
        );
      }
      // Bound disk use even during extended outages.
      await tx.rawDelete(
        'DELETE FROM fixes WHERE uid = ? AND id NOT IN (SELECT id FROM fixes WHERE uid = ? ORDER BY captured DESC, id DESC LIMIT 5000)',
        [uid, uid],
      );
      return true;
    });
  }

  Future<LocationLease?> claim(String uid, int now) async {
    return (await database).transaction((tx) async {
      final sharing = await tx.query(
        'sharing',
        where: 'uid = ? AND enabled = 1',
        whereArgs: [uid],
      );
      if (sharing.isEmpty) return null;
      await tx.delete(
        'fixes',
        where: 'uid = ? AND captured < ?',
        whereArgs: [uid, now - const Duration(days: 7).inMilliseconds],
      );
      final circle = sharing.first['circle'] as String;
      final busy = await tx.query(
        'fixes',
        columns: ['id'],
        where: 'uid = ? AND lease IS NOT NULL AND due > ?',
        whereArgs: [uid, now],
        limit: 1,
      );
      if (busy.isNotEmpty) return null;
      final rows = await tx.query(
        'fixes',
        where: 'uid = ? AND circle = ? AND due <= ?',
        whereArgs: [uid, circle, now],
        orderBy: 'captured ASC, id ASC',
        limit: 50,
      );
      if (rows.isEmpty) return null;
      final token = List.generate(
        32,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      for (final row in rows) {
        await tx.update(
          'fixes',
          {'lease': token, 'due': now + 120000},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      return LocationLease(
        uid,
        circle,
        token,
        rows
            .map(
              (row) => Map<String, Object>.from(
                jsonDecode(row['payload'] as String) as Map,
              ),
            )
            .toList(),
      );
    });
  }

  Future<void> acknowledge(LocationLease lease, List<String> ids) async {
    await (await database).transaction((tx) async {
      for (final id in ids) {
        await tx.delete(
          'fixes',
          where: 'uid = ? AND lease = ? AND id = ?',
          whereArgs: [lease.uid, lease.token, id],
        );
      }
    });
  }

  Future<void> retry(LocationLease lease, int now) async {
    await (await database).transaction((tx) async {
      final rows = await tx.query(
        'fixes',
        where: 'uid = ? AND lease = ?',
        whereArgs: [lease.uid, lease.token],
      );
      for (final row in rows) {
        final attempts = (row['attempts'] as int) + 1;
        final delay = min(900000, 15000 * (1 << min(attempts - 1, 6)));
        await tx.update(
          'fixes',
          {'lease': null, 'due': now + delay, 'attempts': attempts},
          where: 'id = ? AND lease = ?',
          whereArgs: [row['id'], lease.token],
        );
      }
    });
  }

  Future<void> deactivate(String uid) async {
    await (await database).transaction((tx) async {
      await tx.delete('sharing', where: 'uid = ?', whereArgs: [uid]);
      await tx.delete('fixes', where: 'uid = ?', whereArgs: [uid]);
    });
  }

  Future<void> close() async {
    await (await database).close();
    _opening = null;
  }
}

class LocationLease {
  const LocationLease(this.uid, this.circle, this.token, this.fixes);
  final String uid;
  final String circle;
  final String token;
  final List<Map<String, Object>> fixes;
}
