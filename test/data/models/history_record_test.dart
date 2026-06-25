import 'package:flutter_test/flutter_test.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/data/models/history_record.dart';

void main() {
  group('HistoryRecord', () {
    final completedTask = CompressionTask(
      id: 'task-1',
      filePath: r'C:\images\photo.png',
      fileName: 'photo.png',
      originalSize: 1000,
      compressedSize: 400,
      status: CompressionStatus.completed,
      compressionRatio: 0.4,
      createdAt: DateTime(2026, 6, 1, 10, 0),
      completedAt: DateTime(2026, 6, 1, 10, 5),
    );

    test('fromTask 应正确映射压缩任务字段', () {
      final record = HistoryRecord.fromTask(completedTask);

      expect(record.id, 'task-1');
      expect(record.fileName, 'photo.png');
      expect(record.filePath, r'C:\images\photo.png');
      expect(record.originalSize, 1000);
      expect(record.compressedSize, 400);
      expect(record.status, CompressionStatus.completed);
      expect(record.timestamp, completedTask.completedAt);
    });

    test('savingsRatio 应计算节省比例', () {
      final record = HistoryRecord.fromTask(completedTask);
      expect(record.savingsRatio, closeTo(0.6, 0.001));
    });

    test('toMap / fromMap 应可往返序列化', () {
      final record = HistoryRecord.fromTask(completedTask);
      final restored = HistoryRecord.fromMap(record.toMap());

      expect(restored, equals(record));
    });

    test('失败任务应保留 errorMessage', () {
      final failedTask = CompressionTask(
        id: 'task-2',
        filePath: r'C:\images\bad.png',
        fileName: 'bad.png',
        originalSize: 1000,
        status: CompressionStatus.failed,
        errorMessage: '配额已用完',
        createdAt: DateTime(2026, 6, 1, 10, 0),
      );
      final record = HistoryRecord.fromTask(failedTask);

      expect(record.status, CompressionStatus.failed);
      expect(record.errorMessage, '配额已用完');
      expect(record.savingsRatio, isNull);
    });
  });
}
