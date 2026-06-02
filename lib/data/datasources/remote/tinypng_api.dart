import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:tinypng_gui/data/models/compression_result_data.dart';
import 'package:tinypng_gui/services/logger_service.dart';

/// 调整选项
class ResizeOptions {
  final String method; // scale, fit, cover, thumb
  final int? width;
  final int? height;

  ResizeOptions({required this.method, this.width, this.height});
}

/// 自定义异常基类
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  ApiException(this.message, [this.statusCode, this.details]);
}

/// API异常
class ApiRequestException extends ApiException {
  ApiRequestException(super.message, [super.statusCode, super.details]);
}

/// API Key无效异常
class ApiKeyInvalidException extends ApiException {
  ApiKeyInvalidException([String? details])
      : super('API Key 无效或未授权', 401, details);
}

/// 配额超出异常
class QuotaExceededException extends ApiException {
  QuotaExceededException([String? details]) : super('API 配额已用完', 429, details);
}

/// 网络异常
class NetworkException extends ApiException {
  NetworkException(String message, [String? details])
      : super(message, null, details);
}

/// TinyPNG API 服务类
class TinyPngApi {
  final Dio _dio;
  String? _currentApiKey;

  static const String _baseUrl = 'https://api.tinify.com';

  // 构造函数
  TinyPngApi({String? apiKey, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 300); // 压缩可能耗时

    if (apiKey != null) {
      setApiKey(apiKey);
    }
  }

  // 设置/更新 API Key
  void setApiKey(String apiKey) {
    LoggerService.d('正在更新 API Key: ${apiKey.substring(0, 4)}...');
    _currentApiKey = apiKey;
    // 设置 Basic Auth 头
    final basicAuth = 'api:$apiKey';
    final encoded = base64Encode(utf8.encode(basicAuth));
    _dio.options.headers['Authorization'] = 'Basic $encoded';
  }

  /// 完整的压缩流程：上传 -> 压缩 -> (可选Resize/Convert) -> 下载
  /// 返回压缩结果和最新的配额使用量
  Future<CompressionResultData> compressImage(
    File file, {
    ResizeOptions? resize,
    String? targetFormat, // 'image/webp', etc.
  }) async {
    if (_currentApiKey == null) {
      LoggerService.e('压缩失败：未设置 API Key');
      throw ApiRequestException('未设置 API Key');
    }

    LoggerService.i('开始压缩图片: ${file.path}');

    try {
      // 1. 上传图片进行压缩
      final response = await _dio.post(
        '/shrink',
        data: await file.readAsBytes(),
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'application/octet-stream',
          },
        ),
      );

      LoggerService.d('图片上传成功，正在解析响应数据...');

      // 2. 从响应头获取配额信息
      final compressionCount = _parseCompressionCount(response.headers);
      LoggerService.i('当前已使用压缩配额: $compressionCount');

      // 3. 解析响应体获取下载 URL
      var outputUrl = response.data['output']['url'] as String;
      var compressedSize = response.data['output']['size'] as int;
      var type = response.data['output']['type'] as String;

      // 4. 处理可选的 Resize 和 Convert (API 要求对 outputUrl 发起 POST 请求)
      if (resize != null || targetFormat != null) {
        LoggerService.i(
            '检测到额外处理请求: resize=${resize?.method}, format=$targetFormat');
        final Map<String, dynamic> processData = {};

        if (resize != null) {
          processData['resize'] = {
            'method': resize.method,
            if (resize.width != null) 'width': resize.width,
            if (resize.height != null) 'height': resize.height,
          };
        }

        if (targetFormat != null) {
          processData['convert'] = {'type': targetFormat};
        }

        final processResponse = await _dio.post(
          outputUrl,
          data: jsonEncode(processData),
          options: Options(
            headers: {
              Headers.contentTypeHeader: 'application/json',
            },
          ),
        );

        LoggerService.d('图片后处理成功(Resize/Convert)');

        // 更新下载信息 (Location 包含处理后的图片 URL)
        outputUrl = processResponse.headers.value('Location') ?? outputUrl;
        if (processResponse.data != null &&
            processResponse.data['output'] != null) {
          compressedSize =
              processResponse.data['output']['size'] ?? compressedSize;
          type = processResponse.data['output']['type'] ?? type;
        }
      }

      // 5. 下载最终结果
      LoggerService.i('正在下载处理后的图片从: $outputUrl');
      final compressedBytes = await _downloadImage(outputUrl);
      LoggerService.i(
          '全流程完成！原始大小: ${response.data['input']['size']}, 压缩后: $compressedSize');

      return CompressionResultData(
        originalSize: response.data['input']['size'],
        compressedSize: compressedSize,
        mimeType: type,
        data: compressedBytes,
        monthlyCompressionCount: compressionCount,
      );
    } on DioException catch (e) {
      LoggerService.e('网络请求异常', e);
      throw _handleDioError(e);
    }
  }

  /// 下载压缩后的图片
  Future<Uint8List> _downloadImage(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  /// 验证 API Key 是否有效
  Future<bool> validateApiKey(String apiKey) async {
    LoggerService.i('正在验证 API Key 有效性...');
    try {
      final oldKey = _currentApiKey;
      setApiKey(apiKey);

      // 发送一个空请求来验证
      await _dio.post('/shrink', data: []);

      LoggerService.i('API Key 验证通过');
      // 如果没有抛出异常，说明Key有效
      if (oldKey != null) {
        setApiKey(oldKey);
      } else {
        _dio.options.headers.remove('Authorization');
        _currentApiKey = null;
      }

      return true;
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode == 401) {
        LoggerService.w('API Key 验证失败：无效或未授权');
        // Key无效
        return false;
      }
      LoggerService.e('API Key 验证过程中发生异常', e);
      // 其他错误可能意味着网络问题，但Key可能是有效的
      rethrow;
    }
  }

  /// 从响应头解析 compression-count
  int? _parseCompressionCount(Headers headers) {
    final list = headers.value('Compression-Count');
    if (list != null) {
      return int.tryParse(list);
    }
    return null;
  }

  /// 统一错误处理
  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final message = e.response!.data['message'] ?? e.message;
      final errorType = e.response!.data['error']; // error 字段

      if (statusCode == 401) {
        return ApiKeyInvalidException();
      } else if (statusCode == 429) {
        return QuotaExceededException();
      } else {
        return ApiRequestException('API 错误 ($errorType): $message', statusCode);
      }
    }
    return NetworkException('网络请求失败: ${e.message}');
  }

  /// 释放资源
  void dispose() {
    _dio.close();
  }
}
