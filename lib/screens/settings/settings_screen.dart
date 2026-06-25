import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/api_key_notifier.dart';
import '../../providers/settings_notifier.dart';
import 'widgets/api_key_section.dart';
import 'widgets/appearance_section.dart';
import 'widgets/compression_section.dart';
import 'widgets/output_section.dart';

/// 设置页面
/// 包含 API Key 管理、压缩设置、输出设置和外观设置四大区块
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('设置'),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // 重置为默认设置按钮
        IconButton(
          icon: const Icon(Icons.restore),
          tooltip: '重置默认设置',
          onPressed: () => _confirmReset(context),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, notifier, _) {
        if (notifier.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              // 限制内容最大宽度，在大屏幕上提升可读性
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 错误提示
                  if (notifier.error != null) ...[
                    _buildErrorBanner(context, notifier),
                    const SizedBox(height: 16),
                  ],
                  // 1. API Key 管理区块
                  const ApiKeySection(),
                  const SizedBox(height: 28),
                  _buildDivider(context),
                  const SizedBox(height: 28),
                  // 2. 压缩设置区块
                  const CompressionSection(),
                  const SizedBox(height: 28),
                  _buildDivider(context),
                  const SizedBox(height: 28),
                  // 3. 输出设置区块
                  const OutputSection(),
                  const SizedBox(height: 28),
                  _buildDivider(context),
                  const SizedBox(height: 28),
                  // 4. 外观设置区块
                  const AppearanceSection(),
                  // 底部安全边距
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildErrorBanner(BuildContext context, SettingsNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notifier.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置设置'),
        content: const Text('确认将所有设置恢复为默认值？\nAPI Key 列表也将被清空，此操作不可撤销。'),
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
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<ApiKeyNotifier>().clearAllKeys();
      await context.read<SettingsNotifier>().resetToDefault();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已恢复为默认值')),
        );
      }
    }
  }
}
