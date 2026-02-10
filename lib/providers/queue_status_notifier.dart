import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/compression_task.dart';
import '../services/queue_service.dart';
import '../services/queue_event.dart';

/// 队列状态管理器
/// 使用 ChangeNotifier 管理队列的整体状态，并监听队列事件以同步状态变化
class QueueStatusNotifier extends ChangeNotifier {
  final QueueService _queueService;

  QueueStatus _status = QueueStatus.idle;
  CompressionTask? _currentTask;
  int _completedCount = 0;
  int _totalCount = 0;
  String? _message;
  StreamSubscription<QueueEvent>? _queueSubscription;

  QueueStatusNotifier({required QueueService queueService})
      : _queueService = queueService {
    // 订阅队列事件，自动同步队列状态
    _queueSubscription = _queueService.events.listen(_handleQueueEvent);
  }

  /// 当前队列状态
  QueueStatus get status => _status;

  /// 当前正在处理的任务
  CompressionTask? get currentTask => _currentTask;

  /// 已完成任务数量
  int get completedCount => _completedCount;

  /// 总任务数量
  int get totalCount => _totalCount;

  /// 待处理任务数量
  int get pendingCount => _queueService.pendingCount;

  /// 正在处理的任务数量
  int get activeCount => _queueService.activeCount;

  /// 状态消息
  String? get message => _message;

  /// 当前进度（0.0 - 1.0）
  double get progress {
    if (_totalCount == 0) return 0.0;
    return _completedCount / _totalCount;
  }

  /// 进度百分比（0 - 100）
  int get progressPercentage => (progress * 100).round();

  /// 是否正在运行
  bool get isRunning => _status == QueueStatus.running;

  /// 是否已暂停
  bool get isPaused => _status == QueueStatus.paused;

  /// 是否空闲
  bool get isIdle => _status == QueueStatus.idle;

  /// 是否正在停止
  bool get isStopping => _status == QueueStatus.stopping;

  /// 是否可以开始（空闲状态且有待处理任务）
  bool get canStart => isIdle && pendingCount > 0;

  /// 是否可以暂停（正在运行）
  bool get canPause => isRunning;

  /// 是否可以恢复（已暂停）
  bool get canResume => isPaused;

  /// 是否可以停止（正在运行或已暂停）
  bool get canStop => isRunning || isPaused;

  /// 开始处理队列
  void start() {
    if (!canStart) return;
    _queueService.start();
  }

  /// 暂停处理队列
  void pause() {
    if (!canPause) return;
    _queueService.pause();
  }

  /// 恢复处理队列
  void resume() {
    if (!canResume) return;
    _queueService.resume();
  }

  /// 停止处理队列
  Future<void> stop() async {
    if (!canStop) return;
    await _queueService.stop();
  }

  /// 重置状态（清空所有统计信息）
  void reset() {
    _status = QueueStatus.idle;
    _currentTask = null;
    _completedCount = 0;
    _totalCount = 0;
    _message = null;
    notifyListeners();
  }

  /// 处理队列事件
  /// 当队列状态发生变化时自动更新本地状态
  void _handleQueueEvent(QueueEvent event) {
    _status = event.status;
    _currentTask = event.currentTask;
    _completedCount = event.completedCount;
    _totalCount = event.totalCount;
    _message = event.message;

    notifyListeners();
  }

  /// 获取状态描述文本
  String getStatusText() {
    switch (_status) {
      case QueueStatus.idle:
        return '空闲';
      case QueueStatus.running:
        if (_currentTask != null) {
          return '正在处理: ${_currentTask!.fileName}';
        }
        return '运行中';
      case QueueStatus.paused:
        return '已暂停';
      case QueueStatus.stopping:
        return '正在停止...';
    }
  }

  /// 获取详细进度文本
  String getProgressText() {
    if (_totalCount == 0) {
      return '没有任务';
    }
    return '$_completedCount / $_totalCount (${progressPercentage}%)';
  }

  @override
  void dispose() {
    // 取消队列事件订阅
    _queueSubscription?.cancel();
    super.dispose();
  }
}
