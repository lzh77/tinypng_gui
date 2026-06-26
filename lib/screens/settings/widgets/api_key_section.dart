import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/api_key_info.dart';
import '../../../providers/api_key_notifier.dart';
import 'add_api_key_dialog.dart';

/// API Key 管理区块
/// 通过 [ApiKeyNotifier] 读写安全存储，与压缩流程共用 [ApiKeyService]
class ApiKeySection extends StatelessWidget {
  const ApiKeySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiKeyNotifier>(
      builder: (context, notifier, _) {
        if (!notifier.isInitialized && notifier.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final List<ApiKeyInfo> apiKeys = notifier.apiKeys;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, apiKeys, notifier),
            if (notifier.error != null) ...[
              const SizedBox(height: 8),
              _buildErrorBanner(context, notifier.error!),
            ],
            const SizedBox(height: 8),
            if (apiKeys.isEmpty)
              _buildEmptyState(context)
            else
              _buildKeyList(context, apiKeys, notifier),
          ],
        );
      },
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    List<ApiKeyInfo> apiKeys,
    ApiKeyNotifier notifier,
  ) {
    return Row(
      children: [
        Text(
          'API Key 管理',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${apiKeys.length} 个',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
          ),
        ),
        const Spacer(),
        FilledButton.tonalIcon(
          onPressed: notifier.isLoading ? null : () => _showAddApiKeyDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('添加'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.key_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            '尚未添加 API Key',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右上角"添加"按钮以添加您的 TinyPNG API Key',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyList(
    BuildContext context,
    List<ApiKeyInfo> apiKeys,
    ApiKeyNotifier notifier,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: apiKeys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final ApiKeyInfo apiKey = apiKeys[index];
        return _ApiKeyCard(
          apiKey: apiKey,
          onSetDefault: notifier.isLoading
              ? null
              : () => notifier.setDefaultKey(apiKey.id),
          onDelete: notifier.isLoading
              ? null
              : () => _confirmDelete(context, notifier, apiKey),
        );
      },
    );
  }

  Future<void> _showAddApiKeyDialog(BuildContext context) async {
    final ApiKeyInfo? result = await showDialog<ApiKeyInfo>(
      context: context,
      builder: (_) => const AddApiKeyDialog(),
    );
    if (result == null || !context.mounted) return;

    final ApiKeyNotifier notifier = context.read<ApiKeyNotifier>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final bool success = await notifier.addApiKey(
      key: result.key,
      alias: result.alias,
    );

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'API Key 已添加' : (notifier.error ?? '添加 API Key 失败'),
        ),
        backgroundColor: success ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ApiKeyNotifier notifier,
    ApiKeyInfo apiKey,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 API Key'),
        content: Text('确认删除「${apiKey.alias}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await notifier.removeApiKey(apiKey.id);
    }
  }
}

/// 单张 API Key 卡片
class _ApiKeyCard extends StatelessWidget {
  final ApiKeyInfo apiKey;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;

  const _ApiKeyCard({
    required this.apiKey,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDefault = apiKey.isDefault;
    final Color statusColor = _resolveStatusColor(context, apiKey.status);
    final String statusLabel = _resolveStatusLabel(apiKey.status);
    final String maskedKey = _maskKey(apiKey.key);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDefault
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.key,
            color: isDefault
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      apiKey.alias,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 6),
                      _buildBadge(context, '默认',
                          Theme.of(context).colorScheme.primary),
                    ],
                    const SizedBox(width: 6),
                    _buildBadge(context, statusLabel, statusColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  maskedKey,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  apiKey.quotaUsageLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                if (apiKey.quotaUsageRatio != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: apiKey.quotaUsageRatio,
                      minHeight: 4,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      color: apiKey.status == ApiKeyStatus.quotaFull
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isDefault)
            IconButton(
              icon: const Icon(Icons.star_border, size: 20),
              tooltip: '设为默认',
              onPressed: onSetDefault,
            ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: '删除',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _resolveStatusColor(BuildContext context, ApiKeyStatus status) {
    return switch (status) {
      ApiKeyStatus.active => Colors.green,
      ApiKeyStatus.quotaFull => Colors.orange,
      ApiKeyStatus.invalid => Theme.of(context).colorScheme.error,
      ApiKeyStatus.disabled => Theme.of(context).colorScheme.outline,
    };
  }

  String _resolveStatusLabel(ApiKeyStatus status) {
    return switch (status) {
      ApiKeyStatus.active => '正常',
      ApiKeyStatus.quotaFull => '配额已满',
      ApiKeyStatus.invalid => '无效',
      ApiKeyStatus.disabled => '已禁用',
    };
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 4)}••••••••${key.substring(key.length - 4)}';
  }
}
