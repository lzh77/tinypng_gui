import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinypng_gui/data/datasources/local/history_database.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/data/models/history_record.dart';
import 'package:tinypng_gui/services/history_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  late HistoryDatabase database;
  late HistoryService service;

  HistoryRecord makeRecord({
    required String id,
    required DateTime timestamp,
    CompressionStatus status = CompressionStatus.completed,
    int originalSize = 1000,
    int? compressedSize = 400,
  }) {
    return HistoryRecord(
      id: id,
      fileName: '$id.png',
      filePath: 'C:\\images\\$id.png',
      originalSize: originalSize,
      compressedSize: compressedSize,
      status: status,
      timestamp: timestamp,
    );
  }

  CompressionTask makeTask({
    required String id,
    required CompressionStatus status,
    int originalSize = 1000,
    int? compressedSize,
    String? errorMessage,
  }) {
    return CompressionTask(
      id: id,
      filePath: r'C:\images\photo.png',
      fileName: 'photo.png',
      originalSize: originalSize,
      compressedSize: compressedSize,
      status: status,
      errorMessage: errorMessage,
      createdAt: DateTime(2026, 6, 1, 10, 0),
      completedAt: DateTime(2026, 6, 1, 10, 5),
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = HistoryDatabase(
      databaseFileName: 'history_service_test_${const Uuid().v4()}.db',
    );
    service = HistoryService(database: database);
    await service.initialize();
  });

  tearDown(() async {
    await database.close();
  });

  group('HistoryService', () {
    test('saveFromTask 应持久化已完成或失败任务', () async {
      await service.saveFromTask(
        makeTask(id: 'done', status: CompressionStatus.completed, compressedSize: 300),
      );
      await service.saveFromTask(
        makeTask(
          id: 'fail',
          status: CompressionStatus.failed,
          errorMessage: '网络错误',
        ),
      );

      expect(await service.getTotalCount(), 2);
    });

    test('saveFromTask 应忽略 pending / processing / cancelled 状态', () async {
      await service.saveFromTask(
        makeTask(id: 'p', status: CompressionStatus.pending),
      );
      await service.saveFromTask(
        makeTask(id: 'pr', status: CompressionStatus.processing),
      );
      await service.saveFromTask(
        makeTask(id: 'c', status: CompressionStatus.cancelled),
      );

      expect(await service.getTotalCount(), 0);
    });

    test('computeStatistics 应汇总成功与失败记录', () {
      final records = [
        makeRecord(
          id: 'ok1',
          timestamp: DateTime(2026, 6, 1),
          originalSize: 1000,
          compressedSize: 400,
        ),
        makeRecord(
          id: 'ok2',
          timestamp: DateTime(2026, 6, 2),
          originalSize: 2000,
          compressedSize: 1000,
        ),
        makeRecord(
          id: 'bad',
          timestamp: DateTime(2026, 6, 3),
          status: CompressionStatus.failed,
        ),
      ];

      final stats = service.computeStatistics(records);

      expect(stats.totalCount, 3);
      expect(stats.successCount, 2);
      expect(stats.failedCount, 1);
      expect(stats.totalOriginalSize, 3000);
      expect(stats.totalCompressedSize, 1400);
      expect(stats.totalBytesSaved, 1600);
      expect(stats.averageSavingsRatio, closeTo(1600 / 3000, 0.001));
    });

    test('computeStatistics 无成功记录时 averageSavingsRatio 为 0', () {
      final stats = service.computeStatistics([
        makeRecord(
          id: 'bad',
          timestamp: DateTime(2026, 6, 1),
          status: CompressionStatus.failed,
        ),
      ]);

      expect(stats.averageSavingsRatio, 0);
    });

    test('getGlobalStatistics 应基于数据库全量统计', () async {
      await database.addRecord(
        makeRecord(
          id: 'ok',
          timestamp: DateTime(2026, 6, 1),
          originalSize: 1000,
          compressedSize: 500,
        ),
      );
      await database.addRecord(
        makeRecord(
          id: 'bad',
          timestamp: DateTime(2026, 6, 2),
          status: CompressionStatus.failed,
        ),
      );

      final stats = await service.getGlobalStatistics();

      expect(stats.totalCount, 2);
      expect(stats.successCount, 1);
      expect(stats.failedCount, 1);
      expect(stats.totalBytesSaved, 500);
    });

    test('deleteRecord 与 clearAll 应委托数据库', () async {
      await database.addRecord(
        makeRecord(id: 'a', timestamp: DateTime(2026, 6, 1)),
      );
      await database.addRecord(
        makeRecord(id: 'b', timestamp: DateTime(2026, 6, 2)),
      );

      await service.deleteRecord('a');
      expect(await service.getTotalCount(), 1);

      await service.clearAll();
      expect(await service.getTotalCount(), 0);
    });
  });
}
