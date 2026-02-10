import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'data/datasources/local/secure_api_key_storage.dart';
import 'data/datasources/local/settings_local_data_source.dart';
import 'data/datasources/remote/tinypng_api.dart';
import 'providers/providers.dart';
import 'screens/home/home_screen.dart';
import 'services/api_key_service.dart';
import 'services/compression_service.dart';
import 'services/file_service.dart';
import 'services/queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Windows 数据库驱动
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // 2. 初始化窗口管理
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1024, 768),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'TinyPNG 批量压缩工具',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 3. 初始化 SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(TinyPngApp(sharedPreferences: sharedPreferences));
}

class TinyPngApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;

  const TinyPngApp({super.key, required this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ========== 数据源层 ============
        // 使用具体的实现类，并作为抽象类类型提供
        Provider<SettingsLocalDataSource>(
          create: (_) => SettingsLocalDataSourceImpl(
            sharedPreferences: sharedPreferences,
          ),
        ),
        Provider(
          create: (_) => SecureApiKeyStorage(),
        ),
        Provider(
          create: (_) => TinyPngApi(),
        ),

        // ========== 服务层 ============
        Provider(
          create: (_) => FileService(),
        ),

        // ApiKeyService 需要 SecureApiKeyStorage 和 TinyPngApi
        ProxyProvider2<SecureApiKeyStorage, TinyPngApi, ApiKeyService>(
          update: (context, storage, api, previous) =>
              previous ?? ApiKeyService(storage: storage, api: api),
        ),

        // CompressionService 依赖众多
        ProxyProvider4<TinyPngApi, ApiKeyService, SettingsLocalDataSource,
            FileService, CompressionService>(
          update: (context, api, apiKeyService, settingsDataSource, fileService,
                  previous) =>
              previous ??
              CompressionService(
                api: api,
                apiKeyService: apiKeyService,
                settingsDataSource: settingsDataSource,
                fileService: fileService,
              ),
        ),

        // QueueService 依赖 CompressionService
        ProxyProvider<CompressionService, QueueService>(
          update: (context, compressionService, previous) =>
              previous ??
              QueueService(
                compressionService: compressionService,
              ),
        ),

        // ========== 状态管理层 ============

        // 1. 设置状态管理
        ChangeNotifierProxyProvider<SettingsLocalDataSource, SettingsNotifier>(
          create: (context) => SettingsNotifier(
            dataSource: context.read<SettingsLocalDataSource>(),
          ),
          update: (context, dataSource, previous) =>
              previous ?? SettingsNotifier(dataSource: dataSource),
        ),

        // 2. 任务状态管理
        ChangeNotifierProxyProvider<QueueService, TasksNotifier>(
          create: (context) => TasksNotifier(
            queueService: context.read<QueueService>(),
          ),
          update: (context, queueService, previous) =>
              previous ?? TasksNotifier(queueService: queueService),
        ),

        // 3. 队列状态管理
        ChangeNotifierProxyProvider<QueueService, QueueStatusNotifier>(
          create: (context) => QueueStatusNotifier(
            queueService: context.read<QueueService>(),
          ),
          update: (context, queueService, previous) =>
              previous ?? QueueStatusNotifier(queueService: queueService),
        ),
      ],
      child: const MainApp(),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 监听主题变化
    final themeMode = context.select<SettingsNotifier, ThemeMode>(
      (settings) => settings.settings.themeMode,
    );

    return MaterialApp(
      title: 'TinyPNG GUI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Microsoft YaHei',
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
