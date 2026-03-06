import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/settings_notifier.dart';

/// 输出设置区块
/// 包含输出目录选择、文件名后缀和是否覆盖原文件等配置
class OutputSection extends StatefulWidget {
  const OutputSection({super.key});

  @override
  State<OutputSection> createState() => _OutputSectionState();
}

class _OutputSectionState extends State<OutputSection> {
  late TextEditingController _suffixController;
  bool _isSuffixEditing = false;

  @override
  void initState() {
    super.initState();
    _suffixController = TextEditingController();
  }

  @override
  void dispose() {
    _suffixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, notifier, _) {
        // 同步控制器文本（仅在非编辑状态下）
        if (!_isSuffixEditing) {
          _suffixController.text = notifier.settings.fileNameSuffix;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输出设置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            // 输出目录
            _buildOutputDirectoryCard(context, notifier),
            const SizedBox(height: 12),
            // 覆盖原文件开关
            _buildOverwriteCard(context, notifier),
            const SizedBox(height: 12),
            // 文件名后缀
            _buildSuffixCard(context, notifier),
          ],
        );
      },
    );
  }

  Widget _buildOutputDirectoryCard(
      BuildContext context, SettingsNotifier notifier) {
    final String outputDir = notifier.settings.outputDirectory;
    final bool isOverwrite = notifier.settings.overwriteOriginal;

    return _SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('输出目录'),
                    Text(
                      '压缩后的文件保存位置（覆盖原文件时忽略）',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    outputDir.isEmpty ? '（与原文件相同目录）' : outputDir,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: outputDir.isEmpty
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.onSurface,
                          fontFamily:
                              outputDir.isEmpty ? null : 'monospace',
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 选择目录按钮
              OutlinedButton.icon(
                onPressed: isOverwrite
                    ? null
                    : () => _pickOutputDirectory(context, notifier),
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('选择'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              if (outputDir.isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: '清除（使用原文件目录）',
                  onPressed: () =>
                      notifier.updateOutputDirectory(''),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverwriteCard(BuildContext context, SettingsNotifier notifier) {
    return _SettingCard(
      child: Row(
        children: [
          Icon(
            Icons.save_as_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('覆盖原文件'),
                Text(
                  '压缩完成后直接替换原始文件（开启后输出目录设置将被忽略）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: notifier.settings.overwriteOriginal,
            onChanged: (value) =>
                notifier.updateOverwriteOriginal(value),
          ),
        ],
      ),
    );
  }

  Widget _buildSuffixCard(BuildContext context, SettingsNotifier notifier) {
    return _SettingCard(
      child: Row(
        children: [
          Icon(
            Icons.drive_file_rename_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('文件名后缀'),
                Text(
                  '保存压缩文件时附加的后缀，留空则不添加',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _suffixController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: '_compressed',
                isDense: true,
              ),
              onTap: () => setState(() => _isSuffixEditing = true),
              onSubmitted: (value) {
                setState(() => _isSuffixEditing = false);
                notifier.updateFileNameSuffix(value);
              },
              onEditingComplete: () {
                setState(() => _isSuffixEditing = false);
                notifier.updateFileNameSuffix(_suffixController.text);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickOutputDirectory(
      BuildContext context, SettingsNotifier notifier) async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择输出目录',
    );
    if (directoryPath != null && context.mounted) {
      await notifier.updateOutputDirectory(directoryPath);
    }
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
