import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tinypng_gui/data/datasources/local/secure_api_key_storage.dart';
import 'package:tinypng_gui/data/datasources/remote/tinypng_api.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';
import 'package:tinypng_gui/services/api_key_service.dart';

import 'api_key_service_test.mocks.dart';

@GenerateMocks([SecureApiKeyStorage, TinyPngApi])
void main() {
  late MockSecureApiKeyStorage mockStorage;
  late MockTinyPngApi mockApi;
  late ApiKeyService apiKeyService;
  late List<ApiKeyInfo> storedKeys;

  setUp(() {
    mockStorage = MockSecureApiKeyStorage();
    mockApi = MockTinyPngApi();
    storedKeys = [];

    when(mockStorage.isInitialized).thenReturn(true);
    when(mockStorage.getApiKeys()).thenAnswer((_) async => List.from(storedKeys));
    when(mockStorage.saveApiKeys(any)).thenAnswer((invocation) async {
      storedKeys = List<ApiKeyInfo>.from(
        invocation.positionalArguments[0] as List<ApiKeyInfo>,
      );
    });

    apiKeyService = ApiKeyService(storage: mockStorage, api: mockApi);
  });

  group('ApiKeyService', () {
    test('initialize 应加载 Key 并同步到 TinyPngApi', () async {
      storedKeys.add(
        ApiKeyInfo(key: 'key-abc', alias: 'Main', isDefault: true),
      );

      await apiKeyService.initialize();

      expect(apiKeyService.getAllKeys(), hasLength(1));
      verify(mockApi.setApiKey('key-abc')).called(1);
    });

    test('addApiKey 首个 Key 应设为默认并写入存储', () async {
      await apiKeyService.initialize();

      await apiKeyService.addApiKey('new-key', 'New');

      expect(apiKeyService.getAllKeys(), hasLength(1));
      expect(apiKeyService.getAllKeys().first.isDefault, isTrue);
      expect(storedKeys, hasLength(1));
      verify(mockApi.setApiKey('new-key')).called(1);
    });

    test('addApiKey 重复 Key 应抛出异常', () async {
      storedKeys.add(ApiKeyInfo(key: 'dup-key', alias: 'A'));
      await apiKeyService.initialize();

      expect(
        () => apiKeyService.addApiKey('dup-key', 'B'),
        throwsA(isA<Exception>()),
      );
    });

    test('setDefaultKey 应更新默认标记并同步 TinyPngApi', () async {
      storedKeys.addAll([
        ApiKeyInfo(id: 'id-1', key: 'k1', alias: 'A', isDefault: true),
        ApiKeyInfo(id: 'id-2', key: 'k2', alias: 'B'),
      ]);
      await apiKeyService.initialize();

      await apiKeyService.setDefaultKey('id-2');

      expect(apiKeyService.getDefaultKey()?.id, 'id-2');
      verify(mockApi.setApiKey('k2')).called(1);
    });

    test('rotateToNextKey 应跳过配额已满的 Key', () async {
      storedKeys.addAll([
        ApiKeyInfo(id: 'id-1', key: 'k1', alias: 'A', isDefault: true),
        ApiKeyInfo(
          id: 'id-2',
          key: 'k2',
          alias: 'B',
          status: ApiKeyStatus.quotaFull,
        ),
        ApiKeyInfo(id: 'id-3', key: 'k3', alias: 'C'),
      ]);
      await apiKeyService.initialize();

      final next = apiKeyService.rotateToNextKey();

      expect(next?.key, 'k3');
      verify(mockApi.setApiKey('k3')).called(1);
    });

    test('clearAllKeys 应清空内存与存储', () async {
      storedKeys.add(ApiKeyInfo(key: 'k1', alias: 'A'));
      await apiKeyService.initialize();

      await apiKeyService.clearAllKeys();

      expect(apiKeyService.getAllKeys(), isEmpty);
      expect(storedKeys, isEmpty);
    });

    test('validateKey 应委托 TinyPngApi', () async {
      when(mockApi.validateApiKey('test')).thenAnswer((_) async => true);

      final result = await apiKeyService.validateKey('test');

      expect(result, isTrue);
      verify(mockApi.validateApiKey('test')).called(1);
    });
  });
}
