import 'package:equatable/equatable.dart';
import '../data/models/compression_task.dart';

/// 队列状态枚举
enum QueueStatus {
  idle, // 空闲
  running, // 正在运行
  paused, // 已暂停
  stopping, // 正在停止/取消
}

/// 队列事件类
/// 用于在队列状态发生变化或任务完成时通知监听者
class QueueEvent extends Equatable {
  final QueueStatus status;
  final CompressionTask? currentTask;
  final int completedCount;
  final int totalCount;
  final String? message;

  const QueueEvent({
    required this.status,
    this.currentTask,
    this.completedCount = 0,
    this.totalCount = 0,
    this.message,
  });

  factory QueueEvent.idle() => const QueueEvent(status: QueueStatus.idle);

  @override
  List<Object?> get props =>
      [status, currentTask, completedCount, totalCount, message];
}
