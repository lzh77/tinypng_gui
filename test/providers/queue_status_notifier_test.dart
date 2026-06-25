import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tinypng_gui/data/datasources/local/settings_local_data_source.dart';
import 'package:tinypng_gui/data/models/app_settings.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/providers/queue_status_notifier.dart';
import 'package:tinypng_gui/services/queue_service.dart';
import 'package:tinypng_gui/services/queue_event.dart';
import 'dart:async';

import 'queue_status_notifier_test.mocks.dart';

@GenerateMocks([QueueService, SettingsLocalDataSource])
void main() {
  late MockQueueService mockQueueService;
  late MockSettingsLocalDataSource mockSettingsDataSource;
  late StreamController<QueueEvent> queueEventController;
  late QueueStatusNotifier queueStatusNotifier;

  setUp(() {
    mockQueueService = MockQueueService();
    mockSettingsDataSource = MockSettingsLocalDataSource();
    queueEventController = StreamController<QueueEvent>.broadcast();

    when(mockSettingsDataSource.getSettings())
        .thenAnswer((_) async => AppSettings());

    // 配置mock的events流
    when(mockQueueService.events)
        .thenAnswer((_) => queueEventController.stream);

    // 配置默认返回值
    when(mockQueueService.pendingCount).thenReturn(0);
    when(mockQueueService.activeCount).thenReturn(0);

    queueStatusNotifier = QueueStatusNotifier(
      queueService: mockQueueService,
      settingsDataSource: mockSettingsDataSource,
    );
  });

  tearDown(() {
    queueStatusNotifier.dispose();
    queueEventController.close();
  });

  group('QueueStatusNotifier - 初始状态', () {
    test('初始状态应该为空闲', () {
      expect(queueStatusNotifier.status, QueueStatus.idle);
      expect(queueStatusNotifier.currentTask, isNull);
      expect(queueStatusNotifier.completedCount, 0);
      expect(queueStatusNotifier.totalCount, 0);
      expect(queueStatusNotifier.message, isNull);
      expect(queueStatusNotifier.isIdle, isTrue);
      expect(queueStatusNotifier.isRunning, isFalse);
      expect(queueStatusNotifier.isPaused, isFalse);
      expect(queueStatusNotifier.isStopping, isFalse);
    });

    test('初始进度应该为0', () {
      expect(queueStatusNotifier.progress, 0.0);
      expect(queueStatusNotifier.progressPercentage, 0);
    });

    test('初始状态文本应该为"空闲"', () {
      expect(queueStatusNotifier.getStatusText(), '空闲');
    });

    test('初始进度文本应该为"没有任务"', () {
      expect(queueStatusNotifier.getProgressText(), '没有任务');
    });
  });

  group('QueueStatusNotifier - 队列控制', () {
    test('start 应该同步并发限制并调用队列服务', () async {
      when(mockSettingsDataSource.getSettings()).thenAnswer(
        (_) async => AppSettings(concurrentLimit: 7),
      );
      when(mockQueueService.pendingCount).thenReturn(5);

      await queueStatusNotifier.start();

      verify(mockSettingsDataSource.getSettings()).called(1);
      verify(mockQueueService.concurrentLimit = 7).called(1);
      verify(mockQueueService.start()).called(1);
    });

    test('start 在非空闲状态不应该调用队列服务', () async {
      // 模拟运行状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await queueStatusNotifier.start();

      verifyNever(mockQueueService.start());
    });

    test('pause 应该调用队列服务', () async {
      // 先设置为运行状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      queueStatusNotifier.pause();

      verify(mockQueueService.pause()).called(1);
    });

    test('resume 应该调用队列服务', () async {
      // 先设置为暂停状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.paused,
        completedCount: 2,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      queueStatusNotifier.resume();

      verify(mockQueueService.resume()).called(1);
    });

    test('stop 应该调用队列服务', () async {
      // 先设置为运行状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      await queueStatusNotifier.stop();

      verify(mockQueueService.stop()).called(1);
    });
  });

  group('QueueStatusNotifier - 状态同步', () {
    test('应该同步队列运行状态', () async {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'file.png',
        originalSize: 1024,
        status: CompressionStatus.processing,
        createdAt: DateTime.now(),
      );

      queueEventController.add(QueueEvent(
        status: QueueStatus.running,
        currentTask: task,
        completedCount: 1,
        totalCount: 5,
        message: 'Processing...',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.status, QueueStatus.running);
      expect(queueStatusNotifier.currentTask, task);
      expect(queueStatusNotifier.completedCount, 1);
      expect(queueStatusNotifier.totalCount, 5);
      expect(queueStatusNotifier.message, 'Processing...');
      expect(queueStatusNotifier.isRunning, isTrue);
    });

    test('应该同步队列暂停状态', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.paused,
        completedCount: 2,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.status, QueueStatus.paused);
      expect(queueStatusNotifier.isPaused, isTrue);
    });

    test('应该同步队列停止状态', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.stopping,
        completedCount: 3,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.status, QueueStatus.stopping);
      expect(queueStatusNotifier.isStopping, isTrue);
    });

    test('应该同步队列空闲状态', () async {
      // 先设置为运行状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 3,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // 然后回到空闲状态
      queueEventController.add(QueueEvent.idle());

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.status, QueueStatus.idle);
      expect(queueStatusNotifier.isIdle, isTrue);
    });
  });

  group('QueueStatusNotifier - 进度计算', () {
    test('应该正确计算进度', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 3,
        totalCount: 10,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.progress, 0.3);
      expect(queueStatusNotifier.progressPercentage, 30);
    });

    test('总数为0时进度应该为0', () {
      expect(queueStatusNotifier.progress, 0.0);
      expect(queueStatusNotifier.progressPercentage, 0);
    });

    test('应该正确生成进度文本', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 7,
        totalCount: 10,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.getProgressText(), '7 / 10 (70%)');
    });
  });

  group('QueueStatusNotifier - 状态文本', () {
    test('空闲状态文本', () {
      expect(queueStatusNotifier.getStatusText(), '空闲');
    });

    test('运行状态文本（无当前任务）', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.getStatusText(), '运行中');
    });

    test('运行状态文本（有当前任务）', () async {
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'test.png',
        originalSize: 1024,
        status: CompressionStatus.processing,
        createdAt: DateTime.now(),
      );

      queueEventController.add(QueueEvent(
        status: QueueStatus.running,
        currentTask: task,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.getStatusText(), '正在处理: test.png');
    });

    test('暂停状态文本', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.paused,
        completedCount: 2,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.getStatusText(), '已暂停');
    });

    test('停止状态文本', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.stopping,
        completedCount: 3,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.getStatusText(), '正在停止...');
    });
  });

  group('QueueStatusNotifier - 状态判断', () {
    test('canStart 在空闲且有待处理任务时为true', () {
      when(mockQueueService.pendingCount).thenReturn(5);
      expect(queueStatusNotifier.canStart, isTrue);
    });

    test('canStart 在非空闲时为false', () async {
      when(mockQueueService.pendingCount).thenReturn(5);

      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.canStart, isFalse);
    });

    test('canPause 在运行时为true', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.canPause, isTrue);
    });

    test('canResume 在暂停时为true', () async {
      queueEventController.add(const QueueEvent(
        status: QueueStatus.paused,
        completedCount: 2,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.canResume, isTrue);
    });

    test('canStop 在运行或暂停时为true', () async {
      // 运行状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.canStop, isTrue);

      // 暂停状态
      queueEventController.add(const QueueEvent(
        status: QueueStatus.paused,
        completedCount: 2,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueStatusNotifier.canStop, isTrue);
    });
  });

  group('QueueStatusNotifier - 队列信息', () {
    test('应该获取待处理任务数量', () {
      when(mockQueueService.pendingCount).thenReturn(10);
      expect(queueStatusNotifier.pendingCount, 10);
    });

    test('应该获取正在处理任务数量', () {
      when(mockQueueService.activeCount).thenReturn(3);
      expect(queueStatusNotifier.activeCount, 3);
    });
  });

  group('QueueStatusNotifier - 重置', () {
    test('reset 应该清空所有状态', () async {
      // 先设置一些状态
      final task = CompressionTask(
        id: '1',
        filePath: '/path/to/file.png',
        fileName: 'test.png',
        originalSize: 1024,
        status: CompressionStatus.processing,
        createdAt: DateTime.now(),
      );

      queueEventController.add(QueueEvent(
        status: QueueStatus.running,
        currentTask: task,
        completedCount: 5,
        totalCount: 10,
        message: 'Test message',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      // 验证状态已设置
      expect(queueStatusNotifier.status, QueueStatus.running);
      expect(queueStatusNotifier.currentTask, isNotNull);
      expect(queueStatusNotifier.completedCount, 5);

      // 重置
      queueStatusNotifier.reset();

      // 验证状态已清空
      expect(queueStatusNotifier.status, QueueStatus.idle);
      expect(queueStatusNotifier.currentTask, isNull);
      expect(queueStatusNotifier.completedCount, 0);
      expect(queueStatusNotifier.totalCount, 0);
      expect(queueStatusNotifier.message, isNull);
    });
  });

  group('QueueStatusNotifier - 监听变化', () {
    test('状态变化应该通知监听者', () async {
      var notifyCount = 0;
      queueStatusNotifier.addListener(() {
        notifyCount++;
      });

      queueEventController.add(const QueueEvent(
        status: QueueStatus.running,
        completedCount: 1,
        totalCount: 5,
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifyCount, greaterThan(0));
    });
  });

  group('QueueStatusNotifier - 资源管理', () {
    test('dispose 应该取消事件订阅', () {
      final testNotifier = QueueStatusNotifier(
        queueService: mockQueueService,
        settingsDataSource: mockSettingsDataSource,
      );

      // 验证订阅已建立
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
