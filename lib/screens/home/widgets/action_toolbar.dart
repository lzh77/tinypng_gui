import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../data/models/compression_task.dart';
import '../../../providers/tasks_notifier.dart';
import '../../../services/file_service.dart';
import '../../../services/logger_service.dart';
import '../task_import_helper.dart';

class ActionToolbar extends StatelessWidget {
  const ActionToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => _pickFiles(context),
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('添加文件'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 0,
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _pickDirectory(context),
            icon: const Icon(Icons.create_new_folder),
            label: const Text('添加文件夹'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const Spacer(),
          Consumer<TasksNotifier>(
            builder: (context, tasksNotifier, _) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                tooltip: '更多选项',
                onSelected: (value) {
                  switch (value) {
                    case 'clear_all':
                      tasksNotifier.clearAll();
                      break;
                    case 'clear_completed':
                      tasksNotifier.clearCompleted();
                      break;
                    case 'clear_failed':
                      tasksNotifier.clearFailed();
                      break;
                    case 'retry_failed':
                      tasksNotifier.retryFailed();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (tasksNotifier.failedCount > 0)
                    const PopupMenuItem(
                      value: 'retry_failed',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('重试所有失败任务'),
                        ],
                      ),
                    ),
                  if (tasksNotifier.completedCount > 0)
                    const PopupMenuItem(
                      value: 'clear_completed',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Text('清空已完成'),
                        ],
                      ),
                    ),
                  if (tasksNotifier.failedCount > 0)
                    const PopupMenuItem(
                      value: 'clear_failed',
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('清空失败'),
                        ],
                      ),
                    ),
                  if (tasksNotifier.totalCount > 0) ...[
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, color: Colors.red),
                          SizedBox(width: 8),
                          Text('清空全部任务', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'avif'],
        allowMultiple: true,
        dialogTitle: '选择要压缩的图片',
      );

      if (result == null || result.files.isEmpty) return;
      if (!context.mounted) return;

      final tasksNotifier = context.read<TasksNotifier>();
      final fileService = context.read<FileService>();

      final paths = result.files
          .map((file) => file.path)
          .where((path) => path != null)
          .cast<String>()
          .toList();

      final tasks = await TaskImportHelper.buildTasksFromPaths(
        paths,
        fileService,
      );

      if (!context.mounted) return;

      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未选择支持的图片文件')),
        );
        return;
      }

      tasksNotifier.addTasks(tasks);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${tasks.length} 个文件')),
      );
    } catch (e) {
      LoggerService.e('选择文件失败', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _pickDirectory(BuildContext context) async {
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择包含图片的文件夹',
      );

      if (directoryPath == null || !context.mounted) return;

      final tasksNotifier = context.read<TasksNotifier>();
      final fileService = context.read<FileService>();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      List<CompressionTask> tasks;
      try {
        tasks = await TaskImportHelper.buildTasksFromPaths(
          [directoryPath],
          fileService,
        );
      } finally {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }

      if (!context.mounted) return;

      if (tasks.isNotEmpty) {
        tasksNotifier.addTasks(tasks);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${tasks.length} 个文件')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该文件夹没有支持的图片文件')),
        );
      }
    } catch (e) {
      LoggerService.e('选择文件夹失败', e);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }
}
