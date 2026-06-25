import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tinypng_gui/data/datasources/local/settings_local_data_source.dart';
import 'package:tinypng_gui/data/datasources/remote/tinypng_api.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';
import 'package:tinypng_gui/data/models/app_settings.dart';
import 'package:tinypng_gui/data/models/compression_result_data.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/services/api_key_service.dart';
import 'package:tinypng_gui/services/compression_service.dart';
import 'package:tinypng_gui/services/file_service.dart';

import 'compression_service_test.mocks.dart';

@GenerateMocks([
  TinyPngApi,
  ApiKeyService,
  SettingsLocalDataSource,
  FileService,
])
void main() {
  late MockTinyPngApi mockApi;
  late MockApiKeyService mockApiKeyService;
  late MockSettingsLocalDataSource mockSettingsDataSource;
  late MockFileService mockFileService;
  late CompressionService compressionService;
  late CompressionTask task;
  late File tempFile;

  setUp(() async {
    mockApi = MockTinyPngApi();
    mockApiKeyService = MockApiKeyService();
    mockSettingsDataSource = MockSettingsLocalDataSource();
    mockFileService = MockFileService();

    compressionService = CompressionService(
      api: mockApi,
      apiKeyService: mockApiKeyService,
      settingsDataSource: mockSettingsDataSource,
      fileService: mockFileService,
    );

    tempFile = File(
      '${Directory.systemTemp.path}/compression_service_test_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await tempFile.writeAsBytes([0, 1, 2, 3]);

    task = CompressionTask(
      id: 'task-1',
      filePath: tempFile.path,
      fileName: 'test.png',
      originalSize: 4,
      status: CompressionStatus.pending,
      createdAt: DateTime.now(),
    );

    when(mockApiKeyService.initialize()).thenAnswer((_) async {});
    when(mockApiKeyService.getAvailableKey()).thenReturn(null);
    when(mockSettingsDataSource.getSettings()).thenAnswer(
      (_) async => AppSettings(retryCount: 2),
    );
    when(mockFileService.getOutputPath(any,
            outputDir: anyNamed('outputDir'),
            overwrite: anyNamed('overwrite'),
            suffix: anyNamed('suffix')))
        .thenReturn('${Directory.systemTemp.path}/out.png');
    when(mockFileService.ensureDirectoryExists(any))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  group('CompressionService retry', () {
    test('网络错误应按 retryCount 重试后成功', () async {
      final resultData = CompressionResultData(
        data: Uint8List.fromList([1, 2]),
        originalSize: 4,
        compressedSize: 2,
        mimeType: 'image/png',
      );

      when(mockApiKeyService.getAvailableKey()).thenReturn(
        ApiKeyInfo(key: 'test-key', alias: 'Test'),
      );
      var callCount = 0;
      when(mockApi.compressImage(any)).thenAnswer((_) async {
        callCount++;
        if (callCount <= 2) {
          throw NetworkException('timeout');
        }
        return resultData;
      });

      final updatedTask = await compressionService.compressTask(task);

      expect(updatedTask.status, CompressionStatus.completed);
      verify(mockApi.compressImage(any)).called(3);
    });

    test('不可重试错误不应重试', () async {
      when(mockApiKeyService.getAvailableKey()).thenReturn(
        ApiKeyInfo(key: 'bad-key', alias: 'Bad'),
      );
      when(mockApi.compressImage(any))
          .thenThrow(ApiKeyInvalidException());

      final updatedTask = await compressionService.compressTask(task);

      expect(updatedTask.status, CompressionStatus.failed);
      verify(mockApi.compressImage(any)).called(1);
    });

    test('5xx 错误应按 retryCount 重试', () async {
      final resultData = CompressionResultData(
        data: Uint8List.fromList([1, 2]),
        originalSize: 4,
        compressedSize: 2,
        mimeType: 'image/png',
      );

      when(mockApiKeyService.getAvailableKey()).thenReturn(
        ApiKeyInfo(key: 'test-key', alias: 'Test'),
      );

      var callCount = 0;
      when(mockApi.compressImage(any)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw ApiRequestException('server error', 503);
        }
        return resultData;
      });

      final updatedTask = await compressionService.compressTask(task);

      expect(updatedTask.status, CompressionStatus.completed);
      expect(callCount, 2);
    });
  });
}
