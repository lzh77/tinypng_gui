# TasksNotifier 使用示例

## 概述

`TasksNotifier` 是一个用于管理压缩任务状态的 `ChangeNotifier`，它负责：
- 管理压缩任务列表
- 提供任务统计信息
- 与 `QueueService` 集成，自动同步任务状态
- 提供便捷的任务操作方法

## 在 Provider 中注册

在应用根部配置 Provider：

```dart
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 首先创建服务
        Provider(
          create: (_) => QueueService(
            compressionService: CompressionService(...),
          ),
        ),
        
        // 然后创建依赖于服务的 Notifier
        ChangeNotifierProxyProvider<QueueService, TasksNotifier>(
          create: (context) => TasksNotifier(
            queueService: context.read<QueueService>(),
          ),
          update: (context, queueService, previous) {
            return previous ?? TasksNotifier(queueService: queueService);
          },
        ),
      ],
      child: MaterialApp(
        home: HomeScreen(),
      ),
    );
  }
}
```

## 基本使用

### 1. 添加任务

```dart
// 在 Widget 中使用
class FilePickerButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // 选择文件
        final files = await FileService().pickFiles();
        
        // 创建压缩任务
        final tasks = files.map((file) {
          return CompressionTask(
            id: Uuid().v4(),
            filePath: file.path,
            fileName: path.basename(file.path),
            originalSize: file.lengthSync(),
            status: CompressionStatus.pending,
            createdAt: DateTime.now(),
          );
        }).toList();
        
        // 添加到任务管理器
        context.read<TasksNotifier>().addTasks(tasks);
      },
      child: Text('选择文件'),
    );
  }
}
```

### 2. 监听任务列表变化

```dart
class TaskListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用 watch 监听任务列表变化
    final tasksNotifier = context.watch<TasksNotifier>();
    final tasks = tasksNotifier.tasks;
    
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ListTile(
          title: Text(task.fileName),
          subtitle: Text(_getStatusText(task.status)),
          trailing: _buildStatusIcon(task.status),
        );
      },
    );
  }
  
  String _getStatusText(CompressionStatus status) {
    switch (status) {
      case CompressionStatus.pending:
        return '等待中';
      case CompressionStatus.processing:
        return '压缩中';
      case CompressionStatus.completed:
        return '已完成';
      case CompressionStatus.failed:
        return '失败';
      case CompressionStatus.cancelled:
        return '已取消';
    }
  }
  
  Widget _buildStatusIcon(CompressionStatus status) {
    switch (status) {
      case CompressionStatus.pending:
        return Icon(Icons.schedule, color: Colors.grey);
      case CompressionStatus.processing:
        return CircularProgressIndicator();
      case CompressionStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green);
      case CompressionStatus.failed:
        return Icon(Icons.error, color: Colors.red);
      case CompressionStatus.cancelled:
        return Icon(Icons.cancel, color: Colors.grey);
    }
  }
}
```

### 3. 显示统计信息

```dart
class StatisticsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tasksNotifier = context.watch<TasksNotifier>();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('任务统计', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            _buildStatRow('总任务数', tasksNotifier.totalCount),
            _buildStatRow('待处理', tasksNotifier.pendingCount),
            _buildStatRow('处理中', tasksNotifier.processingCount),
            _buildStatRow('已完成', tasksNotifier.completedCount),
            _buildStatRow('失败', tasksNotifier.failedCount),
            Divider(),
            _buildStatRow(
              '原始大小',
              _formatBytes(tasksNotifier.totalOriginalSize),
            ),
            _buildStatRow(
              '压缩后大小',
              _formatBytes(tasksNotifier.totalCompressedSize),
            ),
            _buildStatRow(
              '节省空间',
              _formatBytes(tasksNotifier.totalBytesSaved),
            ),
            _buildStatRow(
              '平均压缩比',
              '${(tasksNotifier.averageCompressionRatio * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
```

### 4. 任务操作

```dart
class TaskActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton(
          onPressed: () {
            // 清空所有任务
            context.read<TasksNotifier>().clearAll();
          },
          child: Text('清空全部'),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            // 清空失败的任务
            context.read<TasksNotifier>().clearFailed();
          },
          child: Text('清空失败'),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            // 重试失败的任务
            context.read<TasksNotifier>().retryFailed();
          },
          child: Text('重试失败'),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            // 清空已完成的任务
            context.read<TasksNotifier>().clearCompleted();
          },
          child: Text('清空已完成'),
        ),
      ],
    );
  }
}
```

### 5. 单任务操作

```dart
class TaskListItem extends StatelessWidget {
  final CompressionTask task;
  
  const TaskListItem({required this.task});
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(task.fileName),
      subtitle: Text(task.filePath),
      trailing: IconButton(
        icon: Icon(Icons.delete),
        onPressed: () {
          // 移除单个任务
          context.read<TasksNotifier>().removeTask(task.id);
        },
      ),
      onTap: () {
        // 查看任务详情
        final task = context.read<TasksNotifier>().getTaskById(task.id);
        if (task != null) {
          _showTaskDetails(context, task);
        }
      },
    );
  }
  
  void _showTaskDetails(BuildContext context, CompressionTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('状态: ${task.status}'),
            Text('原始大小: ${task.originalSize} 字节'),
            if (task.compressedSize != null)
              Text('压缩后大小: ${task.compressedSize} 字节'),
            if (task.compressionRatio != null)
              Text('压缩比: ${(task.compressionRatio! * 100).toStringAsFixed(1)}%'),
            if (task.errorMessage != null)
              Text('错误: ${task.errorMessage}', style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }
}
```

## 自动队列同步

`TasksNotifier` 会自动监听 `QueueService` 的事件流，当队列中的任务状态发生变化时，会自动更新本地任务列表。这意味着你不需要手动同步任务状态。

```dart
// TasksNotifier 内部实现
void _handleQueueEvent(QueueEvent event) {
  if (event.currentTask != null) {
    final task = event.currentTask!;
    final index = _tasks.indexWhere((t) => t.id == task.id);
    
    if (index != -1) {
      _tasks[index] = task;
      notifyListeners(); // 自动通知 UI 更新
    }
  }
}
```

## 注意事项

1. **不可变列表**: `tasks` getter 返回的是不可修改的列表副本，确保外部无法直接修改任务列表。

2. **自动同步**: 添加、移除任务时会自动同步到 `QueueService`，无需手动调用队列服务。

3. **资源清理**: `TasksNotifier` 会在 `dispose` 时自动取消队列事件订阅，确保没有内存泄漏。

4. **线程安全**: 所有操作都在 UI 线程中执行，无需担心并发问题。

## 完整示例

参见项目中的 `HomeScreen` 实现，它展示了如何完整地使用 `TasksNotifier` 来构建一个功能完善的压缩任务管理界面。
