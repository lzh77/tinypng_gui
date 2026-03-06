import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_notifier.dart';

/// 压缩设置区块
/// 包含并发限制和失败重试次数等压缩相关参数的配置
class CompressionSection extends StatelessWidget {
  const CompressionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, notifier, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '压缩设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            // 并发限制
            _ConcurrentLimitTile(notifier: notifier),
            const SizedBox(height: 16),
            // 重试次数
            _RetryCountTile(notifier: notifier),
            const SizedBox(height: 16),
            // 自动轮换 API Key
            _SwitchSettingTile(
              icon: Icons.sync,
              title: '自动轮换 API Key',
              subtitle: '当单个 Key 配额满时自动切换到其他可用 Key',
              value: notifier.settings.autoRotateKeys,
              onChanged: (value) => notifier.updateAutoRotateKeys(value),
            ),
          ],
        );
      },
    );
  }
}

/// 并发限制滑块磁贴
class _ConcurrentLimitTile extends StatelessWidget {
  final SettingsNotifier notifier;

  const _ConcurrentLimitTile({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final int limit = notifier.settings.concurrentLimit;
    return _SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('并发压缩数量'),
                    Text(
                      '同时进行压缩任务的最大数量',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$limit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: limit.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '$limit',
            onChanged: (value) =>
                notifier.updateConcurrentLimit(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1（最低）',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              Text(
                '10（最高）',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 失败重试次数滑块磁贴
class _RetryCountTile extends StatelessWidget {
  final SettingsNotifier notifier;

  const _RetryCountTile({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final int count = notifier.settings.retryCount;
    return _SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.refresh,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('失败重试次数'),
                    Text(
                      '压缩失败时自动重试的最大次数',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count == 0 ? '不重试' : '$count 次',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: count.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            label: count == 0 ? '不重试' : '$count 次',
            onChanged: (value) => notifier.updateRetryCount(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0（不重试）',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              Text(
                '5 次',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 开关类型的设置行（用于 autoRotateKeys 等布尔值设置）
class _SwitchSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 通用设置卡片容器
class _SettingCard extends StatelessWidget {
  final Widget child;

  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: child,
    );
  }
}
