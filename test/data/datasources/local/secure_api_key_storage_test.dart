import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tinypng_gui/data/datasources/local/secure_api_key_storage.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';

void main() {
  // 设置测试环境
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureApiKeyStorage', () {
    late SecureApiKeyStorage storage;

    setUp(() {
      // 每个测试前创建新的存储实例
      storage = SecureApiKeyStorage();

      // Mock FlutterSecureStorage的行为
      // 注意：在实际测试中，flutter_secure_storage可能需要mock
      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() async {
      // 每个测试后清理数据
      try {
        await storage.clearAll();
      } catch (e) {
        // 忽略清理错误
      }
    });

    group('初始化测试', () {
      test('应该成功初始化', () async {
        // Act
        await storage.initialize();

        // Assert
        expect(storage.isInitialized, true);
        expect(storage.deviceId, isNotNull);
        expect(storage.deviceId, isNotEmpty);
      });

      test('重复初始化应该不会出错', () async {
        // Act
        await storage.initialize();
        await storage.initialize();

        // Assert
        expect(storage.isInitialized, true);
      });

      test('未初始化时调用方法应该抛出异常', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(
            key: 'test-key',
            alias: 'Test Key',
          ),
        ];

        // Act & Assert
        expect(
          () => storage.saveApiKeys(apiKeys),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('设备ID管理', () {
      test('相同实例的设备ID应该保持一致', () async {
        // Act
        await storage.initialize();
        final deviceId1 = storage.deviceId;

        // 再次初始化
        final storage2 = SecureApiKeyStorage();
        await storage2.initialize();
        final deviceId2 = storage2.deviceId;

        // Assert
        expect(deviceId1, equals(deviceId2));
      });

      test('清除所有数据后设备ID应该改变', () async {
        // Arrange
        await storage.initialize();
        final oldDeviceId = storage.deviceId;

        // Act
        await storage.clearAll();
        await storage.initialize();
        final newDeviceId = storage.deviceId;

        // Assert
        expect(newDeviceId, isNot(equals(oldDeviceId)));
      });
    });

    group('API Key存储和读取', () {
      setUp(() async {
        await storage.initialize();
      });

      test('应该能保存和读取空列表', () async {
        // Arrange
        final emptyList = <ApiKeyInfo>[];

        // Act
        await storage.saveApiKeys(emptyList);
        final result = await storage.getApiKeys();

        // Assert
        expect(result, isEmpty);
      });

      test('应该能保存和读取单个API Key', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(
            key: 'test-api-key-123',
            alias: 'My Test Key',
            compressionCount: 10,
            monthlyLimit: 500,
            status: ApiKeyStatus.active,
            isDefault: true,
          ),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 1);
        expect(result[0].key, 'test-api-key-123');
        expect(result[0].alias, 'My Test Key');
        expect(result[0].compressionCount, 10);
        expect(result[0].monthlyLimit, 500);
        expect(result[0].status, ApiKeyStatus.active);
        expect(result[0].isDefault, true);
      });

      test('应该能保存和读取多个API Key', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(
            key: 'key-1',
            alias: 'Key 1',
            status: ApiKeyStatus.active,
          ),
          ApiKeyInfo(
            key: 'key-2',
            alias: 'Key 2',
            status: ApiKeyStatus.quotaFull,
          ),
          ApiKeyInfo(
            key: 'key-3',
            alias: 'Key 3',
            status: ApiKeyStatus.disabled,
          ),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 3);
        expect(result[0].key, 'key-1');
        expect(result[1].key, 'key-2');
        expect(result[2].key, 'key-3');
      });

      test('应该能覆盖已有的API Key数据', () async {
        // Arrange
        final firstKeys = [
          ApiKeyInfo(key: 'old-key', alias: 'Old'),
        ];
        final secondKeys = [
          ApiKeyInfo(key: 'new-key', alias: 'New'),
        ];

        // Act
        await storage.saveApiKeys(firstKeys);
        await storage.saveApiKeys(secondKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 1);
        expect(result[0].key, 'new-key');
      });

      test('首次读取应该返回空列表', () async {
        // Act
        final result = await storage.getApiKeys();

        // Assert
        expect(result, isEmpty);
      });
    });

    group('API Key删除', () {
      setUp(() async {
        await storage.initialize();
      });

      test('应该能删除所有API Key', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(key: 'key-1', alias: 'Key 1'),
          ApiKeyInfo(key: 'key-2', alias: 'Key 2'),
        ];
        await storage.saveApiKeys(apiKeys);

        // Act
        await storage.deleteAllApiKeys();
        final result = await storage.getApiKeys();

        // Assert
        expect(result, isEmpty);
      });

      test('删除后应该能重新保存', () async {
        // Arrange
        final apiKeys = [ApiKeyInfo(key: 'test-key', alias: 'Test')];
        await storage.saveApiKeys(apiKeys);
        await storage.deleteAllApiKeys();

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 1);
      });
    });

    group('数据加密验证', () {
      setUp(() async {
        await storage.initialize();
      });

      test('保存的数据应该是加密的', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(key: 'secret-key-123', alias: 'Secret'),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);

        // 直接从secure storage读取原始数据
        const rawStorage = FlutterSecureStorage();
        final rawData =
            await rawStorage.read(key: 'tinypng_api_keys_encrypted');

        // Assert
        expect(rawData, isNotNull);
        // 原始数据不应该包含明文API Key
        expect(rawData, isNot(contains('secret-key-123')));
        // 应该包含Base64编码的特征（冒号分隔IV和密文）
        expect(rawData, contains(':'));
      });

      test('不同的API Key应该产生不同的加密结果', () async {
        // Arrange
        const rawStorage = FlutterSecureStorage();
        final apiKeys1 = [ApiKeyInfo(key: 'key-1', alias: 'Key 1')];
        final apiKeys2 = [ApiKeyInfo(key: 'key-2', alias: 'Key 2')];

        // Act
        await storage.saveApiKeys(apiKeys1);
        final encrypted1 =
            await rawStorage.read(key: 'tinypng_api_keys_encrypted');

        await storage.saveApiKeys(apiKeys2);
        final encrypted2 =
            await rawStorage.read(key: 'tinypng_api_keys_encrypted');

        // Assert
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });

    group('错误处理', () {
      test('读取损坏的数据应该返回空列表而不抛出异常', () async {
        // Arrange
        await storage.initialize();
        const rawStorage = FlutterSecureStorage();
        // 写入无效的加密数据
        await rawStorage.write(
          key: 'tinypng_api_keys_encrypted',
          value: 'invalid-encrypted-data',
        );

        // Act
        final result = await storage.getApiKeys();

        // Assert
        expect(result, isEmpty);
      });

      test('保存包含特殊字符的API Key应该正常工作', () async {
        // Arrange
        await storage.initialize();
        final apiKeys = [
          ApiKeyInfo(
            key: 'key-with-特殊字符-!@#\$%^&*()',
            alias: 'Special 字符 Alias',
          ),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 1);
        expect(result[0].key, 'key-with-特殊字符-!@#\$%^&*()');
        expect(result[0].alias, 'Special 字符 Alias');
      });
    });

    group('完整数据清除', () {
      test('clearAll应该删除所有数据包括设备ID', () async {
        // Arrange
        await storage.initialize();
        final apiKeys = [ApiKeyInfo(key: 'test-key', alias: 'Test')];
        await storage.saveApiKeys(apiKeys);

        // Act
        await storage.clearAll();

        // Assert
        expect(storage.isInitialized, false);

        // 重新初始化后应该无法读取之前的数据
        await storage.initialize();
        final result = await storage.getApiKeys();
        expect(result, isEmpty);
      });
    });

    group('并发访问测试', () {
      setUp(() async {
        await storage.initialize();
      });

      test('连续多次保存应该正常工作', () async {
        // Arrange & Act
        for (int i = 0; i < 10; i++) {
          final apiKeys = [
            ApiKeyInfo(key: 'key-$i', alias: 'Key $i'),
          ];
          await storage.saveApiKeys(apiKeys);
        }

        // Assert
        final result = await storage.getApiKeys();
        expect(result.length, 1);
        expect(result[0].key, 'key-9'); // 最后一次保存的数据
      });

      test('快速读写应该保持数据一致性', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(key: 'test-key', alias: 'Test'),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);
        final result1 = await storage.getApiKeys();
        final result2 = await storage.getApiKeys();
        final result3 = await storage.getApiKeys();

        // Assert
        expect(result1, equals(result2));
        expect(result2, equals(result3));
      });
    });

    group('边界条件测试', () {
      setUp(() async {
        await storage.initialize();
      });

      test('应该能处理大量API Key', () async {
        // Arrange
        final apiKeys = List.generate(
          100,
          (index) => ApiKeyInfo(
            key: 'key-$index',
            alias: 'Key $index',
            compressionCount: index,
          ),
        );

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 100);
        for (int i = 0; i < 100; i++) {
          expect(result[i].key, 'key-$i');
          expect(result[i].compressionCount, i);
        }
      });

      test('应该能处理极长的API Key', () async {
        // Arrange
        final longKey = 'a' * 10000;
        final apiKeys = [
          ApiKeyInfo(key: longKey, alias: 'Long Key'),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 1);
        expect(result[0].key, longKey);
      });

      test('应该能处理包含null值的可选字段', () async {
        // Arrange
        final apiKeys = [
          ApiKeyInfo(
            key: 'test-key',
            alias: 'Test',
            monthlyLimit: null, // null值
            lastUsedAt: null, // null值
          ),
        ];

        // Act
        await storage.saveApiKeys(apiKeys);
        final result = await storage.getApiKeys();

        // Assert
        expect(result.length, 1);
        expect(result[0].monthlyLimit, isNull);
        expect(result[0].lastUsedAt, isNull);
      });
    });
  });
}
