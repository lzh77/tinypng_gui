import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'data/datasources/local/history_database.dart';
import 'data/datasources/local/secure_api_key_storage.dart';
import 'data/datasources/local/settings_local_data_source.dart';
import 'data/datasources/remote/tinypng_api.dart';
import 'providers/providers.dart';
import 'screens/home/home_screen.dart';
import 'services/api_key_service.dart';
import 'services/compression_service.dart';
import 'services/file_service.dart';
import 'services/history_service.dart';
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
        Provider(
          create: (_) => HistoryDatabase(),
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

        ProxyProvider<HistoryDatabase, HistoryService>(
          update: (context, database, previous) =>
              previous ?? HistoryService(database: database),
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

        // 2. 历史记录状态管理
        ChangeNotifierProxyProvider<HistoryService, HistoryNotifier>(
          create: (context) => HistoryNotifier(
            historyService: context.read<HistoryService>(),
          ),
          update: (context, historyService, previous) =>
              previous ?? HistoryNotifier(historyService: historyService),
        ),

        // 3. 任务状态管理（完成后写入历史）
        ChangeNotifierProxyProvider2<QueueService, HistoryNotifier,
            TasksNotifier>(
          create: (context) => TasksNotifier(
            queueService: context.read<QueueService>(),
            historyNotifier: context.read<HistoryNotifier>(),
          ),
          update: (context, queueService, historyNotifier, previous) {
            final notifier = previous ??
                TasksNotifier(
                  queueService: queueService,
                  historyNotifier: historyNotifier,
                );
            notifier.bindHistoryNotifier(historyNotifier);
            return notifier;
          },
        ),

        // 4. 队列状态管理
        ChangeNotifierProxyProvider2<QueueService, SettingsLocalDataSource,
            QueueStatusNotifier>(
          create: (context) => QueueStatusNotifier(
            queueService: context.read<QueueService>(),
            settingsDataSource: context.read<SettingsLocalDataSource>(),
          ),
          update: (context, queueService, settingsDataSource, previous) =>
              previous ??
              QueueStatusNotifier(
                queueService: queueService,
                settingsDataSource: settingsDataSource,
              ),
        ),

        // 5. API Key 状态管理（与安全存储 / 压缩流程共用 ApiKeyService）
        ChangeNotifierProxyProvider<ApiKeyService, ApiKeyNotifier>(
          create: (context) => ApiKeyNotifier(
            apiKeyService: context.read<ApiKeyService>(),
          ),
          update: (context, apiKeyService, previous) =>
              previous ?? ApiKeyNotifier(apiKeyService: apiKeyService),
        ),
      ],
      child: const MainApp(),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// 启动时加载设置，并将旧版 SharedPreferences 中的 API Key 迁移到安全存储
  Future<void> _bootstrap() async {
    if (!mounted) return;

    final settingsNotifier = context.read<SettingsNotifier>();
    final apiKeyNotifier = context.read<ApiKeyNotifier>();

    await settingsNotifier.loadSettings();

    final legacyKeys = settingsNotifier.settings.apiKeys
        .where((key) => key.key.isNotEmpty)
        .toList();

    await apiKeyNotifier.initialize(legacyKeys: legacyKeys);
    await context.read<HistoryNotifier>().initialize();

    if (!mounted) return;

    if (legacyKeys.isNotEmpty) {
      await settingsNotifier.updateSettings(
        settingsNotifier.settings.copyWith(
          apiKeys: const [],
          defaultApiKeyId: null,
        ),
      );
    }

    if (!mounted) return;
    context.read<QueueService>().concurrentLimit =
        settingsNotifier.settings.concurrentLimit;
  }

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
