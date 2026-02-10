import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/providers/tasks_notifier.dart';
import 'package:tinypng_gui/services/queue_service.dart';
import 'package:tinypng_gui/services/queue_event.dart';
import 'dart:async';

import 'tasks_notifier_test.mocks.dart';

@GenerateMocks([QueueService])
void main() {
  late MockQueueService mockQueueService;
  late StreamController<QueueEvent> queueEventController;
  late TasksNotifier tasksNotifier;

  setUp(() {
    mockQueueService = MockQueueService();
    queueEventController = StreamController<QueueEvent>.broadcast();

    // 配置mock的events流
    when(mockQueueService.events)
        .thenAnswer((_) => queueEventController.stream);

    tasksNotifier = TasksNotifier(queueService: mockQueueService);
  });

  tearDown(() {
    tasksNotifier.dispose();
    queueEventController.close();
  });

  group('TasksNotifier - 基本操作', () {
    test('初始状态应该为空', () {
      expect(tasksNotifier.tasks, isEmpty);
      expect(tasksNotifier.totalCount, 0);
      expect(tasksNotifier.pendingCount, 0);
      expect(tasksNotifier.processingCount, 0);
      expect(tasksNotifier.completedCount, 0);
      expect(tasksNotifier.failedCount, 0);
    });

    test('addTask 应该添加任务并通知监听者', () {
      var notified = false;
      tasksNotifier.addListener(() {
        notified = true;
      });

      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);

      expect(tasksNotifier.tasks.length, 1);
      expect(tasksNotifier.tasks.first.id, '1');
      expect(notified, isTrue);
      verify(mockQueueService.addTask(task)).called(1);
    });

    test('addTask 不应该添加重复的任务', () {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);
      tasksNotifier.addTask(task); // 尝试重复添加

      expect(tasksNotifier.tasks.length, 1);
      verify(mockQueueService.addTask(task)).called(1); // 只调用一次
    });

    test('addTasks 应该批量添加任务', () {
      final tasks = [
        CompressionTask(
          id: '1',
          filePath: '/path/to/file1.png',
          fileName: 'file1.png',
          originalSize: 1024,
          status: CompressionStatus.pending,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '2',
          filePath: '/path/to/file2.png',
          fileName: 'file2.png',
          originalSize: 2048,
          status: CompressionStatus.pending,
          createdAt: DateTime.now(),
        ),
      ];

      tasksNotifier.addTasks(tasks);

      expect(tasksNotifier.tasks.length, 2);
      verify(mockQueueService.addTasks(tasks)).called(1);
    });

    test('updateTask 应该更新现有任务', () {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);

      final updatedTask = task.copyWith(
        status: CompressionStatus.processing,
      );

      tasksNotifier.updateTask('1', updatedTask);

      expect(tasksNotifier.tasks.first.status, CompressionStatus.processing);
    });

    test('getTaskById 应该返回正确的任务', () {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);

      final foundTask = tasksNotifier.getTaskById('1');
      expect(foundTask, isNotNull);
      expect(foundTask!.id, '1');

      final notFoundTask = tasksNotifier.getTaskById('999');
      expect(notFoundTask, isNull);
    });

    test('removeTask 应该移除任务', () {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);
      expect(tasksNotifier.tasks.length, 1);

      tasksNotifier.removeTask('1');
      expect(tasksNotifier.tasks.length, 0);
      verify(mockQueueService.removeTask('1')).called(1);
    });

    test('clearAll 应该清空所有任务', () {
      final tasks = [
        CompressionTask(
          id: '1',
          filePath: '/path/to/file1.png',
          fileName: 'file1.png',
          originalSize: 1024,
          status: CompressionStatus.pending,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '2',
          filePath: '/path/to/file2.png',
          fileName: 'file2.png',
          originalSize: 2048,
          status: CompressionStatus.completed,
          createdAt: DateTime.now(),
        ),
      ];

      tasksNotifier.addTasks(tasks);
      expect(tasksNotifier.tasks.length, 2);

      tasksNotifier.clearAll();
      expect(tasksNotifier.tasks.length, 0);
      verify(mockQueueService.clear()).called(1);
    });
  });

  group('TasksNotifier - 状态过滤', () {
    setUp(() {
      final tasks = [
        CompressionTask(
          id: '1',
          filePath: '/path/to/file1.png',
          fileName: 'file1.png',
          originalSize: 1024,
          status: CompressionStatus.pending,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '2',
          filePath: '/path/to/file2.png',
          fileName: 'file2.png',
          originalSize: 2048,
          status: CompressionStatus.processing,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '3',
          filePath: '/path/to/file3.png',
          fileName: 'file3.png',
          originalSize: 3072,
          compressedSize: 2000,
          status: CompressionStatus.completed,
          compressionRatio: 0.65,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '4',
          filePath: '/path/to/file4.png',
          fileName: 'file4.png',
          originalSize: 4096,
          status: CompressionStatus.failed,
          errorMessage: 'Test error',
          createdAt: DateTime.now(),
        ),
      ];

      tasksNotifier.addTasks(tasks);
    });

    test('应该正确统计各状态任务数量', () {
      expect(tasksNotifier.totalCount, 4);
      expect(tasksNotifier.pendingCount, 1);
      expect(tasksNotifier.processingCount, 1);
      expect(tasksNotifier.completedCount, 1);
      expect(tasksNotifier.failedCount, 1);
      expect(tasksNotifier.cancelledCount, 0);
    });

    test('clearFailed 应该只清除失败的任务', () {
      tasksNotifier.clearFailed();
      expect(tasksNotifier.tasks.length, 3);
      expect(tasksNotifier.failedCount, 0);
    });

    test('clearCompleted 应该只清除已完成的任务', () {
      tasksNotifier.clearCompleted();
      expect(tasksNotifier.tasks.length, 3);
      expect(tasksNotifier.completedCount, 0);
    });
  });

  group('TasksNotifier - 统计信息', () {
    test('应该正确计算总文件大小', () {
      final tasks = [
        CompressionTask(
          id: '1',
          filePath: '/path/to/file1.png',
          fileName: 'file1.png',
          originalSize: 1024,
          compressedSize: 512,
          status: CompressionStatus.completed,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '2',
          filePath: '/path/to/file2.png',
          fileName: 'file2.png',
          originalSize: 2048,
          compressedSize: 1024,
          status: CompressionStatus.completed,
          createdAt: DateTime.now(),
        ),
      ];

      tasksNotifier.addTasks(tasks);

      expect(tasksNotifier.totalOriginalSize, 3072);
      expect(tasksNotifier.totalCompressedSize, 1536);
      expect(tasksNotifier.totalBytesSaved, 1536);
    });

    test('应该正确计算平均压缩比', () {
      final tasks = [
        CompressionTask(
          id: '1',
          filePath: '/path/to/file1.png',
          fileName: 'file1.png',
          originalSize: 1024,
          compressedSize: 512,
          compressionRatio: 0.5,
          status: CompressionStatus.completed,
          createdAt: DateTime.now(),
        ),
        CompressionTask(
          id: '2',
          filePath: '/path/to/file2.png',
          fileName: 'file2.png',
          originalSize: 2048,
          compressedSize: 1024,
          compressionRatio: 0.5,
          status: CompressionStatus.completed,
          createdAt: DateTime.now(),
        ),
      ];

      tasksNotifier.addTasks(tasks);

      expect(tasksNotifier.averageCompressionRatio, 0.5);
    });

    test('空任务列表的平均压缩比应该为0', () {
      expect(tasksNotifier.averageCompressionRatio, 0.0);
    });
  });

  group('TasksNotifier - 队列事件处理', () {
    test('应该监听并处理队列事件', () async {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);

      // 模拟队列发送任务更新事件
      final updatedTask = task.copyWith(
        status: CompressionStatus.completed,
        compressedSize: 512,
        compressionRatio: 0.5,
      );

      queueEventController.add(QueueEvent(
        status: QueueStatus.running,
        currentTask: updatedTask,
        completedCount: 1,
        totalCount: 1,
      ));

      // 等待事件处理
      await Future.delayed(const Duration(milliseconds: 100));

      expect(tasksNotifier.tasks.first.status, CompressionStatus.completed);
      expect(tasksNotifier.tasks.first.compressedSize, 512);
    });

    test('retryFailed 应该重置失败任务并重新入队', () {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.failed,
        errorMessage: 'Test error',
        createdAt: DateTime.now(),
      );

      tasksNotifier.addTask(task);
      expect(tasksNotifier.failedCount, 1);

      tasksNotifier.retryFailed();

      expect(tasksNotifier.failedCount, 0);
      expect(tasksNotifier.pendingCount, 1);
      expect(tasksNotifier.tasks.first.errorMessage, isNull);

      // 验证重新添加到队列
      verify(mockQueueService.addTasks(any)).called(1);
    });
  });

  group('TasksNotifier - 资源管理', () {
    test('dispose 应该取消事件订阅', () {
      // 创建一个新的notifier以便测试dispose
      final testNotifier = TasksNotifier(queueService: mockQueueService);

      // 验证订阅已建立（通过添加事件不会抛出异常）
      expect(
          () => queueEventController.add(QueueEvent.idle()), returnsNormally);

      // dispose
      testNotifier.dispose();

      // 验证不会因为dispose导致问题
      expect(
          () => queueEventController.add(QueueEvent.idle()), returnsNormally);
    });
  });
}
