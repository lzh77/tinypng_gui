import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
// import 'package:provider/provider.dart'; // 暂时注释掉，等添加 Notifier 后再用

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

  runApp(const TinyPngApp());
}

class TinyPngApp extends StatelessWidget {
  const TinyPngApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 暂时不使用 MultiProvider，直到我们有了实际的 Provider
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
      themeMode: ThemeMode.system,
      home: const Scaffold(
        body: Center(
          child: Text(
            'TinyPNG GUI\n项目初始化完成',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
