# TinyPNG GUI - 状态管理完整指南

## 概述

本项目使用 **Provider** 进行状态管理，包含三个核心的 `ChangeNotifier`：

1. **SettingsNotifier** - 应用设置状态管理
2. **TasksNotifier** - 任务列表状态管理
3. **QueueStatusNotifier** - 队列状态管理

## Provider 架构配置

### 完整的 Provider 树结构

```dart
import 'package:provider/provider.dart';
import 'package:tinypng_gui/providers/providers.dart';
import 'package:tinypng_gui/services/queue_service.dart';
import 'package:tinypng_gui/services/compression_service.dart';
import 'package:tinypng_gui/services/file_service.dart';
import 'package:tinypng_gui/data/datasources/local/settings_local_data_source.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ========== 数据源层 ==========
        Provider(
          create: (_) => SettingsLocalDataSource(),
        ),
        
        // ========== 服务层 ==========
        Provider(
          create: (_) => FileService(),
        ),
        
        Provider(
          create: (_) => CompressionService(
            // 配置压缩服务
          ),
        ),
        
        ProxyProvider<CompressionService, QueueService>(
          update: (context, compressionService, previous) {
            return previous ?? QueueService(
              compressionService: compressionService,
            );
          },
        ),
        
        // ========== 状态管理层 ==========
        
        // 1. 设置状态管理
        ChangeNotifierProxyProvider<SettingsLocalDataSource, SettingsNotifier>(
          create: (context) => SettingsNotifier(
            dataSource: context.read<SettingsLocalDataSource>(),
          ),
          update: (context, dataSource, previous) {
            return previous ?? SettingsNotifier(dataSource: dataSource);
          },
        ),
        
        // 2. 任务状态管理
        ChangeNotifierProxyProvider<QueueService, TasksNotifier>(
          create: (context) => TasksNotifier(
            queueService: context.read<QueueService>(),
          ),
          update: (context, queueService, previous) {
            return previous ?? TasksNotifier(queueService: queueService);
          },
        ),
        
        // 3. 队列状态管理
        ChangeNotifierProxyProvider<QueueService, QueueStatusNotifier>(
          create: (context) => QueueStatusNotifier(
            queueService: context.read<QueueService>(),
          ),
          update: (context, queueService, previous) {
            return previous ?? QueueStatusNotifier(queueService: queueService);
          },
        ),
      ],
      child: MaterialApp(
        title: 'TinyPNG GUI',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: HomeScreen(),
      ),
    );
  }
}
```

## 主界面集成示例

### 完整的 HomeScreen 实现

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinypng_gui/providers/providers.dart';
import 'package:tinypng_gui/services/file_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 加载设置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsNotifier>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TinyPNG 批量压缩工具'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // 导航到设置页面
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 文件操作工具栏
          _buildFileOperationsBar(),
          
          // 2. 队列状态显示
          _buildQueueStatusPanel(),
          
          // 3. 任务列表
          Expanded(
            child: _buildTasksList(),
          ),
          
          // 4. 统计面板
          _buildStatisticsPanel(),
          
          // 5. 队列控制按钮
          _buildQueueControls(),
        ],
      ),
    );
  }

  /// 文件操作工具栏
  Widget _buildFileOperationsBar() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _pickFiles,
            icon: Icon(Icons.add_photo_alternate),
            label: Text('添加文件'),
          ),
          SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _pickDirectory,
            icon: Icon(Icons.folder_open),
            label: Text('添加文件夹'),
          ),
          Spacer(),
          Consumer<TasksNotifier>(
            builder: (context, tasksNotifier, _) {
              return PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Text('清空全部'),
                    onTap: () => tasksNotifier.clearAll(),
                  ),
                  PopupMenuItem(
                    child: Text('清空失败'),
                    onTap: () => tasksNotifier.clearFailed(),
                  ),
                  PopupMenuItem(
                    child: Text('清空已完成'),
                    onTap: () => tasksNotifier.clearCompleted(),
                  ),
                  PopupMenuItem(
                    child: Text('重试失败'),
                    onTap: () => tasksNotifier.retryFailed(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 队列状态面板
  Widget _buildQueueStatusPanel() {
    return Consumer<QueueStatusNotifier>(
      builder: (context, queueStatus, _) {
        return Container(
          padding: EdgeInsets.all(16),
          color: _getStatusColor(queueStatus.status).withOpacity(0.1),
          child: Column(
            children: [
              Row(
                children: [
                  _buildStatusIndicator(queueStatus.status),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      queueStatus.getStatusText(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    queueStatus.getProgressText(),
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: queueStatus.progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStatusColor(queueStatus.status),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 任务列表
  Widget _buildTasksList() {
    return Consumer<TasksNotifier>(
      builder: (context, tasksNotifier, _) {
        final tasks = tasksNotifier.tasks;
        
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '没有任务',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  '点击上方按钮添加文件',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return ListTile(
              leading: _buildTaskStatusIcon(task.status),
              title: Text(task.fileName),
              subtitle: Row(
                children: [
                  Text(_formatBytes(task.originalSize)),
                  if (task.compressedSize != null) ...[
                    Text(' → '),
                    Text(
                      _formatBytes(task.compressedSize!),
                      style: TextStyle(color: Colors.green),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(${(task.compressionRatio! * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline),
                onPressed: () => tasksNotifier.removeTask(task.id),
              ),
            );
          },
        );
      },
    );
  }

  /// 统计面板
  Widget _buildStatisticsPanel() {
    return Consumer<TasksNotifier>(
      builder: (context, tasksNotifier, _) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('总计', tasksNotifier.totalCount, Colors.blue),
              _buildStatItem('待处理', tasksNotifier.pendingCount, Colors.grey),
              _buildStatItem('处理中', tasksNotifier.processingCount, Colors.orange),
              _buildStatItem('已完成', tasksNotifier.completedCount, Colors.green),
              _buildStatItem('失败', tasksNotifier.failedCount, Colors.red),
            ],
          ),
        );
      },
    );
  }

  /// 队列控制按钮
  Widget _buildQueueControls() {
    return Consumer<QueueStatusNotifier>(
      builder: (context, queueStatus, _) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (queueStatus.canStart)
                ElevatedButton.icon(
                  onPressed: () => queueStatus.start(),
                  icon: Icon(Icons.play_arrow),
                  label: Text('开始压缩'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              
              if (queueStatus.isRunning) ...[
                ElevatedButton.icon(
                  onPressed: () => queueStatus.pause(),
                  icon: Icon(Icons.pause),
                  label: Text('暂停'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmStop(queueStatus),
                  icon: Icon(Icons.stop),
                  label: Text('停止'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
              
              if (queueStatus.isPaused) ...[
                ElevatedButton.icon(
                  onPressed: () => queueStatus.resume(),
                  icon: Icon(Icons.play_arrow),
                  label: Text('继续'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _confirmStop(queueStatus),
                  icon: Icon(Icons.stop),
                  label: Text('停止'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ========== 辅助方法 ==========

  Future<void> _pickFiles() async {
    final fileService = context.read<FileService>();
    final files = await fileService.pickFiles();
    
    if (files.isEmpty) return;
    
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
    
    context.read<TasksNotifier>().addTasks(tasks);
  }

  Future<void> _pickDirectory() async {
    final fileService = context.read<FileService>();
    final files = await fileService.pickDirectory();
    
    if (files.isEmpty) return;
    
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
    
    context.read<TasksNotifier>().addTasks(tasks);
  }

  Future<void> _confirmStop(QueueStatusNotifier queueStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认停止'),
        content: Text('确定要停止处理队列吗？未完成的任务将被取消。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('停止'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await queueStatus.stop();
    }
  }

  Widget _buildStatusIndicator(QueueStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case QueueStatus.idle:
        color = Colors.grey;
        icon = Icons.check_circle_outline;
        break;
      case QueueStatus.running:
        color = Colors.green;
        icon = Icons.play_circle_filled;
        break;
      case QueueStatus.paused:
        color = Colors.orange;
        icon = Icons.pause_circle_filled;
        break;
      case QueueStatus.stopping:
        color = Colors.red;
        icon = Icons.stop_circle;
        break;
    }
    
    return Icon(icon, color: color);
  }

  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.running:
        return Colors.green;
      case QueueStatus.paused:
        return Colors.orange;
      case QueueStatus.stopping:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildTaskStatusIcon(CompressionStatus status) {
    switch (status) {
      case CompressionStatus.pending:
        return Icon(Icons.schedule, color: Colors.grey);
      case CompressionStatus.processing:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case CompressionStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green);
      case CompressionStatus.failed:
        return Icon(Icons.error, color: Colors.red);
      case CompressionStatus.cancelled:
        return Icon(Icons.cancel, color: Colors.grey);
    }
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
```

## 最佳实践

### 1. 使用 Consumer 减少重建

```dart
// ❌ 不好：整个 Widget 都会重建
Widget build(BuildContext context) {
  final tasksNotifier = context.watch<TasksNotifier>();
  return Container(
    child: SomeExpensiveWidget(),
  );
}

// ✅ 好：只有 Consumer 内部会重建
Widget build(BuildContext context) {
  return Container(
    child: Consumer<TasksNotifier>(
      builder: (context, tasksNotifier, child) {
        return Text('${tasksNotifier.totalCount}');
      },
      child: SomeExpensiveWidget(), // 不会重建
    ),
  );
}
```

### 2. 使用 read 进行一次性操作

```dart
// ✅ 正确：使用 read 进行一次性操作
ElevatedButton(
  onPressed: () {
    context.read<TasksNotifier>().clearAll();
  },
  child: Text('清空'),
)

// ❌ 错误：使用 watch 会导致不必要的重建
ElevatedButton(
  onPressed: () {
    context.watch<TasksNotifier>().clearAll();
  },
  child: Text('清空'),
)
```

### 3. 选择性监听

```dart
// 只监听特定属性
Widget build(BuildContext context) {
  final completedCount = context.select<TasksNotifier, int>(
    (notifier) => notifier.completedCount,
  );
  
  return Text('已完成: $completedCount');
}
```

## 组件间协作

三个 Notifier 通过 QueueService 协同工作：

```
┌──────────────────┐
│  SettingsNotifier │
└────────┬─────────┘
         │ 并发设置
         ▼
┌──────────────────┐      ┌──────────────────┐
│   TasksNotifier   │◄────►│   QueueService   │
└──────────────────┘      └────────┬─────────┘
         ▲                          │
         │                          ▼
         │                ┌──────────────────────┐
         └────────────────│ QueueStatusNotifier  │
           队列事件         └──────────────────────┘
```

## 参考文档

- [SettingsNotifier 使用示例](settings_notifier_usage.md)
- [TasksNotifier 使用示例](tasks_notifier_usage.md)
- [QueueStatusNotifier 使用示例](queue_status_notifier_usage.md)
