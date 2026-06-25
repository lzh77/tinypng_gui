import 'package:flutter/material.dart';

import '../../../services/file_service.dart';
import '../../../services/history_service.dart';

/// 历史记录汇总统计面板
class HistorySummaryPanel extends StatelessWidget {
  final HistoryStatistics statistics;

  const HistorySummaryPanel({
    super.key,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileService = FileService();
    final savingsPercent =
        (statistics.averageSavingsRatio * 100).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                label: '记录数',
                value: '${statistics.totalCount}',
                icon: Icons.history,
              ),
            ),
            _divider(theme),
            Expanded(
              child: _StatItem(
                label: '成功 / 失败',
                value: '${statistics.successCount} / ${statistics.failedCount}',
                icon: Icons.check_circle_outline,
              ),
            ),
            _divider(theme),
            Expanded(
              child: _StatItem(
                label: '节省空间',
                value: fileService.getFileSizeString(statistics.totalBytesSaved),
                icon: Icons.savings_outlined,
              ),
            ),
            _divider(theme),
            Expanded(
              child: _StatItem(
                label: '平均压缩率',
                value: '$savingsPercent%',
                icon: Icons.compress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(ThemeData theme) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
