import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';
import 'package:tinypng_gui/data/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('toJson 不应持久化 API Key 明文', () {
      final settings = AppSettings(
        apiKeys: [
          ApiKeyInfo(key: 'secret-key-value', alias: 'Test'),
        ],
        concurrentLimit: 5,
        retryCount: 2,
      );

      final json = settings.toJson();

      expect(json['apiKeys'], isEmpty);
      expect(json['concurrentLimit'], 5);
      expect(json['retryCount'], 2);
    });

    test('fromJson 应能读取旧版 apiKeys 字段以支持迁移', () {
      final json = {
        'apiKeys': [
          {
            'id': 'key-1',
            'key': 'legacy-secret',
            'alias': 'Legacy',
            'compressionCount': 0,
            'status': 'ApiKeyStatus.active',
            'createdAt': '2026-01-01T00:00:00.000',
            'isDefault': true,
          },
        ],
        'concurrentLimit': 4,
      };

      final settings = AppSettings.fromJson(json);

      expect(settings.apiKeys, hasLength(1));
      expect(settings.apiKeys.first.key, 'legacy-secret');
      expect(settings.concurrentLimit, 4);
    });

    test('copyWith 应正确覆盖字段', () {
      final original = AppSettings(concurrentLimit: 3, retryCount: 1);
      final updated = original.copyWith(concurrentLimit: 8, themeMode: ThemeMode.dark);

      expect(updated.concurrentLimit, 8);
      expect(updated.retryCount, 1);
      expect(updated.themeMode, ThemeMode.dark);
    });

    test('getDefaultApiKey 应优先返回 defaultApiKeyId 对应项', () {
      final key1 = ApiKeyInfo(id: 'id-1', key: 'k1', alias: 'A');
      final key2 = ApiKeyInfo(id: 'id-2', key: 'k2', alias: 'B', isDefault: true);

      final settings = AppSettings(
        apiKeys: [key1, key2],
        defaultApiKeyId: 'id-1',
      );

      expect(settings.getDefaultApiKey()?.id, 'id-1');
    });
  });
}
