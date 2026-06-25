import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';
import 'package:tinypng_gui/providers/api_key_notifier.dart';
import 'package:tinypng_gui/services/api_key_service.dart';

import 'api_key_notifier_test.mocks.dart';

@GenerateMocks([ApiKeyService])
void main() {
  late MockApiKeyService mockApiKeyService;
  late ApiKeyNotifier notifier;
  late List<ApiKeyInfo> serviceKeys;

  setUp(() {
    mockApiKeyService = MockApiKeyService();
    serviceKeys = [];

    when(mockApiKeyService.initialize()).thenAnswer((_) async {});
    when(mockApiKeyService.getAllKeys()).thenAnswer((_) => List.unmodifiable(serviceKeys));
    when(mockApiKeyService.addApiKey(any, any)).thenAnswer((invocation) async {
      serviceKeys.add(
        ApiKeyInfo(
          key: invocation.positionalArguments[0] as String,
          alias: invocation.positionalArguments[1] as String,
          isDefault: serviceKeys.isEmpty,
        ),
      );
    });
    when(mockApiKeyService.validateKey(any)).thenAnswer((_) async => true);
    when(mockApiKeyService.setDefaultKey(any)).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      serviceKeys = serviceKeys
          .map((k) => k.copyWith(isDefault: k.id == id))
          .toList();
    });
    when(mockApiKeyService.removeApiKey(any)).thenAnswer((invocation) async {
      final id = invocation.positionalArguments[0] as String;
      serviceKeys.removeWhere((k) => k.id == id);
    });
    when(mockApiKeyService.clearAllKeys()).thenAnswer((_) async {
      serviceKeys.clear();
    });

    notifier = ApiKeyNotifier(apiKeyService: mockApiKeyService);
  });

  tearDown(() {
    notifier.dispose();
  });

  group('ApiKeyNotifier', () {
    test('initialize 应从服务加载 Key 列表', () async {
      serviceKeys.add(ApiKeyInfo(key: 'k1', alias: 'A'));

      await notifier.initialize();

      expect(notifier.isInitialized, isTrue);
      expect(notifier.apiKeys, hasLength(1));
      verify(mockApiKeyService.initialize()).called(1);
    });

    test('initialize 在安全存储为空时应迁移 legacy Keys', () async {
      final legacy = [
        ApiKeyInfo(key: 'legacy-key', alias: 'Legacy', isDefault: true),
      ];

      await notifier.initialize(legacyKeys: legacy);

      expect(notifier.apiKeys, hasLength(1));
      expect(notifier.apiKeys.first.key, 'legacy-key');
      verify(mockApiKeyService.addApiKey('legacy-key', 'Legacy')).called(1);
      verify(mockApiKeyService.setDefaultKey(any)).called(1);
    });

    test('addApiKey 验证失败时不应添加', () async {
      when(mockApiKeyService.validateKey('bad')).thenAnswer((_) async => false);
      await notifier.initialize();

      final success = await notifier.addApiKey(key: 'bad', alias: 'Bad');

      expect(success, isFalse);
      expect(notifier.error, contains('无效'));
      expect(notifier.apiKeys, isEmpty);
      verifyNever(mockApiKeyService.addApiKey(any, any));
    });

    test('addApiKey 验证成功时应添加并刷新列表', () async {
      await notifier.initialize();

      final success = await notifier.addApiKey(key: 'good-key', alias: 'Good');

      expect(success, isTrue);
      expect(notifier.apiKeys, hasLength(1));
      expect(notifier.apiKeys.first.alias, 'Good');
    });

    test('removeApiKey 应从列表移除', () async {
      serviceKeys.add(ApiKeyInfo(key: 'k1', alias: 'A'));
      await notifier.initialize();
      final keyId = notifier.apiKeys.first.id;

      await notifier.removeApiKey(keyId);

      expect(notifier.apiKeys, isEmpty);
      verify(mockApiKeyService.removeApiKey(keyId)).called(1);
    });

    test('clearAllKeys 应清空列表', () async {
      serviceKeys.add(ApiKeyInfo(key: 'k1', alias: 'A'));
      await notifier.initialize();

      await notifier.clearAllKeys();

      expect(notifier.apiKeys, isEmpty);
      verify(mockApiKeyService.clearAllKeys()).called(1);
    });
  });
}
