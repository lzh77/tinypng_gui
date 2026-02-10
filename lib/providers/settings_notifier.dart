import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/models/app_settings.dart';
import '../data/datasources/local/settings_local_data_source.dart';

/// 应用设置状态管理器
/// 使用 ChangeNotifier 管理应用设置状态，并提供持久化功能
class SettingsNotifier extends ChangeNotifier {
  final SettingsLocalDataSource _dataSource;
  AppSettings _settings = AppSettings(); // 默认设置
  bool _isLoading = false;
  String? _error;

  SettingsNotifier({required SettingsLocalDataSource dataSource})
      : _dataSource = dataSource;

  /// 当前应用设置
  AppSettings get settings => _settings;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 错误信息
  String? get error => _error;

  /// 从本地存储加载设置
  /// 在应用启动时调用
  Future<void> loadSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _settings = await _dataSource.getSettings();
      _error = null;
    } catch (e) {
      _error = '加载设置失败: $e';
      _settings = AppSettings(); // 使用默认设置
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新完整的应用设置
  /// [newSettings] 新的设置对象
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    await _saveSettings();
  }

  /// 更新并发压缩数量限制
  /// [limit] 并发数量 (1-10)
  Future<void> updateConcurrentLimit(int limit) async {
    if (limit < 1 || limit > 10) {
      _error = '并发数量必须在 1-10 之间';
      notifyListeners();
      return;
    }

    _settings = _settings.copyWith(concurrentLimit: limit);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新输出目录
  /// [directory] 输出目录路径
  Future<void> updateOutputDirectory(String directory) async {
    _settings = _settings.copyWith(outputDirectory: directory);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新文件名后缀
  /// [suffix] 文件名后缀（例如: "_compressed"）
  Future<void> updateFileNameSuffix(String suffix) async {
    _settings = _settings.copyWith(fileNameSuffix: suffix);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新重试次数
  /// [count] 重试次数 (0-5)
  Future<void> updateRetryCount(int count) async {
    if (count < 0 || count > 5) {
      _error = '重试次数必须在 0-5 之间';
      notifyListeners();
      return;
    }

    _settings = _settings.copyWith(retryCount: count);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新是否覆盖原文件
  /// [overwrite] 是否覆盖原文件
  Future<void> updateOverwriteOriginal(bool overwrite) async {
    _settings = _settings.copyWith(overwriteOriginal: overwrite);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新是否自动轮换 API Key
  /// [autoRotate] 是否自动轮换
  Future<void> updateAutoRotateKeys(bool autoRotate) async {
    _settings = _settings.copyWith(autoRotateKeys: autoRotate);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新语言设置
  /// [language] 语言代码（例如: "zh-CN", "en-US"）
  Future<void> updateLanguage(String language) async {
    _settings = _settings.copyWith(language: language);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新主题模式
  /// [themeMode] 主题模式（浅色/深色/跟随系统）
  Future<void> updateThemeMode(ThemeMode themeMode) async {
    _settings = _settings.copyWith(themeMode: themeMode);
    notifyListeners();
    await _saveSettings();
  }

  /// 更新默认 API Key ID
  /// [keyId] API Key ID
  Future<void> updateDefaultApiKeyId(String? keyId) async {
    _settings = _settings.copyWith(defaultApiKeyId: keyId);
    notifyListeners();
    await _saveSettings();
  }

  /// 重置为默认设置
  Future<void> resetToDefault() async {
    _settings = AppSettings();
    notifyListeners();
    await _saveSettings();
  }

  /// 清除所有设置
  Future<void> clearSettings() async {
    try {
      await _dataSource.clearSettings();
      _settings = AppSettings();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = '清除设置失败: $e';
      notifyListeners();
    }
  }

  /// 保存设置到本地存储
  Future<void> _saveSettings() async {
    try {
      await _dataSource.saveSettings(_settings);
      _error = null;
    } catch (e) {
      _error = '保存设置失败: $e';
      notifyListeners();
    }
  }
}
