import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

import '../../../data/models/compression_task.dart';
import '../../../data/models/history_record.dart';
import '../../../services/file_service.dart';

/// 单条历史记录列表项
class HistoryListItem extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback? onDelete;

  const HistoryListItem({
    super.key,
    required this.record,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileService = FileService();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(record.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _buildFileIcon(theme),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.fileName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.dirname(record.filePath),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (record.status == CompressionStatus.failed &&
                      record.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        record.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(theme),
                  const SizedBox(height: 6),
                  _buildSizeInfo(theme, fileService),
                ],
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: '删除',
                color: theme.colorScheme.error,
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(ThemeData theme) {
    final ext = p.extension(record.fileName).toLowerCase();
    Color iconColor = theme.colorScheme.primary;

    if (ext == '.png') {
      iconColor = Colors.orange;
    } else if (ext == '.jpg' || ext == '.jpeg') {
      iconColor = Colors.blue;
    } else if (ext == '.webp') {
      iconColor = Colors.green;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, color: iconColor, size: 22),
    );
  }

  Widget _buildStatusChip(ThemeData theme) {
    final isSuccess = record.status == CompressionStatus.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isSuccess ? Colors.green : theme.colorScheme.error)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSuccess ? '成功' : '失败',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSuccess ? Colors.green.shade700 : theme.colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSizeInfo(ThemeData theme, FileService fileService) {
    final originalStr = fileService.getFileSizeString(record.originalSize);

    if (record.status == CompressionStatus.completed &&
        record.compressedSize != null) {
      final compressedStr =
          fileService.getFileSizeString(record.compressedSize!);
      final ratio = ((record.savingsRatio ?? 0) * 100).toStringAsFixed(1);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            originalStr,
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            compressedStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '-$ratio%',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.green),
          ),
        ],
      );
    }

    return Text(
      originalStr,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
