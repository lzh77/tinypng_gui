import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/compression_task.dart';
import '../services/queue_service.dart';
import '../services/queue_event.dart';
import 'history_notifier.dart';

/// 任务状态管理器
/// 使用 ChangeNotifier 管理压缩任务列表，并监听队列事件以同步任务状态
class TasksNotifier extends ChangeNotifier {
  final QueueService _queueService;
  HistoryNotifier? _historyNotifier;

  final List<CompressionTask> _tasks = [];
  StreamSubscription<QueueEvent>? _queueSubscription;

  TasksNotifier({
    required QueueService queueService,
    HistoryNotifier? historyNotifier,
  })  : _queueService = queueService,
        _historyNotifier = historyNotifier {
    // 订阅队列事件，自动同步任务状态
    _queueSubscription = _queueService.events.listen(_handleQueueEvent);
  }

  /// 注入历史记录 Notifier（Provider 树装配完成后调用）
  void bindHistoryNotifier(HistoryNotifier historyNotifier) {
    _historyNotifier = historyNotifier;
  }

  /// 所有任务列表（不可修改）
  List<CompressionTask> get tasks => List.unmodifiable(_tasks);

  /// 待处理任务数量
  int get pendingCount =>
      _tasks.where((t) => t.status == CompressionStatus.pending).length;

  /// 处理中任务数量
  int get processingCount =>
      _tasks.where((t) => t.status == CompressionStatus.processing).length;

  /// 已完成任务数量
  int get completedCount =>
      _tasks.where((t) => t.status == CompressionStatus.completed).length;

  /// 失败任务数量
  int get failedCount =>
      _tasks.where((t) => t.status == CompressionStatus.failed).length;

  /// 已取消任务数量
  int get cancelledCount =>
      _tasks.where((t) => t.status == CompressionStatus.cancelled).length;

  /// 任务总数
  int get totalCount => _tasks.length;

  /// 总原始文件大小（字节）
  int get totalOriginalSize =>
      _tasks.fold(0, (sum, task) => sum + task.originalSize);

  /// 总压缩后文件大小（字节）
  int get totalCompressedSize => _tasks
      .where((t) => t.compressedSize != null)
      .fold(0, (sum, task) => sum + (task.compressedSize ?? 0));

  /// 平均压缩比率（0.0 - 1.0）
  double get averageCompressionRatio {
    final completedTasks = _tasks
        .where((t) =>
            t.status == CompressionStatus.completed &&
            t.compressionRatio != null)
        .toList();

    if (completedTasks.isEmpty) return 0.0;

    final sum = completedTasks.fold(
        0.0, (sum, task) => sum + (task.compressionRatio ?? 0.0));
    return sum / completedTasks.length;
  }

  /// 总节省的空间（字节）
  int get totalBytesSaved => totalOriginalSize - totalCompressedSize;

  /// 添加单个任务
  /// [task] 要添加的压缩任务
  void addTask(CompressionTask task) {
    // 检查任务是否已存在
    if (_tasks.any((t) => t.id == task.id)) {
      return;
    }

    _tasks.add(task);
    notifyListeners();

    // 同时添加到队列服务
    _queueService.addTask(task);
  }

  /// 批量添加任务
  /// [tasks] 要添加的任务列表
  void addTasks(List<CompressionTask> tasks) {
    // 过滤掉已存在的任务
    final newTasks =
        tasks.where((task) => !_tasks.any((t) => t.id == task.id)).toList();

    if (newTasks.isEmpty) return;

    _tasks.addAll(newTasks);
    notifyListeners();

    // 同时添加到队列服务
    _queueService.addTasks(newTasks);
  }

  /// 更新任务状态
  /// [taskId] 任务ID
  /// [updatedTask] 更新后的任务对象
  void updateTask(String taskId, CompressionTask updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }

  /// 根据ID查找任务
  /// [taskId] 任务ID
  /// 返回找到的任务或null
  CompressionTask? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((t) => t.id == taskId);
    } catch (e) {
      return null;
    }
  }

  /// 移除单个任务
  /// [taskId] 要移除的任务ID
  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();

    // 同时从队列服务中移除
    _queueService.removeTask(taskId);
  }

  /// 清空所有任务
  void clearAll() {
    _tasks.clear();
    notifyListeners();

    // 同时清空队列
    _queueService.clear();
  }

  /// 清空所有失败的任务
  void clearFailed() {
    _tasks.removeWhere((t) => t.status == CompressionStatus.failed);
    notifyListeners();
  }

  /// 清空所有已完成的任务
  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == CompressionStatus.completed);
    notifyListeners();
  }

  /// 重试所有失败的任务
  void retryFailed() {
    final failedTasks = _tasks
        .where((t) => t.status == CompressionStatus.failed)
        .map((t) => CompressionTask(
              id: t.id,
              filePath: t.filePath,
              fileName: t.fileName,
              originalSize: t.originalSize,
              compressedSize: t.compressedSize,
              status: CompressionStatus.pending,
              errorMessage: null, // 显式清除错误消息
              compressionRatio: t.compressionRatio,
              createdAt: t.createdAt,
              completedAt: t.completedAt,
              baseDir: t.baseDir,
            ))
        .toList();

    // 更新任务状态
    for (var task in failedTasks) {
      updateTask(task.id, task);
    }

    // 重新添加到队列
    _queueService.addTasks(failedTasks);
  }

  /// 处理队列事件
  /// 当队列中任务状态发生变化时自动更新本地任务列表
  void _handleQueueEvent(QueueEvent event) {
    // 如果事件包含当前任务信息，更新任务状态
    if (event.currentTask != null) {
      final task = event.currentTask!;
      final index = _tasks.indexWhere((t) => t.id == task.id);

      if (index != -1) {
        _tasks[index] = task;
        notifyListeners();

        if (task.status == CompressionStatus.completed ||
            task.status == CompressionStatus.failed) {
          _historyNotifier?.onTaskFinished(task);
        }
      }
    }
  }

  @override
  void dispose() {
    // 取消队列事件订阅
    _queueSubscription?.cancel();
    super.dispose();
  }
}
