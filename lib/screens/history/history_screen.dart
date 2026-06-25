import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/history_notifier.dart';
import 'widgets/history_list_item.dart';
import 'widgets/history_summary_panel.dart';

/// 压缩历史记录页面
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryNotifier>().refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HistoryNotifier>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空历史',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: Consumer<HistoryNotifier>(
        builder: (context, notifier, _) {
          if (notifier.isLoading && notifier.records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (notifier.error != null) _buildErrorBanner(context, notifier),
              if (notifier.statistics != null)
                HistorySummaryPanel(statistics: notifier.statistics!),
              Expanded(child: _buildList(context, notifier)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, HistoryNotifier notifier) {
    return MaterialBanner(
      content: Text(notifier.error!),
      leading: const Icon(Icons.error_outline),
      actions: [
        TextButton(
          onPressed: notifier.refresh,
          child: const Text('重试'),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, HistoryNotifier notifier) {
    if (notifier.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无历史记录',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '压缩完成的文件会自动记录在此',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: notifier.records.length + (notifier.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= notifier.records.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final record = notifier.records[index];
          return HistoryListItem(
            key: ValueKey(record.id),
            record: record,
            onDelete: () => notifier.deleteRecord(record.id),
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final notifier = context.read<HistoryNotifier>();
    if (notifier.records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可清空的历史记录')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要删除全部压缩历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await notifier.clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('历史记录已清空')),
        );
      }
    }
  }
}
