import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/queue_status_notifier.dart';
import '../../../services/queue_event.dart';

class QueueControlButtons extends StatelessWidget {
  const QueueControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueStatusNotifier>(
      builder: (context, queueStatus, _) {
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 状态文本与进度
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _buildStatusIcon(context, queueStatus.status),
                        const SizedBox(width: 8),
                        Text(
                          queueStatus.getStatusText(),
                          style: theme.textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          queueStatus.getProgressText(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          queueStatus.totalCount > 0 ? queueStatus.progress : 0,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(context, queueStatus.status),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // 控制按钮组
              _buildButtons(context, queueStatus),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(BuildContext context, QueueStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case QueueStatus.idle:
        icon = Icons.check_circle_outline;
        color = Colors.grey;
        break;
      case QueueStatus.running:
        icon = Icons.play_circle_filled;
        color = Colors.green;
        break;
      case QueueStatus.paused:
        icon = Icons.pause_circle_filled;
        color = Colors.orange;
        break;
      case QueueStatus.stopping:
        icon = Icons.stop_circle;
        color = Colors.red;
        break;
    }

    return Icon(icon, color: color, size: 24);
  }

  Color _getStatusColor(BuildContext context, QueueStatus status) {
    switch (status) {
      case QueueStatus.running:
        return Colors.green;
      case QueueStatus.paused:
        return Colors.orange;
      case QueueStatus.stopping:
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildButtons(BuildContext context, QueueStatusNotifier queueStatus) {
    if (queueStatus.isIdle) {
      // 空闲状态：显示开始按钮
      return FilledButton.icon(
        onPressed: queueStatus.canStart ? queueStatus.start : null,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始压缩'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      );
    } else if (queueStatus.isRunning) {
      // 运行状态：显示暂停和停止
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: queueStatus.pause,
            icon: const Icon(Icons.pause),
            label: const Text('暂停'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmStop(context, queueStatus),
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ],
      );
    } else if (queueStatus.isPaused) {
      // 暂停状态：显示继续和停止
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: queueStatus.resume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('继续'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _confirmStop(context, queueStatus),
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ],
      );
    } else {
      // 停止中
      return OutlinedButton.icon(
        onPressed: null,
        icon: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('正在停止...'),
      );
    }
  }

  Future<void> _confirmStop(
      BuildContext context, QueueStatusNotifier queueStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认停止'),
        content: const Text('确定要停止处理队列吗？\n当前正在处理的任务将完成，未开始的任务将被取消。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('停止'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await queueStatus.stop();
    }
  }
}
