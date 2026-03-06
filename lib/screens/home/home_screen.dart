import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tasks_notifier.dart';
import '../settings/settings_screen.dart';
import 'widgets/action_toolbar.dart';
import 'widgets/file_list_item.dart';
import 'widgets/statistics_panel.dart';
import 'widgets/queue_control_buttons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              // TODO: 导航到历史记录页面
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('历史记录页面开发中...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 操作栏
          const ActionToolbar(),

          // 2. 统计面板
          const StatisticsPanel(),

          // 3. 任务列表
          Expanded(
            child: _buildTaskList(),
          ),

          // 4. 队列控制按钮
          const QueueControlButtons(),
        ],
      ),
    );
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
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
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
                  '点击上方按钮添加图片或文件夹',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80), // 底部留出空间给FAB（如果有）
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
