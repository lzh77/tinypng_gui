import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tinypng_gui/services/queue_service.dart';
import 'package:tinypng_gui/services/compression_service.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/services/queue_event.dart';

import 'queue_service_test.mocks.dart';

@GenerateMocks([CompressionService])
void main() {
  late QueueService queueService;
  late MockCompressionService mockCompressionService;

  setUp(() {
    mockCompressionService = MockCompressionService();
    queueService = QueueService(compressionService: mockCompressionService);
  });

  tearDown(() {
    queueService.dispose();
  });

  group('QueueService Basic Tests', () {
    test('初始状态应为空闲', () {
      expect(queueService.status, QueueStatus.idle);
      expect(queueService.pendingCount, 0);
      expect(queueService.activeCount, 0);
    });

    test('添加任务后状态应更新', () {
      final task = CompressionTask(
        id: '1',
        fileName: 'test.png',
        filePath: 'path/test.png',
        originalSize: 100,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      queueService.addTask(task);

      expect(queueService.pendingCount, 1);
      // 注意：只有调用 start() 后才会变为 running
      expect(queueService.status, QueueStatus.idle);

      // 启动后状态应变为 running
      queueService.start();
      expect(queueService.status, QueueStatus.running);
    });
  });

  group('QueueService Execution Tests', () {
    test('调用 start 应开始处理任务', () async {
      final task = CompressionTask(
        id: '1',
        fileName: 'test.png',
        filePath: 'path/test.png',
        originalSize: 100,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
      );

      final completedTask = task.copyWith(status: CompressionStatus.completed);

      when(mockCompressionService.compressTask(any))
          .thenAnswer((_) async => completedTask);

      queueService.addTask(task);
      queueService.start();

      // 等待任务完成
      await Future.delayed(const Duration(milliseconds: 200));

      verify(mockCompressionService.compressTask(any)).called(1);
      expect(queueService.status, QueueStatus.idle);
      expect(queueService.activeCount, 0);
    });

    test('并发控制测试', () async {
      queueService.concurrentLimit = 2;

      final tasks = List.generate(
          5,
          (i) => CompressionTask(
                id: '$i',
                fileName: 'test$i.png',
                filePath: 'path/test$i.png',
                originalSize: 100,
                status: CompressionStatus.pending,
                createdAt: DateTime.now(),
              ));

      // 模拟耗时任务
      when(mockCompressionService.compressTask(any)).thenAnswer((invocation) async {
        await Future.delayed(const Duration(milliseconds: 100));
        final t = invocation.positionalArguments[0] as CompressionTask;
        return t.copyWith(status: CompressionStatus.completed);
      });

      queueService.addTasks(tasks);
      queueService.start();

      // 给点时间让前两个任务进入处理中
      await Future.delayed(const Duration(milliseconds: 50));

      expect(queueService.activeCount, 2);
      expect(queueService.pendingCount, 3);

      // 等待全部完成
      await Future.delayed(const Duration(milliseconds: 600));
      expect(queueService.pendingCount, 0);
      expect(queueService.activeCount, 0);
      expect(queueService.status, QueueStatus.idle);
    });
  });
}
