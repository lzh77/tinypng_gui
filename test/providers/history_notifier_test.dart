import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/data/models/history_record.dart';
import 'package:tinypng_gui/providers/history_notifier.dart';
import 'package:tinypng_gui/services/history_service.dart';

import 'history_notifier_test.mocks.dart';

@GenerateMocks([HistoryService])
void main() {
  late MockHistoryService mockHistoryService;
  late HistoryNotifier notifier;

  const emptyStats = HistoryStatistics(
    totalCount: 0,
    successCount: 0,
    failedCount: 0,
    totalOriginalSize: 0,
    totalCompressedSize: 0,
    totalBytesSaved: 0,
  );

  HistoryRecord makeRecord(String id) {
    return HistoryRecord(
      id: id,
      fileName: '$id.png',
      filePath: 'C:\\images\\$id.png',
      originalSize: 1000,
      compressedSize: 400,
      status: CompressionStatus.completed,
      timestamp: DateTime(2026, 6, 1, 12, 0),
    );
  }

  CompressionTask makeCompletedTask(String id) {
    return CompressionTask(
      id: id,
      filePath: r'C:\images\photo.png',
      fileName: 'photo.png',
      originalSize: 1000,
      compressedSize: 400,
      status: CompressionStatus.completed,
      createdAt: DateTime(2026, 6, 1, 10, 0),
      completedAt: DateTime(2026, 6, 1, 10, 5),
    );
  }

  setUp(() {
    mockHistoryService = MockHistoryService();
    notifier = HistoryNotifier(historyService: mockHistoryService);

    when(mockHistoryService.initialize()).thenAnswer((_) async {});
    when(mockHistoryService.getGlobalStatistics())
        .thenAnswer((_) async => emptyStats);
  });

  tearDown(() {
    notifier.dispose();
  });

  group('HistoryNotifier', () {
    test('initialize 应初始化服务并刷新列表', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => [makeRecord('r1')]);

      await notifier.initialize();

      expect(notifier.records, hasLength(1));
      expect(notifier.isLoading, isFalse);
      expect(notifier.error, isNull);
      verify(mockHistoryService.initialize()).called(1);
      verify(mockHistoryService.getHistory(limit: 50, offset: 0)).called(1);
    });

    test('refresh 失败时应设置 error', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenThrow(Exception('db error'));

      await notifier.refresh();

      expect(notifier.error, contains('加载历史记录失败'));
      expect(notifier.isLoading, isFalse);
    });

    test('refresh 满页时应标记 hasMore', () async {
      final page = List.generate(50, (i) => makeRecord('r$i'));
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => page);

      await notifier.refresh();

      expect(notifier.hasMore, isTrue);
    });

    test('refresh 不足一页时应标记 hasMore 为 false', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => [makeRecord('r1')]);

      await notifier.refresh();

      expect(notifier.hasMore, isFalse);
    });

    test('loadMore 应追加下一页记录', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => List.generate(50, (i) => makeRecord('p0-$i')));
      when(mockHistoryService.getHistory(limit: 50, offset: 50))
          .thenAnswer((_) async => [makeRecord('p1-0')]);

      await notifier.refresh();
      await notifier.loadMore();

      expect(notifier.records, hasLength(51));
      expect(notifier.records.last.id, 'p1-0');
      expect(notifier.hasMore, isFalse);
    });

    test('loadMore 在 isLoading 或 !hasMore 时不应请求', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => [makeRecord('only')]);

      await notifier.refresh();
      await notifier.loadMore();

      verifyNever(mockHistoryService.getHistory(limit: 50, offset: 50));
    });

    test('onTaskFinished 应将新记录插入列表头部', () async {
      when(mockHistoryService.saveFromTask(any)).thenAnswer((_) async {});
      when(mockHistoryService.getGlobalStatistics()).thenAnswer(
        (_) async => const HistoryStatistics(
          totalCount: 1,
          successCount: 1,
          failedCount: 0,
          totalOriginalSize: 1000,
          totalCompressedSize: 400,
          totalBytesSaved: 600,
        ),
      );

      await notifier.onTaskFinished(makeCompletedTask('new-task'));

      expect(notifier.records.first.id, 'new-task');
      expect(notifier.statistics?.totalCount, 1);
      verify(mockHistoryService.saveFromTask(any)).called(1);
    });

    test('onTaskFinished 已存在相同 id 时不应重复插入', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => [makeRecord('dup')]);
      when(mockHistoryService.saveFromTask(any)).thenAnswer((_) async {});

      await notifier.refresh();
      await notifier.onTaskFinished(makeCompletedTask('dup'));

      expect(notifier.records, hasLength(1));
    });

    test('deleteRecord 应从列表移除并刷新统计', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => [makeRecord('del')]);
      when(mockHistoryService.deleteRecord('del')).thenAnswer((_) async {});
      when(mockHistoryService.getGlobalStatistics())
          .thenAnswer((_) async => emptyStats);

      await notifier.refresh();
      await notifier.deleteRecord('del');

      expect(notifier.records, isEmpty);
      expect(notifier.error, isNull);
      verify(mockHistoryService.deleteRecord('del')).called(1);
    });

    test('deleteRecord 失败时应设置 error', () async {
      when(mockHistoryService.deleteRecord('x'))
          .thenThrow(Exception('delete failed'));

      await notifier.deleteRecord('x');

      expect(notifier.error, contains('删除记录失败'));
    });

    test('clearAll 应清空列表并重置统计', () async {
      when(mockHistoryService.getHistory(limit: 50, offset: 0))
          .thenAnswer((_) async => [makeRecord('a')]);
      when(mockHistoryService.clearAll()).thenAnswer((_) async {});

      await notifier.refresh();
      await notifier.clearAll();

      expect(notifier.records, isEmpty);
      expect(notifier.hasMore, isFalse);
      expect(notifier.statistics, equals(emptyStats));
      verify(mockHistoryService.clearAll()).called(1);
    });

    test('clearAll 失败时应设置 error', () async {
      when(mockHistoryService.clearAll())
          .thenThrow(Exception('clear failed'));

      await notifier.clearAll();

      expect(notifier.error, contains('清空历史失败'));
    });
  });
}
