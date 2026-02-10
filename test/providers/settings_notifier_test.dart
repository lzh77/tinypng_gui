import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tinypng_gui/data/models/app_settings.dart';
import 'package:tinypng_gui/data/datasources/local/settings_local_data_source.dart';
import 'package:tinypng_gui/providers/settings_notifier.dart';

import 'settings_notifier_test.mocks.dart';

// 生成 Mock 类
@GenerateMocks([SettingsLocalDataSource])
void main() {
  late MockSettingsLocalDataSource mockDataSource;
  late SettingsNotifier settingsNotifier;

  setUp(() {
    mockDataSource = MockSettingsLocalDataSource();
    settingsNotifier = SettingsNotifier(dataSource: mockDataSource);
  });

  tearDown(() {
    settingsNotifier.dispose();
  });

  group('SettingsNotifier 初始化测试', () {
    test('初始状态应为默认设置', () {
      expect(settingsNotifier.settings, isA<AppSettings>());
      expect(settingsNotifier.isLoading, false);
      expect(settingsNotifier.error, isNull);
    });
  });

  group('loadSettings 测试', () {
    test('成功加载设置时应更新状态', () async {
      // 准备测试数据
      final testSettings = AppSettings(
        concurrentLimit: 5,
        retryCount: 2,
        fileNameSuffix: '_test',
      );

      // 配置 Mock 行为
      when(mockDataSource.getSettings()).thenAnswer((_) async => testSettings);

      // 执行测试
      await settingsNotifier.loadSettings();

      // 验证结果
      expect(settingsNotifier.settings.concurrentLimit, 5);
      expect(settingsNotifier.settings.retryCount, 2);
      expect(settingsNotifier.settings.fileNameSuffix, '_test');
      expect(settingsNotifier.isLoading, false);
      expect(settingsNotifier.error, isNull);

      // 验证 Mock 调用
      verify(mockDataSource.getSettings()).called(1);
    });

    test('加载失败时应使用默认设置并设置错误信息', () async {
      // 配置 Mock 抛出异常
      when(mockDataSource.getSettings()).thenThrow(Exception('读取失败'));

      // 执行测试
      await settingsNotifier.loadSettings();

      // 验证结果
      expect(settingsNotifier.settings, isA<AppSettings>());
      expect(settingsNotifier.isLoading, false);
      expect(settingsNotifier.error, contains('加载设置失败'));
    });
  });

  group('updateConcurrentLimit 测试', () {
    test('更新有效的并发数量应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.updateConcurrentLimit(5);

      // 验证结果
      expect(settingsNotifier.settings.concurrentLimit, 5);
      verify(mockDataSource.saveSettings(any)).called(1);
    });

    test('更新无效的并发数量应设置错误', () async {
      // 执行测试 - 超出上限
      await settingsNotifier.updateConcurrentLimit(15);

      // 验证结果
      expect(settingsNotifier.error, contains('并发数量必须在 1-10 之间'));
      verifyNever(mockDataSource.saveSettings(any));

      // 执行测试 - 低于下限
      await settingsNotifier.updateConcurrentLimit(0);

      // 验证结果
      expect(settingsNotifier.error, contains('并发数量必须在 1-10 之间'));
      verifyNever(mockDataSource.saveSettings(any));
    });
  });

  group('updateOutputDirectory 测试', () {
    test('更新输出目录应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      const testDir = 'C:\\output';
      await settingsNotifier.updateOutputDirectory(testDir);

      // 验证结果
      expect(settingsNotifier.settings.outputDirectory, testDir);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('updateFileNameSuffix 测试', () {
    test('更新文件名后缀应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      const testSuffix = '_optimized';
      await settingsNotifier.updateFileNameSuffix(testSuffix);

      // 验证结果
      expect(settingsNotifier.settings.fileNameSuffix, testSuffix);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('updateRetryCount 测试', () {
    test('更新有效的重试次数应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.updateRetryCount(3);

      // 验证结果
      expect(settingsNotifier.settings.retryCount, 3);
      verify(mockDataSource.saveSettings(any)).called(1);
    });

    test('更新无效的重试次数应设置错误', () async {
      // 执行测试 - 超出上限
      await settingsNotifier.updateRetryCount(10);

      // 验证结果
      expect(settingsNotifier.error, contains('重试次数必须在 0-5 之间'));
      verifyNever(mockDataSource.saveSettings(any));

      // 执行测试 - 低于下限
      await settingsNotifier.updateRetryCount(-1);

      // 验证结果
      expect(settingsNotifier.error, contains('重试次数必须在 0-5 之间'));
      verifyNever(mockDataSource.saveSettings(any));
    });
  });

  group('updateOverwriteOriginal 测试', () {
    test('更新覆盖原文件选项应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.updateOverwriteOriginal(true);

      // 验证结果
      expect(settingsNotifier.settings.overwriteOriginal, true);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('updateAutoRotateKeys 测试', () {
    test('更新自动轮换 API Key 选项应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.updateAutoRotateKeys(true);

      // 验证结果
      expect(settingsNotifier.settings.autoRotateKeys, true);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('updateLanguage 测试', () {
    test('更新语言设置应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      const testLanguage = 'en-US';
      await settingsNotifier.updateLanguage(testLanguage);

      // 验证结果
      expect(settingsNotifier.settings.language, testLanguage);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('updateThemeMode 测试', () {
    test('更新主题模式应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.updateThemeMode(ThemeMode.dark);

      // 验证结果
      expect(settingsNotifier.settings.themeMode, ThemeMode.dark);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('updateDefaultApiKeyId 测试', () {
    test('更新默认 API Key ID 应成功', () async {
      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      const testKeyId = 'test-key-123';
      await settingsNotifier.updateDefaultApiKeyId(testKeyId);

      // 验证结果
      expect(settingsNotifier.settings.defaultApiKeyId, testKeyId);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('resetToDefault 测试', () {
    test('重置为默认设置应成功', () async {
      // 先修改一些设置
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});
      await settingsNotifier.updateConcurrentLimit(7);

      // 执行重置
      await settingsNotifier.resetToDefault();

      // 验证结果 - 应该恢复到默认值
      expect(settingsNotifier.settings.concurrentLimit, 3); // 默认值
      verify(mockDataSource.saveSettings(any))
          .called(2); // updateConcurrentLimit + resetToDefault
    });
  });

  group('clearSettings 测试', () {
    test('清除设置应成功', () async {
      // 配置 Mock
      when(mockDataSource.clearSettings()).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.clearSettings();

      // 验证结果
      expect(settingsNotifier.settings, isA<AppSettings>());
      expect(settingsNotifier.error, isNull);
      verify(mockDataSource.clearSettings()).called(1);
    });

    test('清除设置失败应设置错误信息', () async {
      // 配置 Mock 抛出异常
      when(mockDataSource.clearSettings()).thenThrow(Exception('删除失败'));

      // 执行测试
      await settingsNotifier.clearSettings();

      // 验证结果
      expect(settingsNotifier.error, contains('清除设置失败'));
    });
  });

  group('updateSettings 测试', () {
    test('更新完整设置对象应成功', () async {
      // 准备测试数据
      final newSettings = AppSettings(
        concurrentLimit: 8,
        retryCount: 4,
        fileNameSuffix: '_new',
        overwriteOriginal: true,
      );

      // 配置 Mock
      when(mockDataSource.saveSettings(any)).thenAnswer((_) async => {});

      // 执行测试
      await settingsNotifier.updateSettings(newSettings);

      // 验证结果
      expect(settingsNotifier.settings.concurrentLimit, 8);
      expect(settingsNotifier.settings.retryCount, 4);
      expect(settingsNotifier.settings.fileNameSuffix, '_new');
      expect(settingsNotifier.settings.overwriteOriginal, true);
      verify(mockDataSource.saveSettings(any)).called(1);
    });
  });

  group('持久化失败测试', () {
    test('保存失败时应设置错误信息', () async {
      // 配置 Mock 抛出异常
      when(mockDataSource.saveSettings(any)).thenThrow(Exception('保存失败'));

      // 执行测试
      await settingsNotifier.updateConcurrentLimit(5);

      // 验证结果 - 设置应该更新，但有错误信息
      expect(settingsNotifier.settings.concurrentLimit, 5);
      expect(settingsNotifier.error, contains('保存设置失败'));
    });
  });
}
