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
  /// 会自动处理 API Key 轮换和文件保存
  Future<CompressionTask> compressTask(CompressionTask task) async {
    LoggerService.i('开始处理任务: ${task.fileName} (ID: ${task.id})');

    // 确保 ApiKeyService 已初始化
    await _apiKeyService.initialize();

    // 获取当前设置
    final settings = await _settingsDataSource.getSettings();

    try {
      // 执行压缩（带 Key 轮换逻辑）
      final resultData = await _compressWithKeyRotation(task, settings);

      // 更新配额统计
      if (resultData.monthlyCompressionCount != null) {
        final currentKey = _apiKeyService.getAvailableKey();
        if (currentKey != null) {
          await _apiKeyService.updateKeyUsage(
              currentKey.key, resultData.monthlyCompressionCount!);
        }
      }

      // 确定并生成输出路径
      final outputPath = _fileService.getOutputPath(
        task.filePath,
        outputDir: settings.outputDirectory,
        overwrite: settings.overwriteOriginal,
        suffix: settings.fileNameSuffix,
      );

      // 保存文件
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
    } catch (e, stackTrace) {
      LoggerService.e('压缩任务失败: ${task.fileName}', e, stackTrace);
      return task.copyWith(
        status: CompressionStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 带 Key 轮换逻辑的压缩实现
  Future<dynamic> _compressWithKeyRotation(
      CompressionTask task, AppSettings settings) async {
    final file = File(task.filePath);

    try {
      // 确保至少有一个 Key 设置到了 API
      if (_apiKeyService.getAvailableKey() == null) {
        throw Exception('没有可用的 API Key');
      }

      return await _api.compressImage(file);
    } on QuotaExceededException {
      // 如果配额用完且开启了自动轮换
      if (settings.autoRotateKeys) {
        LoggerService.w('当前 API Key 配额已满，尝试轮换 Key...');

        // 标记当前 Key 为配额已满
        final currentKey = _apiKeyService.getAvailableKey();
        if (currentKey != null) {
          await _apiKeyService.updateApiKey(currentKey.id,
              status: ApiKeyStatus.quotaFull);
        }

        final nextKey = _apiKeyService.rotateToNextKey();
        if (nextKey != null) {
          // 重新尝试压缩
          return await _api.compressImage(file);
        }
      }
      rethrow;
    }
  }
}
