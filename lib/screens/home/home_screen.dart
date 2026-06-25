import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tasks_notifier.dart';
import '../../services/file_service.dart';
import '../../services/logger_service.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'task_import_helper.dart';
import 'widgets/action_toolbar.dart';
import 'widgets/file_list_item.dart';
import 'widgets/statistics_panel.dart';
import 'widgets/queue_control_buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final dropEnabled = ModalRoute.of(context)?.isCurrent ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TinyPNG 批量压缩工具'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: DropTarget(
        enable: dropEnabled,
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: _onDragDone,
        child: Stack(
          children: [
            Column(
              children: [
                const ActionToolbar(),
                const StatisticsPanel(),
                Expanded(child: _buildTaskList()),
                const QueueControlButtons(),
              ],
            ),
            if (_isDragging) _buildDropOverlay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDropOverlay(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_download_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '松开以添加图片',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '支持图片文件或文件夹',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onDragDone(DropDoneDetails details) async {
    setState(() => _isDragging = false);

    final paths = details.files
        .map((file) => file.path)
        .where((path) => path.isNotEmpty)
        .toList();

    if (paths.isEmpty || !mounted) return;

    final fileService = context.read<FileService>();
    final tasksNotifier = context.read<TasksNotifier>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final tasks = await TaskImportHelper.buildTasksFromPaths(
        paths,
        fileService,
        recursiveDirectoryScan: true,
      );

      if (!mounted) return;

      if (tasks.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('未找到支持的图片文件')),
        );
        return;
      }

      tasksNotifier.addTasks(tasks);
      messenger.showSnackBar(
        SnackBar(content: Text('已添加 ${tasks.length} 个文件')),
      );
    } catch (e, stackTrace) {
      LoggerService.e('拖拽导入失败', e, stackTrace);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('拖拽导入失败: $e')),
        );
      }
    }
  }

  Widget _buildTaskList() {
    return Consumer<TasksNotifier>(
      builder: (context, tasksNotifier, child) {
        final tasks = tasksNotifier.tasks;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '没有任务',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击上方按钮添加，或将图片/文件夹拖拽到此处',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return FileListItem(
              key: ValueKey(task.id),
              task: task,
            );
          },
        );
      },
    );
  }
}
