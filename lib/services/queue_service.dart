import 'dart:async';
import 'package:pool/pool.dart';
import '../data/models/compression_task.dart';
import 'compression_service.dart';
import 'queue_event.dart';
import 'logger_service.dart';

/// 任务队列服务
/// 负责管理待压缩任务的调度、并发控制和状态通知
class QueueService {
  final CompressionService _compressionService;

  final List<CompressionTask> _queue = [];
  final Set<String> _processingIds = {};

  final StreamController<QueueEvent> _eventController =
      StreamController<QueueEvent>.broadcast();

  Pool? _pool;
  int _concurrentLimit = 3;
  int _completedCount = 0;
  bool _isPaused = false;
  bool _isStopping = false;
  bool _isRunning = false; // 新增：明确标识 Pool 是否已启动

  QueueService({
    required CompressionService compressionService,
  }) : _compressionService = compressionService;

  /// 暴露队列事件流
  Stream<QueueEvent> get events => _eventController.stream;

  /// 队列中待处理的任务数量
  int get pendingCount => _queue.length;

  /// 正在处理的任务数量
  int get activeCount => _processingIds.length;

  /// 当前队列状态
  QueueStatus get status {
    if (_isStopping) return QueueStatus.stopping;
    if (_isPaused) return QueueStatus.paused;
    if (_isRunning && (_processingIds.isNotEmpty || _queue.isNotEmpty)) {
      return QueueStatus.running;
    }
    return QueueStatus.idle;
  }

  /// 设置并发限制
  set concurrentLimit(int limit) {
    if (limit <= 0) return;
    _concurrentLimit = limit;
    // 如果正在运行，Pool 不支持动态调整，但新任务会遵循新限制
    // 实际上通常建议在启动前设置
  }

  /// 添加单个任务到队列
  void addTask(CompressionTask task) {
    if (_queue.any((t) => t.id == task.id) ||
        _processingIds.contains(task.id)) {
      return;
    }
    _queue.add(task);
    _notifyListeners();
  }

  /// 批量添加任务到队列
  void addTasks(List<CompressionTask> tasks) {
    for (var task in tasks) {
      addTask(task);
    }
  }

  /// 开始处理队列
  void start() {
    if (_isRunning || _isStopping) return; // 使用 _isRunning 判断

    _isPaused = false;
    _isStopping = false;
    _isRunning = true; // 标记为运行中
    _pool = Pool(_concurrentLimit);

    LoggerService.i('队列启动，并发限制: $_concurrentLimit');
    _notifyListeners(); // 启动时通知
    _processQueue();
  }

  /// 暂停处理新任务（已开始的任务会继续完成）
  void pause() {
    _isPaused = true;
    _notifyListeners();
    LoggerService.i('队列已暂停');
  }

  /// 恢复处理
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    LoggerService.i('队列恢复');
    _notifyListeners(); // 恢复时通知
    _processQueue();
  }

  /// 取消/停止队列（已开始的任务会标记为完成或失败）
  Future<void> stop() async {
    _isStopping = true;
    _notifyListeners();

    _queue.clear();
    // 等待现有任务完成
    if (_pool != null) {
      await _pool!.close();
      _pool = null;
    }

    _isStopping = false;
    _isPaused = false;
    _isRunning = false; // 重置运行标志
    _processingIds.clear();
    _notifyListeners();
    LoggerService.i('队列已停止并清空');
  }

  /// 内部循环处理队列
  void _processQueue() async {
    if (_pool == null || _isPaused || _isStopping) {
      return;
    }

    // 只有当当前处理中的任务数小于并发限制时，才从队列中取出新任务
    while (_processingIds.length < _concurrentLimit &&
        _queue.isNotEmpty &&
        !_isPaused &&
        !_isStopping) {
      final task = _queue.removeAt(0);
      _processingIds.add(task.id);
      _notifyListeners();

      unawaited(_pool!.withResource(() async {
        try {
          final updatedTask = await _compressionService.compressTask(
              task.copyWith(status: CompressionStatus.processing));

          _completedCount++;
          // 在 notifyListeners 之前更新任务完成状态（如果需要上层感知，这里通常是通过 currentTask 传回）
          _notifyListeners(currentTask: updatedTask);
        } catch (e) {
          _notifyListeners();
        } finally {
          _processingIds.remove(task.id);
          _notifyListeners();

          // 任务完成后，或者出错了，尝试处理队列中的下一个任务
          if (!_isPaused && !_isStopping) {
            _processQueue();
          }
        }
      }));
    }

    // 状态更新通知
    _notifyListeners();
  }

  /// 移除特定任务
  void removeTask(String taskId) {
    _queue.removeWhere((t) => t.id == taskId);
    _notifyListeners();
  }

  /// 清空等待队列
  void clear() {
    _queue.clear();
    _notifyListeners();
  }

  void _notifyListeners({CompressionTask? currentTask}) {
    if (_eventController.isClosed) return;

    _eventController.add(QueueEvent(
      status: status,
      currentTask: currentTask,
      completedCount: _completedCount,
      totalCount: _queue.length + _processingIds.length + _completedCount,
    ));
  }

  void dispose() {
    _pool?.close();
    _eventController.close();
  }
}
