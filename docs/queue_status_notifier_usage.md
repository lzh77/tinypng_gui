# QueueStatusNotifier 使用示例

## 概述

`QueueStatusNotifier` 是一个用于管理队列整体状态的 `ChangeNotifier`，它负责：
- 管理队列的运行状态（空闲/运行/暂停/停止）
- 跟踪当前正在处理的任务
- 提供进度信息和统计数据
- 提供队列控制操作（开始/暂停/恢复/停止）
- 与 `QueueService` 集成，自动同步状态

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
        home: HomeScreen(),
      ),
    );
  }
}
```

## 基本使用

### 1. 队列控制按钮

```dart
class QueueControlButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final queueStatus = context.watch<QueueStatusNotifier>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 开始按钮
        ElevatedButton.icon(
          onPressed: queueStatus.canStart
              ? () => queueStatus.start()
              : null,
          icon: Icon(Icons.play_arrow),
          label: Text('开始'),
        ),
        SizedBox(width: 8),
        
        // 暂停按钮
        ElevatedButton.icon(
          onPressed: queueStatus.canPause
              ? () => queueStatus.pause()
              : null,
          icon: Icon(Icons.pause),
          label: Text('暂停'),
        ),
        SizedBox(width: 8),
        
        // 恢复按钮
        ElevatedButton.icon(
          onPressed: queueStatus.canResume
              ? () => queueStatus.resume()
              : null,
          icon: Icon(Icons.play_arrow),
          label: Text('恢复'),
        ),
        SizedBox(width: 8),
        
        // 停止按钮
        ElevatedButton.icon(
          onPressed: queueStatus.canStop
              ? () => queueStatus.stop()
              : null,
          icon: Icon(Icons.stop),
          label: Text('停止'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
        ),
      ],
    );
  }
}
```

### 2. 显示队列状态

```dart
class QueueStatusDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final queueStatus = context.watch<QueueStatusNotifier>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '队列状态',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            
            // 状态指示器
            Row(
              children: [
                _buildStatusIndicator(queueStatus.status),
                SizedBox(width: 8),
                Text(
                  queueStatus.getStatusText(),
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 进度信息
            Text('进度: ${queueStatus.getProgressText()}'),
            SizedBox(height: 8),
            
            // 进度条
            LinearProgressIndicator(
              value: queueStatus.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getProgressColor(queueStatus.status),
              ),
            ),
            
            SizedBox(height: 16),
            
            // 详细统计
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('待处理', queueStatus.pendingCount),
                _buildStatItem('处理中', queueStatus.activeCount),
                _buildStatItem('已完成', queueStatus.completedCount),
              ],
            ),
          ],
        ),
      ),
    );
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
    
    return Icon(icon, color: color, size: 24);
  }

  Color _getProgressColor(QueueStatus status) {
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

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
```

### 3. 当前任务显示

```dart
class CurrentTaskDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final queueStatus = context.watch<QueueStatusNotifier>();
    final currentTask = queueStatus.currentTask;

    if (currentTask == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              queueStatus.isRunning ? '正在准备任务...' : '没有正在处理的任务',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前任务',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircularProgressIndicator(),
              title: Text(currentTask.fileName),
              subtitle: Text(currentTask.filePath),
              trailing: Text(
                _formatBytes(currentTask.originalSize),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
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

### 4. 智能控制按钮（根据状态自动切换）

```dart
class SmartQueueButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final queueStatus = context.watch<QueueStatusNotifier>();

    // 根据当前状态决定显示哪个按钮
    if (queueStatus.isIdle) {
      return ElevatedButton.icon(
        onPressed: queueStatus.canStart ? () => queueStatus.start() : null,
        icon: Icon(Icons.play_arrow),
        label: Text('开始压缩'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      );
    } else if (queueStatus.isRunning) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            onPressed: () => queueStatus.stop(),
            icon: Icon(Icons.stop),
            label: Text('停止'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      );
    } else if (queueStatus.isPaused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            onPressed: () => queueStatus.stop(),
            icon: Icon(Icons.stop),
            label: Text('停止'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      );
    } else {
      // Stopping
      return ElevatedButton.icon(
        onPressed: null,
        icon: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('正在停止...'),
      );
    }
  }
}
```

### 5. 使用状态判断方法

```dart
class AdvancedQueueControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final queueStatus = context.watch<QueueStatusNotifier>();

    return Column(
      children: [
        // 只有在可以开始时显示
        if (queueStatus.canStart)
          ElevatedButton(
            onPressed: () => queueStatus.start(),
            child: Text('开始处理队列'),
          ),
        
        // 只有在可以暂停时显示
        if (queueStatus.canPause)
          ElevatedButton(
            onPressed: () => queueStatus.pause(),
            child: Text('暂停处理'),
          ),
        
        // 只有在可以恢复时显示
        if (queueStatus.canResume)
          ElevatedButton(
            onPressed: () => queueStatus.resume(),
            child: Text('恢复处理'),
          ),
        
        // 只有在可以停止时显示
        if (queueStatus.canStop)
          ElevatedButton(
            onPressed: () async {
              final confirmed = await _confirmStop(context);
              if (confirmed) {
                await queueStatus.stop();
              }
            },
            child: Text('停止处理'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
      ],
    );
  }

  Future<bool> _confirmStop(BuildContext context) async {
    return await showDialog<bool>(
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
    ) ?? false;
  }
}
```

### 6. 进度通知

```dart
class QueueProgressNotification extends StatefulWidget {
  @override
  _QueueProgressNotificationState createState() =>
      _QueueProgressNotificationState();
}

class _QueueProgressNotificationState extends State<QueueProgressNotification> {
  @override
  Widget build(BuildContext context) {
    final queueStatus = context.watch<QueueStatusNotifier>();

    // 当队列完成时显示通知
    if (queueStatus.isIdle && 
        queueStatus.completedCount > 0 && 
        queueStatus.completedCount == queueStatus.totalCount) {
      
      // 在下一帧显示Snackbar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 所有任务已完成！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: '查看',
              textColor: Colors.white,
              onPressed: () {
                // 跳转到历史记录页面
              },
            ),
          ),
        );
        
        // 重置状态以避免重复显示
        queueStatus.reset();
      });
    }

    return SizedBox.shrink();
  }
}
```

## 状态判断方法

QueueStatusNotifier 提供了多个便捷的状态判断方法：

```dart
// 状态检查
queueStatus.isIdle       // 是否空闲
queueStatus.isRunning    // 是否运行中
queueStatus.isPaused     // 是否已暂停
queueStatus.isStopping   // 是否正在停止

// 操作权限检查
queueStatus.canStart     // 是否可以开始（空闲且有待处理任务）
queueStatus.canPause     // 是否可以暂停（正在运行）
queueStatus.canResume    // 是否可以恢复（已暂停）
queueStatus.canStop      // 是否可以停止（运行或暂停）
```

## 自动队列同步

`QueueStatusNotifier` 会自动监听 `QueueService` 的事件流，当队列状态发生变化时，会自动更新本地状态并通知UI刷新。

```dart
// QueueStatusNotifier 内部实现
void _handleQueueEvent(QueueEvent event) {
  _status = event.status;
  _currentTask = event.currentTask;
  _completedCount = event.completedCount;
  _totalCount = event.totalCount;
  _message = event.message;
  
  notifyListeners(); // 自动通知 UI 更新
}
```

## 注意事项

1. **状态一致性**: QueueStatusNotifier 的状态完全来自 QueueService，确保状态同步。

2. **操作验证**: 控制操作（start/pause/resume/stop）会先检查当前状态，只有在允许的情况下才会执行。

3. **资源清理**: QueueStatusNotifier 会在 `dispose` 时自动取消队列事件订阅。

4. **进度计算**: 进度值和百分比会自动根据 completedCount 和 totalCount 计算。

5. **重置功能**: 使用 `reset()` 方法可以清空所有统计信息，通常在显示完成通知后调用。

## 完整示例

参见项目中的 `HomeScreen` 实现，它展示了如何完整地使用 `QueueStatusNotifier` 来构建功能完善的队列控制界面。
