import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'api_key_info.dart';

/// 应用设置模型
/// 用于存储和管理应用程序的各种配置选项
class AppSettings extends Equatable {
  final List<ApiKeyInfo> apiKeys; // 所有API Key列表
  final String? defaultApiKeyId; // 默认使用的API Key ID
  final bool autoRotateKeys; // 是否自动轮换使用多个API Key
  final String outputDirectory; // 输出目录路径
  final bool overwriteOriginal; // 是否覆盖原始文件
  final String fileNameSuffix; // 压缩后文件的名称后缀
  final int concurrentLimit; // 并发压缩任务的最大数量
  final int retryCount; // 失败任务的重试次数
  final String language; // 应用语言设置
  final ThemeMode themeMode; // 主题模式（浅色/深色/系统）

  AppSettings({
    List<ApiKeyInfo>? apiKeys,
    this.defaultApiKeyId,
    this.autoRotateKeys = false,
    this.outputDirectory = '',
    this.overwriteOriginal = false,
    this.fileNameSuffix = '_compressed',
    this.concurrentLimit = 3,
    this.retryCount = 3,
    this.language = 'zh-CN',
    this.themeMode = ThemeMode.system,
  }) : apiKeys = apiKeys ?? [];

  /// 创建一个新的AppSettings实例，其属性值来自当前实例，
  /// 但可以根据需要覆盖某些属性
  AppSettings copyWith({
    List<ApiKeyInfo>? apiKeys,
    String? defaultApiKeyId,
    bool? autoRotateKeys,
    String? outputDirectory,
    bool? overwriteOriginal,
    String? fileNameSuffix,
    int? concurrentLimit,
    int? retryCount,
    String? language,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      apiKeys: apiKeys ?? this.apiKeys,
      defaultApiKeyId: defaultApiKeyId ?? this.defaultApiKeyId,
      autoRotateKeys: autoRotateKeys ?? this.autoRotateKeys,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      overwriteOriginal: overwriteOriginal ?? this.overwriteOriginal,
      fileNameSuffix: fileNameSuffix ?? this.fileNameSuffix,
      concurrentLimit: concurrentLimit ?? this.concurrentLimit,
      retryCount: retryCount ?? this.retryCount,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// 将对象转换为JSON格式的映射
  Map<String, dynamic> toJson() {
    return {
      'apiKeys': apiKeys.map((key) => key.toJson()).toList(),
      'defaultApiKeyId': defaultApiKeyId,
      'autoRotateKeys': autoRotateKeys,
      'outputDirectory': outputDirectory,
      'overwriteOriginal': overwriteOriginal,
      'fileNameSuffix': fileNameSuffix,
      'concurrentLimit': concurrentLimit,
      'retryCount': retryCount,
      'language': language,
      'themeMode': themeMode.toString(),
    };
  }

  /// 从JSON格式的映射创建AppSettings实例
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      apiKeys: (json['apiKeys'] as List<dynamic>?)
              ?.map((keyJson) =>
                  ApiKeyInfo.fromJson(keyJson as Map<String, dynamic>))
              .toList() ??
          [],
      defaultApiKeyId: json['defaultApiKeyId'] as String?,
      autoRotateKeys: json['autoRotateKeys'] as bool? ?? false,
      outputDirectory: json['outputDirectory'] as String? ?? '',
      overwriteOriginal: json['overwriteOriginal'] as bool? ?? false,
      fileNameSuffix: json['fileNameSuffix'] as String? ?? '_compressed',
      concurrentLimit: json['concurrentLimit'] as int? ?? 3,
      retryCount: json['retryCount'] as int? ?? 3,
      language: json['language'] as String? ?? 'zh-CN',
      themeMode: _getThemeModeFromString(
          json['themeMode'] as String? ?? 'ThemeMode.system'),
    );
  }

  /// 根据字符串形式的主题模式转换为ThemeMode枚举
  static ThemeMode _getThemeModeFromString(String themeModeStr) {
    switch (themeModeStr) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  /// 获取默认的API Key
  /// 如果设置了默认API Key ID，则返回对应的API Key
  /// 否则返回标记为默认的第一个API Key
  /// 如果都没有，则返回列表中的第一个API Key（如果存在）
  ApiKeyInfo? getDefaultApiKey() {
    if (defaultApiKeyId != null) {
      var apiKey = apiKeys.firstWhere((key) => key.id == defaultApiKeyId,
          orElse: () => ApiKeyInfo(
                key: '',
                alias: '',
              ));
      if (apiKey.key.isNotEmpty) {
        return apiKey;
      }
    }

    var defaultKey = apiKeys.firstWhere((key) => key.isDefault,
        orElse: () => ApiKeyInfo(
              key: '',
              alias: '',
            ));
    if (defaultKey.key.isNotEmpty) {
      return defaultKey;
    }

    return apiKeys.isNotEmpty ? apiKeys.first : null;
  }

  /// 获取所有可用的API Key
  /// 返回状态为active的API Key列表
  List<ApiKeyInfo> getAvailableApiKeys() {
    return apiKeys.where((key) => key.status == ApiKeyStatus.active).toList();
  }

  /// 获取默认设置的实例
  AppSettings get defaultSettings => AppSettings();

  @override
  List<Object?> get props => [
        apiKeys,
        defaultApiKeyId,
        autoRotateKeys,
        outputDirectory,
        overwriteOriginal,
        fileNameSuffix,
        concurrentLimit,
        retryCount,
        language,
        themeMode,
      ];
}
