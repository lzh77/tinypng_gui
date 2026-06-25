import 'package:flutter/foundation.dart';

import '../data/models/compression_task.dart';
import '../data/models/history_record.dart';
import '../services/history_service.dart';

/// 历史记录状态管理器
class HistoryNotifier extends ChangeNotifier {
  final HistoryService _historyService;

  static const int _pageSize = 50;

  List<HistoryRecord> _records = [];
  HistoryStatistics? _statistics;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  HistoryNotifier({required HistoryService historyService})
      : _historyService = historyService;

  List<HistoryRecord> get records => List.unmodifiable(_records);

  HistoryStatistics? get statistics => _statistics;

  bool get isLoading => _isLoading;

  bool get hasMore => _hasMore;

  String? get error => _error;

  /// 初始化并加载首页数据
  Future<void> initialize() async {
    await _historyService.initialize();
    await refresh();
  }

  /// 刷新历史列表（从第一页重新加载）
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _records = await _historyService.getHistory(limit: _pageSize, offset: 0);
      _hasMore = _records.length >= _pageSize;
      _statistics = await _historyService.getGlobalStatistics();
      _error = null;
    } catch (e) {
      _error = '加载历史记录失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多（分页）
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final more = await _historyService.getHistory(
        limit: _pageSize,
        offset: _records.length,
      );
      _records = [..._records, ...more];
      _hasMore = more.length >= _pageSize;
      _error = null;
    } catch (e) {
      _error = '加载更多失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 压缩完成后追加一条记录（由 TasksNotifier 调用）
  Future<void> onTaskFinished(CompressionTask task) async {
    await _historyService.saveFromTask(task);

    if (_records.any((r) => r.id == task.id)) return;

    if (task.status == CompressionStatus.completed ||
        task.status == CompressionStatus.failed) {
      final record = HistoryRecord.fromTask(task);
      _records.insert(0, record);
      _statistics = await _historyService.getGlobalStatistics();
      notifyListeners();
    }
  }

  /// 删除单条记录
  Future<void> deleteRecord(String id) async {
    try {
      await _historyService.deleteRecord(id);
      _records.removeWhere((r) => r.id == id);
      _statistics = await _historyService.getGlobalStatistics();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = '删除记录失败: $e';
      notifyListeners();
    }
  }

  /// 清空全部历史
  Future<void> clearAll() async {
    try {
      await _historyService.clearAll();
      _records = [];
      _hasMore = false;
      _statistics = const HistoryStatistics(
        totalCount: 0,
        successCount: 0,
        failedCount: 0,
        totalOriginalSize: 0,
        totalCompressedSize: 0,
        totalBytesSaved: 0,
      );
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = '清空历史失败: $e';
      notifyListeners();
    }
  }
}
