import 'dart:async';
import 'dart:io';
import '../data/models/compression_task.dart';
import '../data/models/api_key_info.dart';
import '../data/models/app_settings.dart';
import '../data/datasources/remote/tinypng_api.dart';
import '../data/datasources/local/settings_local_data_source.dart';
import 'api_key_service.dart';
import 'file_service.dart';
import 'logger_service.dart';

/// 压缩核心服务
/// 负责协调 API Key 轮换、API 调用和文件保存
class CompressionService {
  final TinyPngApi _api;
  final ApiKeyService _apiKeyService;
  final SettingsLocalDataSource _settingsDataSource;
  final FileService _fileService;

  CompressionService({
    required TinyPngApi api,
    required ApiKeyService apiKeyService,
    required SettingsLocalDataSource settingsDataSource,
    required FileService fileService,
  })  : _api = api,
        _apiKeyService = apiKeyService,
        _settingsDataSource = settingsDataSource,
        _fileService = fileService;

  /// 压缩单个任务
  /// 会自动处理 API Key 轮换、失败重试和文件保存
  Future<CompressionTask> compressTask(CompressionTask task) async {
    LoggerService.i('开始处理任务: ${task.fileName} (ID: ${task.id})');

    await _apiKeyService.initialize();
    final settings = await _settingsDataSource.getSettings();
    final int maxAttempts = settings.retryCount + 1;

    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _executeCompression(task, settings);
      } catch (e, stackTrace) {
        lastError = e;
        lastStackTrace = stackTrace;

        final bool canRetry = attempt < maxAttempts && _isRetryable(e);
        if (!canRetry) break;

        LoggerService.w(
          '压缩任务失败，准备重试 ($attempt/${settings.retryCount}): ${task.fileName}',
        );
      }
    }

    LoggerService.e('压缩任务失败: ${task.fileName}', lastError, lastStackTrace);
    return task.copyWith(
      status: CompressionStatus.failed,
      errorMessage: lastError.toString(),
    );
  }

  Future<CompressionTask> _executeCompression(
    CompressionTask task,
    AppSettings settings,
  ) async {
    final resultData = await _compressWithKeyRotation(task, settings);

    if (resultData.monthlyCompressionCount != null) {
      final currentKey = _apiKeyService.getAvailableKey();
      if (currentKey != null) {
        await _apiKeyService.updateKeyUsage(
          currentKey.key,
          resultData.monthlyCompressionCount!,
        );
      }
    }

    final outputPath = _fileService.getOutputPath(
      task.filePath,
      outputDir: settings.outputDirectory,
      overwrite: settings.overwriteOriginal,
      suffix: settings.fileNameSuffix,
    );

    await _fileService.ensureDirectoryExists(outputPath);
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(resultData.data);

    LoggerService.i('任务完成: ${task.fileName} -> $outputPath');

    return task.copyWith(
      status: CompressionStatus.completed,
      compressedSize: resultData.compressedSize,
      compressionRatio: resultData.compressedSize / resultData.originalSize,
      completedAt: DateTime.now(),
    );
  }

  /// 带 Key 轮换逻辑的压缩实现
  Future<dynamic> _compressWithKeyRotation(
    CompressionTask task,
    AppSettings settings,
  ) async {
    final file = File(task.filePath);

    if (_apiKeyService.getAvailableKey() == null) {
      throw Exception('没有可用的 API Key');
    }

    try {
      return await _api.compressImage(file);
    } on QuotaExceededException {
      if (settings.autoRotateKeys) {
        LoggerService.w('当前 API Key 配额已满，尝试轮换 Key...');

        final currentKey = _apiKeyService.getAvailableKey();
        if (currentKey != null) {
          await _apiKeyService.updateApiKey(
            currentKey.id,
            status: ApiKeyStatus.quotaFull,
          );
        }

        final nextKey = _apiKeyService.rotateToNextKey();
        if (nextKey != null) {
          return await _api.compressImage(file);
        }
      }
      rethrow;
    }
  }

  /// 判断错误是否适合自动重试
  bool _isRetryable(Object error) {
    if (error is NetworkException) return true;
    if (error is ApiRequestException) {
      final statusCode = error.statusCode;
      return statusCode == null || statusCode >= 500;
    }
    return false;
  }
}
