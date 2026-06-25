import 'package:flutter/material.dart';
import '../../../data/models/compression_task.dart';
import '../../../providers/tasks_notifier.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class FileListItem extends StatelessWidget {
  final CompressionTask task;

  const FileListItem({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1, // 轻微提升，更现代
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // 1. 图标区域
            _buildFileIcon(context),
            const SizedBox(width: 16),

            // 2. 信息区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件名
                  Text(
                    task.fileName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 路径
                  Text(
                    p.dirname(task.filePath),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 进度条（仅在处理中显示）
                  if (task.status == CompressionStatus.processing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),

                  // 错误信息（仅在失败时显示）
                  if (task.status == CompressionStatus.failed &&
                      task.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '错误: ${task.errorMessage}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. 状态与统计
            SizedBox(
              width: 140, // 固定宽度以对齐
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusText(context),
                  const SizedBox(height: 4),
                  _buildSizeInfo(context),
                ],
              ),
            ),

            // 4. 操作按钮
            const SizedBox(width: 8),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(BuildContext context) {
    final theme = Theme.of(context);
    final ext = p.extension(task.fileName).toLowerCase();

    IconData iconData = Icons.image;
    Color iconColor = theme.colorScheme.primary;

    // 简单的根据扩展名着色
    if (ext == '.png') {
      iconColor = Colors.orange;
    } else if (ext == '.jpg' || ext == '.jpeg') {
      iconColor = Colors.blue;
    } else if (ext == '.webp') {
      iconColor = Colors.green;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: iconColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildStatusText(BuildContext context) {
    final theme = Theme.of(context);
    String text;
    Color color;

    switch (task.status) {
      case CompressionStatus.pending:
        text = '等待中';
        color = theme.colorScheme.outline;
        break;
      case CompressionStatus.processing:
        text = '压缩中...';
        color = theme.colorScheme.primary;
        break;
      case CompressionStatus.completed:
        text = '完成';
        color = Colors.green;
        break;
      case CompressionStatus.failed:
        text = '失败';
        color = theme.colorScheme.error;
        break;
      case CompressionStatus.cancelled:
        text = '已取消';
        color = theme.colorScheme.outline;
        break;
    }

    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSizeInfo(BuildContext context) {
    final theme = Theme.of(context);

    // 原始大小总是显示
    final originalSizeStr = _formatBytes(task.originalSize);

    if (task.status == CompressionStatus.completed &&
        task.compressedSize != null) {
      // 成功：显示箭头和新大小
      final compressedSizeStr = _formatBytes(task.compressedSize!);
      final ratio = ((1 - (task.compressedSize! / task.originalSize)) * 100)
          .toStringAsFixed(1);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            originalSizeStr,
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            compressedSizeStr,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '-$ratio%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.green,
            ),
          ),
        ],
      );
    } else {
      // 其他状态：仅显示原始大小
      return Text(
        originalSizeStr,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    // 仅在非处理中状态显示删除/重试按钮
    if (task.status == CompressionStatus.processing) {
      return const SizedBox(width: 48, height: 48); // 占位
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        // 失败的任务可以重试
        if (task.status == CompressionStatus.failed) {
          items.add(
            const PopupMenuItem(
              value: 'retry',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('重试'),
                ],
              ),
            ),
          );
        }

        // 所有任务都可以删除
        items.add(
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('移除'),
              ],
            ),
          ),
        );

        return items;
      },
      onSelected: (value) {
        final tasksNotifier = context.read<TasksNotifier>();
        if (value == 'delete') {
          tasksNotifier.removeTask(task.id);
        } else if (value == 'retry') {
          final resetTask = CompressionTask(
            id: task.id,
            filePath: task.filePath,
            fileName: task.fileName,
            originalSize: task.originalSize,
            status: CompressionStatus.pending,
            errorMessage: null, // 清除错误
            compressionRatio: null,
            compressedSize: null,
            createdAt: task.createdAt,
            completedAt: null,
            baseDir: task.baseDir,
          );
          tasksNotifier.removeTask(task.id);
          tasksNotifier.addTask(resetTask);
        }
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
