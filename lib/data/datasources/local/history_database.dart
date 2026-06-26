import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/history_record.dart';

/// 压缩历史 SQLite 数据源（Windows 使用 sqflite_common_ffi）
class HistoryDatabase {
  static const String _tableName = 'compression_history';
  static const String defaultDatabaseFileName = 'tinypng_history.db';
  static const int _defaultMaxRecords = 1000;

  final String _databaseFileName;
  Database? _db;

  HistoryDatabase({String databaseFileName = defaultDatabaseFileName})
      : _databaseFileName = databaseFileName;

  /// 初始化数据库连接并创建表
  Future<void> init() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseFileName);

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_tableName('
          'id TEXT PRIMARY KEY, '
          'fileName TEXT NOT NULL, '
          'filePath TEXT NOT NULL, '
          'originalSize INTEGER NOT NULL, '
          'compressedSize INTEGER, '
          'status TEXT NOT NULL, '
          'errorMessage TEXT, '
          'timestamp INTEGER NOT NULL)',
        );
        await db.execute(
          'CREATE INDEX idx_history_timestamp ON $_tableName(timestamp DESC)',
        );
      },
    );
  }

  Future<void> addRecord(HistoryRecord record) async {
    await _ensureOpen();
    await _db!.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _trimToMax(_defaultMaxRecords);
  }

  Future<List<HistoryRecord>> getHistory({
    int limit = 100,
    int offset = 0,
  }) async {
    await _ensureOpen();
    final maps = await _db!.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map(HistoryRecord.fromMap).toList();
  }

  Future<int> getCount() async {
    await _ensureOpen();
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_tableName',
    );
    final value = result.first['cnt'];
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<void> deleteRecord(String id) async {
    await _ensureOpen();
    await _db!.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    await _ensureOpen();
    await _db!.delete(_tableName);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _ensureOpen() async {
    if (_db == null) {
      await init();
    }
  }

  /// 保留最近 [maxRecords] 条，删除更早的记录
  Future<void> _trimToMax(int maxRecords) async {
    final count = await getCount();
    if (count <= maxRecords) return;

    final excess = count - maxRecords;
    await _db!.rawDelete(
      'DELETE FROM $_tableName WHERE id IN ('
      'SELECT id FROM $_tableName ORDER BY timestamp ASC LIMIT ?'
      ')',
      [excess],
    );
  }
}
