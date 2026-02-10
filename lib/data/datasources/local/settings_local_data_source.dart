import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';

/// 应用设置本地数据源接口
abstract class SettingsLocalDataSource {
  /// 获取保存的应用设置，如果没有则返回默认设置
  Future<AppSettings> getSettings();

  /// 保存应用设置
  Future<void> saveSettings(AppSettings settings);

  /// 清除已保存的应用设置
  Future<void> clearSettings();
}

/// 基于 SharedPreferences 的应用设置本地数据源实现
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final SharedPreferences sharedPreferences;
  static const String _settingsKey = 'app_settings';

  SettingsLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<AppSettings> getSettings() async {
    final jsonString = sharedPreferences.getString(_settingsKey);
    if (jsonString != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        return AppSettings.fromJson(jsonMap);
      } catch (e) {
        // 如果解析失败，返回默认设置并可能记录错误
        return AppSettings();
      }
    }
    return AppSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final jsonString = json.encode(settings.toJson());
    await sharedPreferences.setString(_settingsKey, jsonString);
  }

  @override
  Future<void> clearSettings() async {
    await sharedPreferences.remove(_settingsKey);
  }
}
