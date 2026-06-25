import '../data/models/compression_task.dart';
import '../data/models/history_record.dart';
import '../data/datasources/local/history_database.dart';
import 'logger_service.dart';

/// 历史记录汇总统计
class HistoryStatistics {
  final int totalCount;
  final int successCount;
  final int failedCount;
  final int totalOriginalSize;
  final int totalCompressedSize;
  final int totalBytesSaved;

  const HistoryStatistics({
    required this.totalCount,
    required this.successCount,
    required this.failedCount,
    required this.totalOriginalSize,
    required this.totalCompressedSize,
    required this.totalBytesSaved,
  });

  /// 平均压缩节省比例（0.0–1.0），无成功记录时为 0
  double get averageSavingsRatio {
    if (successCount == 0 || totalOriginalSize <= 0) return 0;
    return totalBytesSaved / totalOriginalSize;
  }
}

/// 压缩历史记录服务
class HistoryService {
  final HistoryDatabase _database;

  HistoryService({required HistoryDatabase database})
      : _database = database;

  Future<void> initialize() => _database.init();

  /// 将已完成的压缩任务写入历史
  Future<void> saveFromTask(CompressionTask task) async {
    if (task.status != CompressionStatus.completed &&
        task.status != CompressionStatus.failed) {
      return;
    }

    try {
      await _database.addRecord(HistoryRecord.fromTask(task));
      LoggerService.d('历史记录已保存: ${task.fileName}');
    } catch (e, stackTrace) {
      LoggerService.e('保存历史记录失败: ${task.fileName}', e, stackTrace);
    }
  }

  Future<List<HistoryRecord>> getHistory({
    int limit = 100,
    int offset = 0,
  }) {
    return _database.getHistory(limit: limit, offset: offset);
  }

  Future<int> getTotalCount() => _database.getCount();

  Future<void> deleteRecord(String id) => _database.deleteRecord(id);

  Future<void> clearAll() => _database.clearAll();

  /// 基于当前已加载记录计算汇总（UI 层分页时使用）
  HistoryStatistics computeStatistics(List<HistoryRecord> records) {
    final successRecords = records
        .where((r) => r.status == CompressionStatus.completed)
        .toList();

    final totalOriginal = successRecords.fold<int>(
      0,
      (sum, r) => sum + r.originalSize,
    );
    final totalCompressed = successRecords.fold<int>(
      0,
      (sum, r) => sum + (r.compressedSize ?? 0),
    );

    return HistoryStatistics(
      totalCount: records.length,
      successCount: successRecords.length,
      failedCount: records
          .where((r) => r.status == CompressionStatus.failed)
          .length,
      totalOriginalSize: totalOriginal,
      totalCompressedSize: totalCompressed,
      totalBytesSaved: totalOriginal - totalCompressed,
    );
  }

  /// 从数据库全量计算汇总统计
  Future<HistoryStatistics> getGlobalStatistics() async {
    final all = await _database.getHistory(limit: 10000);
    final stats = computeStatistics(all);
    return HistoryStatistics(
      totalCount: await _database.getCount(),
      successCount: stats.successCount,
      failedCount: stats.failedCount,
      totalOriginalSize: stats.totalOriginalSize,
      totalCompressedSize: stats.totalCompressedSize,
      totalBytesSaved: stats.totalBytesSaved,
    );
  }
}
