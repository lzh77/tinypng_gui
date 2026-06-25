import 'package:flutter_test/flutter_test.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';

void main() {
  group('CompressionTask', () {
    final createdAt = DateTime(2026, 1, 1);

    test('copyWith 应保留未覆盖字段', () {
      final task = CompressionTask(
        id: 't1',
        filePath: '/a/b.png',
        fileName: 'b.png',
        originalSize: 100,
        status: CompressionStatus.pending,
        createdAt: createdAt,
      );

      final updated = task.copyWith(status: CompressionStatus.completed);

      expect(updated.id, 't1');
      expect(updated.status, CompressionStatus.completed);
      expect(updated.originalSize, 100);
    });

    test('toJson / fromJson 往返应保持一致', () {
      final task = CompressionTask(
        id: 't1',
        filePath: '/a/b.png',
        fileName: 'b.png',
        originalSize: 100,
        compressedSize: 40,
        status: CompressionStatus.completed,
        compressionRatio: 0.4,
        createdAt: createdAt,
        completedAt: DateTime(2026, 1, 2),
      );

      final restored = CompressionTask.fromJson(task.toJson());

      expect(restored.id, task.id);
      expect(restored.filePath, task.filePath);
      expect(restored.status, CompressionStatus.completed);
      expect(restored.compressedSize, 40);
    });
  });
}
