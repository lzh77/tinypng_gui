import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tinypng_gui/data/datasources/local/settings_local_data_source.dart';
import 'package:tinypng_gui/data/models/app_settings.dart';
import 'package:flutter/material.dart';

import 'settings_local_data_source_test.mocks.dart';

@GenerateMocks([SharedPreferences])
void main() {
  late SettingsLocalDataSourceImpl dataSource;
  late MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    dataSource =
        SettingsLocalDataSourceImpl(sharedPreferences: mockSharedPreferences);
  });

  group('SettingsLocalDataSource', () {
    const tSettingsKey = 'app_settings';
    final tAppSettings = AppSettings(
      outputDirectory: 'C:\\Users\\Test\\Pictures',
      overwriteOriginal: true,
      concurrentLimit: 5,
      themeMode: ThemeMode.dark,
    );

    test('当没有保存的设置时，getSettings 应返回默认设置', () async {
      // arrange
      when(mockSharedPreferences.getString(any)).thenReturn(null);

      // act
      final result = await dataSource.getSettings();

      // assert
      expect(result, equals(AppSettings()));
      verify(mockSharedPreferences.getString(tSettingsKey));
    });

    test('当有保存的设置时，getSettings 应正确解析并返回 AppSettings', () async {
      // arrange
      final jsonString = json.encode(tAppSettings.toJson());
      when(mockSharedPreferences.getString(tSettingsKey))
          .thenReturn(jsonString);

      // act
      final result = await dataSource.getSettings();

      // assert
      expect(result, equals(tAppSettings));
      verify(mockSharedPreferences.getString(tSettingsKey));
    });

    test('saveSettings 应调用 SharedPreferences 保存 JSON 字符串', () async {
      // arrange
      final expectedJsonString = json.encode(tAppSettings.toJson());
      when(mockSharedPreferences.setString(any, any))
          .thenAnswer((_) async => true);

      // act
      await dataSource.saveSettings(tAppSettings);

      // assert
      verify(mockSharedPreferences.setString(tSettingsKey, expectedJsonString));
    });

    test('clearSettings 应调用 SharedPreferences 移除对应的 key', () async {
      // arrange
      when(mockSharedPreferences.remove(any)).thenAnswer((_) async => true);

      // act
      await dataSource.clearSettings();

      // assert
      verify(mockSharedPreferences.remove(tSettingsKey));
    });

    test('当 JSON 解析失败时，getSettings 应返回默认设置', () async {
      // arrange
      when(mockSharedPreferences.getString(tSettingsKey))
          .thenReturn('invalid json');

      // act
      final result = await dataSource.getSettings();

      // assert
      expect(result, equals(AppSettings()));
    });
    group('FromJson 特殊检查', () {
      test('themeMode 应该能从字符串正确解析', () {
        final json = {
          'themeMode': 'ThemeMode.dark',
        };
        final settings = AppSettings.fromJson(json);
        expect(settings.themeMode, ThemeMode.dark);
      });
    });
  });
}
