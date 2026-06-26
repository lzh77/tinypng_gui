import 'dart:async';
import '../data/models/api_key_info.dart';
import '../data/datasources/local/secure_api_key_storage.dart';
import '../data/datasources/remote/tinypng_api.dart';
import 'logger_service.dart';

/// API Key 管理服务
/// 负责 API Key 的生命周期管理、验证、轮换和统计更新
class ApiKeyService {
  final SecureApiKeyStorage _storage;
  final TinyPngApi _api;

  List<ApiKeyInfo> _apiKeys = [];
  int _currentKeyIndex = -1;
  bool _initialized = false;

  ApiKeyService({
    required SecureApiKeyStorage storage,
    required TinyPngApi api,
  })  : _storage = storage,
        _api = api;

  /// 初始化服务，从安全存储中加载 Key
  Future<void> initialize() async {
    if (_initialized) return;

    if (!_storage.isInitialized) {
      await _storage.initialize();
    }

    _apiKeys = await _storage.getApiKeys();

    // 设置初始当前索引（默认 Key 或第一个可用 Key）
    _currentKeyIndex = _apiKeys.indexWhere((k) => k.isDefault);
    if (_currentKeyIndex == -1 && _apiKeys.isNotEmpty) {
      _currentKeyIndex =
          _apiKeys.indexWhere((k) => k.status == ApiKeyStatus.active);
    }

    // 如果找到了可用 Key，同步到 TinyPngApi
    final currentKey = getAvailableKey();
    if (currentKey != null) {
      _api.setApiKey(currentKey.key);
    }

    _initialized = true;
    LoggerService.i('ApiKeyService 初始化完成，加载了 ${_apiKeys.length} 个 Key');
  }

  /// 获取所有 Key
  List<ApiKeyInfo> getAllKeys() => List.unmodifiable(_apiKeys);

  /// 获取当前可用的 Key
  ApiKeyInfo? getAvailableKey() {
    if (_currentKeyIndex >= 0 && _currentKeyIndex < _apiKeys.length) {
      final key = _apiKeys[_currentKeyIndex];
      if (key.status == ApiKeyStatus.active) {
        return key;
      }
    }

    // 如果当前选中的不可用，寻找第一个可用的
    final index = _apiKeys.indexWhere((k) => k.status == ApiKeyStatus.active);
    if (index != -1) {
      _currentKeyIndex = index;
      return _apiKeys[index];
    }

    return null;
  }

  /// 获取默认 Key
  ApiKeyInfo? getDefaultKey() {
    try {
      return _apiKeys.firstWhere((k) => k.isDefault);
    } catch (_) {
      return _apiKeys.isNotEmpty ? _apiKeys.first : null;
    }
  }

  /// 设置默认 Key
  Future<void> setDefaultKey(String keyId) async {
    for (int i = 0; i < _apiKeys.length; i++) {
      _apiKeys[i] = _apiKeys[i].copyWith(isDefault: _apiKeys[i].id == keyId);
    }

    final index = _apiKeys.indexWhere((k) => k.id == keyId);
    if (index != -1) {
      _currentKeyIndex = index;
      final selectedKey = _apiKeys[index];
      if (selectedKey.status == ApiKeyStatus.active) {
        _api.setApiKey(selectedKey.key);
      }
    }

    await _storage.saveApiKeys(_apiKeys);
  }

  /// 添加新的 API Key
  Future<void> addApiKey(String key, String alias) async {
    // 验证是否已存在
    if (_apiKeys.any((k) => k.key == key)) {
      throw Exception('此 API Key 已存在');
    }

    final newKey = ApiKeyInfo(
      key: key,
      alias: alias,
      isDefault: _apiKeys.isEmpty,
      monthlyLimit: kTinyPngFreeMonthlyLimit,
    );

    _apiKeys.add(newKey);
    await _storage.saveApiKeys(_apiKeys);

    if (_currentKeyIndex == -1) {
      _currentKeyIndex = _apiKeys.length - 1;
      _api.setApiKey(key);
    }
  }

  /// 删除 API Key
  Future<void> removeApiKey(String keyId) async {
    _apiKeys.removeWhere((k) => k.id == keyId);
    await _storage.saveApiKeys(_apiKeys);

    if (_apiKeys.isEmpty) {
      _currentKeyIndex = -1;
      return;
    }

    final defaultIndex = _apiKeys.indexWhere((k) => k.isDefault);
    _currentKeyIndex = defaultIndex != -1 ? defaultIndex : 0;

    final currentKey = getAvailableKey();
    if (currentKey != null) {
      _api.setApiKey(currentKey.key);
    }
  }

  /// 清空所有 API Key
  Future<void> clearAllKeys() async {
    _apiKeys = [];
    _currentKeyIndex = -1;
    await _storage.saveApiKeys(_apiKeys);
  }

  /// 更新 API Key 信息
  Future<void> updateApiKey(String keyId,
      {String? alias, bool? isDefault, ApiKeyStatus? status}) async {
    final index = _apiKeys.indexWhere((k) => k.id == keyId);
    if (index != -1) {
      _apiKeys[index] = _apiKeys[index].copyWith(
        alias: alias,
        isDefault: isDefault,
        status: status,
      );

      if (isDefault == true) {
        // 确保只有一个默认 Key
        for (int i = 0; i < _apiKeys.length; i++) {
          if (i != index) {
            _apiKeys[i] = _apiKeys[i].copyWith(isDefault: false);
          }
        }
      }

      await _storage.saveApiKeys(_apiKeys);
    }
  }

  /// 验证 API Key
  Future<bool> validateKey(String key) async {
    return await _api.validateApiKey(key);
  }

  /// 更新 Key 的使用统计
  Future<void> updateKeyUsage(String key, int compressionCount) async {
    final index = _apiKeys.indexWhere((k) => k.key == key);
    if (index != -1) {
      final limit = _apiKeys[index].monthlyLimit;
      final reachedLimit =
          limit != null && compressionCount >= limit;

      _apiKeys[index] = _apiKeys[index].copyWith(
        compressionCount: compressionCount,
        lastUsedAt: DateTime.now(),
        status: reachedLimit ? ApiKeyStatus.quotaFull : _apiKeys[index].status,
      );
      await _storage.saveApiKeys(_apiKeys);
    }
  }

  /// 自动轮换到下一个可用 Key
  ApiKeyInfo? rotateToNextKey() {
    if (_apiKeys.isEmpty) return null;

    int startIndex = _currentKeyIndex;
    for (int i = 1; i <= _apiKeys.length; i++) {
      int nextIndex = (startIndex + i) % _apiKeys.length;
      if (_apiKeys[nextIndex].status == ApiKeyStatus.active) {
        _currentKeyIndex = nextIndex;
        final nextKey = _apiKeys[nextIndex];
        _api.setApiKey(nextKey.key);
        LoggerService.i('已轮换到新的 API Key: ${nextKey.alias}');
        return nextKey;
      }
    }

    LoggerService.w('没有更多可用的 API Key');
    return null;
  }

  /// 刷新所有 Key 的状态（模拟验证）
  Future<void> refreshAllKeyStatus() async {
    for (int i = 0; i < _apiKeys.length; i++) {
      // 这里可以实际调用 API 验证，或者只是根据当前配额逻辑
      // 简单处理：如果当前索引有效，就用它
    }
  }
}
