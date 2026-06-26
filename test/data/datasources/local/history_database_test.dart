import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinypng_gui/data/datasources/local/history_database.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/data/models/history_record.dart';
import 'package:uuid/uuid.dart';

void main() {
  late HistoryDatabase database;

  HistoryRecord makeRecord({
    required String id,
    required DateTime timestamp,
    CompressionStatus status = CompressionStatus.completed,
    int originalSize = 1000,
    int? compressedSize = 400,
    String? errorMessage,
  }) {
    return HistoryRecord(
      id: id,
      fileName: '$id.png',
      filePath: 'C:\\images\\$id.png',
      originalSize: originalSize,
      compressedSize: compressedSize,
      status: status,
      errorMessage: errorMessage,
      timestamp: timestamp,
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    database = HistoryDatabase(
      databaseFileName: 'history_test_${const Uuid().v4()}.db',
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('HistoryDatabase', () {
    test('init 应创建表并支持写入与读取', () async {
      await database.init();

      final record = makeRecord(
        id: 'r1',
        timestamp: DateTime(2026, 6, 1, 12, 0),
      );
      await database.addRecord(record);

      final history = await database.getHistory();
      expect(history, hasLength(1));
      expect(history.first, equals(record));
    });

    test('getHistory 应按时间倒序并支持分页', () async {
      await database.init();

      await database.addRecord(
        makeRecord(id: 'old', timestamp: DateTime(2026, 6, 1, 10, 0)),
      );
      await database.addRecord(
        makeRecord(id: 'mid', timestamp: DateTime(2026, 6, 1, 11, 0)),
      );
      await database.addRecord(
        makeRecord(id: 'new', timestamp: DateTime(2026, 6, 1, 12, 0)),
      );

      final page1 = await database.getHistory(limit: 2, offset: 0);
      final page2 = await database.getHistory(limit: 2, offset: 2);

      expect(page1.map((r) => r.id).toList(), ['new', 'mid']);
      expect(page2.map((r) => r.id).toList(), ['old']);
    });

    test('getCount 应返回记录总数', () async {
      await database.init();

      expect(await database.getCount(), 0);

      await database.addRecord(
        makeRecord(id: 'a', timestamp: DateTime(2026, 6, 1)),
      );
      await database.addRecord(
        makeRecord(id: 'b', timestamp: DateTime(2026, 6, 2)),
      );

      expect(await database.getCount(), 2);
    });

    test('addRecord 相同 id 应替换已有记录', () async {
      await database.init();

      await database.addRecord(
        makeRecord(
          id: 'same',
          timestamp: DateTime(2026, 6, 1),
          originalSize: 1000,
        ),
      );
      await database.addRecord(
        makeRecord(
          id: 'same',
          timestamp: DateTime(2026, 6, 2),
          originalSize: 2000,
        ),
      );

      expect(await database.getCount(), 1);
      final history = await database.getHistory();
      expect(history.single.originalSize, 2000);
    });

    test('deleteRecord 应删除指定记录', () async {
      await database.init();

      await database.addRecord(
        makeRecord(id: 'keep', timestamp: DateTime(2026, 6, 1)),
      );
      await database.addRecord(
        makeRecord(id: 'remove', timestamp: DateTime(2026, 6, 2)),
      );

      await database.deleteRecord('remove');

      expect(await database.getCount(), 1);
      final history = await database.getHistory();
      expect(history.single.id, 'keep');
    });

    test('clearAll 应清空全部记录', () async {
      await database.init();

      await database.addRecord(
        makeRecord(id: 'a', timestamp: DateTime(2026, 6, 1)),
      );
      await database.addRecord(
        makeRecord(id: 'b', timestamp: DateTime(2026, 6, 2)),
      );

      await database.clearAll();

      expect(await database.getCount(), 0);
      expect(await database.getHistory(), isEmpty);
    });

    test('超过 1000 条时应自动删除最旧记录', () async {
      await database.init();

      final base = DateTime(2026, 1, 1);
      for (var i = 0; i < 1001; i++) {
        await database.addRecord(
          makeRecord(
            id: 'id-$i',
            timestamp: base.add(Duration(seconds: i)),
          ),
        );
      }

      expect(await database.getCount(), 1000);

      final newest = await database.getHistory(limit: 1);
      expect(newest.single.id, 'id-1000');

      final all = await database.getHistory(limit: 1000);
      expect(all.any((r) => r.id == 'id-0'), isFalse);
    });

    test('未显式 init 时 CRUD 应自动初始化', () async {
      await database.addRecord(
        makeRecord(id: 'lazy', timestamp: DateTime(2026, 6, 1)),
      );

      expect(await database.getCount(), 1);
    });
  });
}
