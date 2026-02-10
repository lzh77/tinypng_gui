import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../../models/api_key_info.dart';
import '../../../services/logger_service.dart';

/// API Key安全存储服务
///
/// 使用双重加密保护API Key：
/// 1. AES-256加密数据
/// 2. flutter_secure_storage提供系统级保护（Windows凭据管理器）
///
/// 安全特性：
/// - 基于设备唯一标识符生成加密密钥
/// - 加密数据无法在其他设备上解密
/// - Windows平台使用凭据管理器进行系统级访问控制
class SecureApiKeyStorage {
  // flutter_secure_storage在Windows平台会自动使用凭据管理器
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  late encrypt.Encrypter _encrypter;
  late String _deviceId;
  bool _initialized = false;

  // 存储键
  static const String _keysStorageKey = 'tinypng_api_keys_encrypted';
  static const String _deviceIdKey = 'device_identifier';

  // 加密盐值（增强安全性）
  static const String _encryptionSalt = 'tinypng_gui_salt_v1';

  /// 初始化加密器
  ///
  /// 这个方法应该在应用启动时调用一次
  /// 它会生成或获取设备ID，并基于设备ID创建加密密钥
  ///
  /// 抛出：
  /// - [Exception] 如果初始化失败
  Future<void> initialize() async {
    if (_initialized) {
      return; // 避免重复初始化
    }

    try {
      LoggerService.i('正在初始化SecureApiKeyStorage...');
      // 获取或创建设备ID
      _deviceId = await _getOrCreateDeviceId();
      LoggerService.d('设备ID已准备就绪');

      // 基于设备ID生成加密密钥
      final key = _deriveEncryptionKey(_deviceId);

      // 创建AES加密器
      _encrypter = encrypt.Encrypter(encrypt.AES(key));

      _initialized = true;
      LoggerService.i('SecureApiKeyStorage初始化完成');
    } catch (e, stackTrace) {
      LoggerService.e('初始化API Key存储失败', e, stackTrace);
      throw Exception('初始化API Key存储失败: $e');
    }
  }

  /// 获取或创建设备唯一标识符
  ///
  /// 设备ID用于生成加密密钥，确保数据只能在本设备上解密
  /// 首次运行时生成一个UUID作为设备ID并安全存储
  /// 后续运行时直接读取已存储的设备ID
  ///
  /// 返回：设备唯一标识符
  Future<String> _getOrCreateDeviceId() async {
    // 尝试读取已存在的设备ID
    String? existingId = await _storage.read(key: _deviceIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    // 生成新的设备ID
    final newId = const Uuid().v4();

    // 安全存储设备ID
    await _storage.write(key: _deviceIdKey, value: newId);

    return newId;
  }

  /// 基于设备ID生成AES加密密钥
  ///
  /// 使用SHA-256哈希算法从设备ID生成256位密钥
  /// 添加盐值以增强安全性
  ///
  /// 参数：
  /// - [deviceId] 设备唯一标识符
  ///
  /// 返回：AES-256加密密钥
  encrypt.Key _deriveEncryptionKey(String deviceId) {
    // 组合设备ID和盐值
    final bytes = utf8.encode(deviceId + _encryptionSalt);

    // 使用SHA-256生成256位哈希
    final hash = sha256.convert(bytes);

    // 转换为加密库所需的Key格式
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// 加密字符串
  ///
  /// 使用AES-256-CBC模式加密，每次加密使用随机IV（初始化向量）
  /// 返回格式：IV(Base64):加密数据(Base64)
  ///
  /// 参数：
  /// - [plainText] 需要加密的明文
  ///
  /// 返回：加密后的文本（IV和密文用冒号分隔）
  String _encrypt(String plainText) {
    _ensureInitialized();

    // 生成随机IV（初始化向量），确保相同明文每次加密结果不同
    final iv = encrypt.IV.fromSecureRandom(16);

    // 执行加密
    final encrypted = _encrypter.encrypt(plainText, iv: iv);

    // 返回 "IV:密文" 格式（都使用Base64编码）
    return '${iv.base64}:${encrypted.base64}';
  }

  /// 解密字符串
  ///
  /// 解析加密文本并还原原始内容
  ///
  /// 参数：
  /// - [encryptedText] 加密后的文本（IV:密文格式）
  ///
  /// 返回：解密后的明文
  ///
  /// 抛出：
  /// - [Exception] 如果加密格式无效或解密失败
  String _decrypt(String encryptedText) {
    _ensureInitialized();

    // 分离IV和密文
    final parts = encryptedText.split(':');
    if (parts.length != 2) {
      throw Exception('无效的加密格式');
    }

    try {
      // 解析IV和密文
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      // 执行解密
      return _encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('解密失败: $e');
    }
  }

  /// 保存API Key列表
  ///
  /// 将API Key列表序列化为JSON，加密后存储到secure storage
  ///
  /// 参数：
  /// - [apiKeys] 要保存的API Key列表
  ///
  /// 抛出：
  /// - [Exception] 如果保存失败
  Future<void> saveApiKeys(List<ApiKeyInfo> apiKeys) async {
    _ensureInitialized();

    try {
      LoggerService.d('正在保存 ${apiKeys.length} 个API Key...');
      // 将API Key列表转换为JSON
      final jsonData = jsonEncode(
        apiKeys.map((k) => k.toJson()).toList(),
      );

      // 加密JSON数据
      final encryptedData = _encrypt(jsonData);

      // 存储到secure storage（Windows平台使用凭据管理器）
      await _storage.write(
        key: _keysStorageKey,
        value: encryptedData,
      );
      LoggerService.i('API Key已成功加密保存');
    } catch (e, stackTrace) {
      LoggerService.e('保存API Key失败', e, stackTrace);
      throw Exception('保存API Key失败: $e');
    }
  }

  /// 获取API Key列表
  ///
  /// 从secure storage读取加密数据，解密后反序列化为API Key列表
  ///
  /// 返回：API Key列表，如果没有数据或解密失败则返回空列表
  Future<List<ApiKeyInfo>> getApiKeys() async {
    _ensureInitialized();

    try {
      LoggerService.d('正在读取存储的API Key...');
      // 从secure storage读取加密数据
      final encryptedData = await _storage.read(key: _keysStorageKey);

      // 如果没有数据，返回空列表
      if (encryptedData == null || encryptedData.isEmpty) {
        LoggerService.d('未发现存储的API Key数据');
        return [];
      }

      // 解密数据
      final jsonData = _decrypt(encryptedData);

      // 反序列化JSON
      final List<dynamic> decoded = jsonDecode(jsonData);

      // 转换为ApiKeyInfo列表
      final results = decoded
          .map((j) => ApiKeyInfo.fromJson(j as Map<String, dynamic>))
          .toList();

      LoggerService.i('成功从安全存储加载了 ${results.length} 个API Key');
      return results;
    } catch (e, stackTrace) {
      // 解密失败可能是因为数据损坏或密钥不匹配
      // 返回空列表而不是抛出异常，避免应用崩溃
      LoggerService.w('读取或解密API Key数据失败 (可能数据损坏或密钥变更): $e');
      LoggerService.e('详细错误信息', e, stackTrace);
      return [];
    }
  }

  /// 删除所有API Key
  ///
  /// 从secure storage中删除所有存储的API Key数据
  /// 注意：不会删除设备ID
  Future<void> deleteAllApiKeys() async {
    _ensureInitialized();

    try {
      await _storage.delete(key: _keysStorageKey);
    } catch (e) {
      throw Exception('删除API Key失败: $e');
    }
  }

  /// 完全清除所有数据（包括设备ID）
  ///
  /// 警告：这将删除设备ID，之前加密的数据将无法解密！
  /// 仅在需要完全重置应用时使用
  Future<void> clearAll() async {
    try {
      LoggerService.w('正在彻底清除所有安全存储数据（包括设备识别码）...');
      await _storage.deleteAll();
      _initialized = false;
      LoggerService.i('所有安全存储数据已完全清除');
    } catch (e, stackTrace) {
      LoggerService.e('清除所有数据失败', e, stackTrace);
      throw Exception('清除所有数据失败: $e');
    }
  }

  /// 检查是否已初始化
  ///
  /// 抛出：
  /// - [StateError] 如果尚未初始化
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SecureApiKeyStorage未初始化，请先调用initialize()');
    }
  }

  /// 获取当前设备ID（仅用于调试）
  ///
  /// 返回：设备ID，如果未初始化则返回null
  String? get deviceId => _initialized ? _deviceId : null;

  /// 检查是否已初始化
  bool get isInitialized => _initialized;
}
