import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class PendingOperation {
  const PendingOperation({
    required this.id,
    required this.method,
    required this.path,
    required this.body,
    required this.attempts,
  });
  final String id;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final int attempts;
}

class OfflineStore {
  OfflineStore._();
  static final shared = OfflineStore._();
  Database? _db;

  Future<Database> get database async => _db ??= await openDatabase(
    p.join(await getDatabasesPath(), 'family_os.db'),
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE response_cache(cache_key TEXT PRIMARY KEY,payload TEXT NOT NULL,updated_at INTEGER NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE pending_operations(id TEXT PRIMARY KEY,method TEXT NOT NULL,path TEXT NOT NULL,body TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,created_at INTEGER NOT NULL,last_error TEXT)',
      );
    },
  );

  Future<void> cache(String key, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('response_cache', {
      'cache_key': key,
      'payload': jsonEncode(payload),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> cached(String key) async {
    final rows = await (await database).query(
      'response_cache',
      where: 'cache_key=?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<String> enqueue(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final id = const Uuid().v4();
    await (await database).insert('pending_operations', {
      'id': id,
      'method': method,
      'path': path,
      'body': jsonEncode(body),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<List<PendingOperation>> pending() async {
    final rows = await (await database).query(
      'pending_operations',
      orderBy: 'created_at',
      limit: 100,
    );
    return rows
        .map(
          (r) => PendingOperation(
            id: r['id'] as String,
            method: r['method'] as String,
            path: r['path'] as String,
            body: jsonDecode(r['body'] as String) as Map<String, dynamic>,
            attempts: r['attempts'] as int,
          ),
        )
        .toList();
  }

  Future<void> remove(String id) async => (await database).delete(
    'pending_operations',
    where: 'id=?',
    whereArgs: [id],
  );
  Future<void> failed(
    String id,
    String message,
  ) async => (await database).rawUpdate(
    'UPDATE pending_operations SET attempts=attempts+1,last_error=? WHERE id=?',
    [message, id],
  );
  Future<int> count() async =>
      Sqflite.firstIntValue(
        await (await database).rawQuery(
          'SELECT COUNT(*) FROM pending_operations',
        ),
      ) ??
      0;
  Future<void> clearSensitiveData() async {
    final db = await database;
    await db.delete('response_cache');
    await db.delete('pending_operations');
  }
}
