import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/api_key_info.dart';
import '../../../providers/api_key_notifier.dart';

/// 主页默认 API Key 配额摘要，压缩过程中随队列事件实时刷新
class QuotaSummaryBar extends StatelessWidget {
  const QuotaSummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<ApiKeyNotifier, ApiKeyInfo?>(
      selector: (_, notifier) {
        if (!notifier.isInitialized || notifier.apiKeys.isEmpty) {
          return null;
        }
        try {
          return notifier.apiKeys.firstWhere((key) => key.isDefault);
        } catch (_) {
          return notifier.apiKeys.first;
        }
      },
      builder: (context, apiKey, _) {
        if (apiKey == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final ratio = apiKey.quotaUsageRatio;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.data_usage,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${apiKey.alias} · ${apiKey.quotaUsageLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (ratio != null) ...[
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 3,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: apiKey.status == ApiKeyStatus.quotaFull
                              ? Colors.orange
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
