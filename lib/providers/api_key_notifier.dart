import 'package:flutter/foundation.dart';
import '../data/models/api_key_info.dart';
import '../services/api_key_service.dart';
import '../services/logger_service.dart';

/// API Key 状态管理器
/// 通过 [ApiKeyService] 读写安全存储，供设置页 UI 与压缩流程共用同一数据源
class ApiKeyNotifier extends ChangeNotifier {
  final ApiKeyService _apiKeyService;

  List<ApiKeyInfo> _apiKeys = [];
  bool _isLoading = false;
  bool _initialized = false;
  String? _error;

  ApiKeyNotifier({required ApiKeyService apiKeyService})
      : _apiKeyService = apiKeyService;

  List<ApiKeyInfo> get apiKeys => List.unmodifiable(_apiKeys);

  bool get isLoading => _isLoading;

  bool get isInitialized => _initialized;

  String? get error => _error;

  /// 从安全存储加载 Key；若存在旧版 SharedPreferences 中的 Key 则迁移后写入安全存储
  Future<void> initialize({List<ApiKeyInfo> legacyKeys = const []}) async {
    if (_initialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiKeyService.initialize();
      await _migrateLegacyKeys(legacyKeys);
      _apiKeys = _apiKeyService.getAllKeys();
      _initialized = true;
    } catch (e, stackTrace) {
      LoggerService.e('初始化 API Key 失败', e, stackTrace);
      _error = '加载 API Key 失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 验证并添加 API Key
  Future<bool> addApiKey({required String key, required String alias}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureInitialized();

      final bool valid = await _apiKeyService.validateKey(key);
      if (!valid) {
        _error = 'API Key 无效，请检查后重试';
        return false;
      }

      await _apiKeyService.addApiKey(key, alias);
      _refreshKeys();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 删除 API Key
  Future<void> removeApiKey(String keyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureInitialized();
      await _apiKeyService.removeApiKey(keyId);
      _refreshKeys();
    } catch (e) {
      _error = '删除 API Key 失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 设为默认 API Key
  Future<void> setDefaultKey(String keyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureInitialized();
      await _apiKeyService.setDefaultKey(keyId);
      _refreshKeys();
    } catch (e) {
      _error = '设置默认 API Key 失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空所有 API Key（重置设置时调用）
  Future<void> clearAllKeys() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureInitialized();
      await _apiKeyService.clearAllKeys();
      _refreshKeys();
    } catch (e) {
      _error = '清空 API Key 失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 压缩任务完成后同步用量（供后续配额展示）
  void refreshFromService() {
    _refreshKeys();
    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  void _refreshKeys() {
    _apiKeys = _apiKeyService.getAllKeys();
  }

  Future<void> _migrateLegacyKeys(List<ApiKeyInfo> legacyKeys) async {
    if (legacyKeys.isEmpty) return;

    final existingKeys = _apiKeyService.getAllKeys();
    if (existingKeys.isNotEmpty) {
      LoggerService.i('安全存储已有 API Key，跳过 SharedPreferences 迁移');
      return;
    }

    LoggerService.i('正在迁移 ${legacyKeys.length} 个 API Key 到安全存储...');
    for (final legacyKey in legacyKeys) {
      if (legacyKey.key.isEmpty) continue;
      try {
        await _apiKeyService.addApiKey(legacyKey.key, legacyKey.alias);
      } catch (e) {
        LoggerService.w('迁移 API Key「${legacyKey.alias}」失败: $e');
      }
    }

    final defaultLegacy = legacyKeys.where((k) => k.isDefault && k.key.isNotEmpty);
    if (defaultLegacy.isNotEmpty) {
      final targetKey = defaultLegacy.first.key;
      final migrated = _apiKeyService.getAllKeys().firstWhere(
            (k) => k.key == targetKey,
          );
      await _apiKeyService.setDefaultKey(migrated.id);
    }

    _refreshKeys();
  }
}
