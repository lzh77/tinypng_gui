import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/tasks_notifier.dart';
import '../../../services/file_service.dart';

class StatisticsPanel extends StatelessWidget {
  const StatisticsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TasksNotifier>(
      builder: (context, tasksNotifier, _) {
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 状态统计
              Row(
                children: [
                  _buildStatItem(
                    context,
                    label: '总任务',
                    value: tasksNotifier.totalCount.toString(),
                    color: theme.colorScheme.onSurface,
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    context,
                    label: '已完成',
                    value: tasksNotifier.completedCount.toString(),
                    color: Colors.green,
                  ),
                  _buildDivider(),
                  _buildStatItem(
                    context,
                    label: '失败',
                    value: tasksNotifier.failedCount.toString(),
                    color: Colors.red,
                  ),
                ],
              ),

              // 空间节省统计
              Row(
                children: [
                  _buildStatItem(
                    context,
                    label: '原始大小',
                    value:
                        _formatBytes(context, tasksNotifier.totalOriginalSize),
                    color: theme.colorScheme.onSurfaceVariant,
                    isSmall: true,
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    context,
                    label: '压缩后',
                    value: _formatBytes(
                        context, tasksNotifier.totalCompressedSize),
                    color: Colors.green,
                    isSmall: true,
                  ),
                  _buildDivider(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '节省 ${_formatBytes(context, tasksNotifier.totalBytesSaved)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      if (tasksNotifier.averageCompressionRatio > 0 &&
                          tasksNotifier.averageCompressionRatio < 1)
                        Text(
                          '平均节省 ${(1 - tasksNotifier.averageCompressionRatio * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool isSmall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 16 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  String _formatBytes(BuildContext context, int bytes) {
    // 简单的格式化，实际项目中可以使用 FileService 或 intl 包
    // 这里我们简单复用一下，或者直接内联逻辑
    // 由于 FileService 是注入的，我们在 StatelessWidget 中不便直接调用实例方法
    // 除非我们从 context.read<FileService>() 获取，但这需要 FileService 暴露静态方法或我们在 Utils 类中定义
    // 既然 FileService 有实例方法 getFileSizeString，我们可以临时在这里实现一个简单的静态版本
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
