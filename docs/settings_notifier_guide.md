# SettingsNotifier 使用指南

## 概述

`SettingsNotifier` 是应用设置的状态管理器，负责管理所有应用配置并提供持久化功能。

## 功能特性

- ✅ 完整的设置状态管理
- ✅ 自动持久化到本地存储
- ✅ 参数验证（并发数、重试次数等）
- ✅ 错误处理和状态反馈
- ✅ 支持所有设置项的独立更新

## 集成到应用

### 1. 在主应用中配置 Provider

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tinypng_gui/providers/providers.dart';
import 'package:tinypng_gui/data/datasources/local/settings_local_data_source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  runApp(MyApp(sharedPreferences: sharedPreferences));
}

class MyApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;

  const MyApp({Key? key, required this.sharedPreferences}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 设置状态管理
        ChangeNotifierProvider(
          create: (_) {
            final dataSource = SettingsLocalDataSourceImpl(
              sharedPreferences: sharedPreferences,
            );
            final notifier = SettingsNotifier(dataSource: dataSource);
            // 在创建时加载设置
            notifier.loadSettings();
            return notifier;
          },
        ),
        
        // 其他 Providers...
      ],
      child: MaterialApp(
        title: 'TinyPNG GUI',
        home: HomeScreen(),
      ),
    );
  }
}
```

### 2. 在 UI 中使用设置

#### 读取设置

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinypng_gui/providers/providers.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用 watch 监听设置变化
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: ListView(
        children: [
          // 显示当前并发数量
          ListTile(
            title: Text('并发数量'),
            subtitle: Text('当前: ${settings.concurrentLimit}'),
          ),
          
          // 显示输出目录
          ListTile(
            title: Text('输出目录'),
            subtitle: Text(settings.outputDirectory.isEmpty 
              ? '与原文件同目录' 
              : settings.outputDirectory),
          ),
          
          // 显示是否覆盖原文件
          SwitchListTile(
            title: Text('覆盖原文件'),
            value: settings.overwriteOriginal,
            onChanged: (value) {
              // 更新设置
              context.read<SettingsNotifier>()
                .updateOverwriteOriginal(value);
            },
          ),
        ],
      ),
    );
  }
}
```

#### 更新设置

```dart
// 在事件处理器中更新设置
class ConcurrencySlider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsNotifier>().settings;
    
    return Column(
      children: [
        Text('并发数量: ${settings.concurrentLimit}'),
        Slider(
          value: settings.concurrentLimit.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          label: settings.concurrentLimit.toString(),
          onChanged: (value) {
            // 使用 read 避免不必要的重建
            context.read<SettingsNotifier>()
              .updateConcurrentLimit(value.toInt());
          },
        ),
      ],
    );
  }
}
```

### 3. 处理加载状态和错误

```dart
class SettingsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsNotifier = context.watch<SettingsNotifier>();

    // 显示加载状态
    if (settingsNotifier.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // 显示错误信息
    if (settingsNotifier.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              settingsNotifier.error!,
              style: TextStyle(color: Colors.red),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                settingsNotifier.loadSettings();
              },
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    // 正常显示设置界面
    return _buildSettingsUI(settingsNotifier.settings);
  }
  
  Widget _buildSettingsUI(AppSettings settings) {
    // 构建设置界面...
    return Container();
  }
}
```

## API 参考

### 属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `settings` | `AppSettings` | 当前应用设置 |
| `isLoading` | `bool` | 是否正在加载 |
| `error` | `String?` | 错误信息 |

### 方法

#### loadSettings()
从本地存储加载设置，应在应用启动时调用。

```dart
await settingsNotifier.loadSettings();
```

#### updateSettings(AppSettings newSettings)
更新完整的设置对象。

```dart
final newSettings = AppSettings(
  concurrentLimit: 5,
  retryCount: 3,
);
await settingsNotifier.updateSettings(newSettings);
```

#### updateConcurrentLimit(int limit)
更新并发压缩数量（范围 1-10）。

```dart
await settingsNotifier.updateConcurrentLimit(5);
```

#### updateOutputDirectory(String directory)
更新输出目录路径。

```dart
await settingsNotifier.updateOutputDirectory('C:\\output');
```

#### updateFileNameSuffix(String suffix)
更新文件名后缀。

```dart
await settingsNotifier.updateFileNameSuffix('_compressed');
```

#### updateRetryCount(int count)
更新重试次数（范围 0-5）。

```dart
await settingsNotifier.updateRetryCount(3);
```

#### updateOverwriteOriginal(bool overwrite)
更新是否覆盖原文件。

```dart
await settingsNotifier.updateOverwriteOriginal(true);
```

#### updateAutoRotateKeys(bool autoRotate)
更新是否自动轮换 API Key。

```dart
await settingsNotifier.updateAutoRotateKeys(true);
```

#### updateLanguage(String language)
更新语言设置。

```dart
await settingsNotifier.updateLanguage('en-US');
```

#### updateThemeMode(ThemeMode themeMode)
更新主题模式。

```dart
await settingsNotifier.updateThemeMode(ThemeMode.dark);
```

#### updateDefaultApiKeyId(String? keyId)
更新默认 API Key ID。

```dart
await settingsNotifier.updateDefaultApiKeyId('key-123');
```

#### resetToDefault()
重置为默认设置。

```dart
await settingsNotifier.resetToDefault();
```

#### clearSettings()
清除所有设置。

```dart
await settingsNotifier.clearSettings();
```

## 最佳实践

### 1. 使用 Consumer 避免不必要的重建

```dart
// 只重建需要更新的部分
Consumer<SettingsNotifier>(
  builder: (context, settingsNotifier, child) {
    return Text('并发数: ${settingsNotifier.settings.concurrentLimit}');
  },
)
```

### 2. 使用 Selector 优化性能

```dart
// 只在特定设置改变时重建
Selector<SettingsNotifier, int>(
  selector: (_, notifier) => notifier.settings.concurrentLimit,
  builder: (context, concurrentLimit, child) {
    return Text('并发数: $concurrentLimit');
  },
)
```

### 3. 参数验证

```dart
// SettingsNotifier 会自动验证参数
await settingsNotifier.updateConcurrentLimit(15); // 会设置错误信息

// 检查错误
if (settingsNotifier.error != null) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(settingsNotifier.error!)),
  );
}
```

### 4. 初始化时加载设置

```dart
// 在 Provider 创建时加载设置
ChangeNotifierProvider(
  create: (_) {
    final notifier = SettingsNotifier(dataSource: dataSource);
    notifier.loadSettings(); // 立即加载
    return notifier;
  },
)
```

## 测试

完整的单元测试位于 `test/providers/settings_notifier_test.dart`。

运行测试：
```bash
flutter test test/providers/settings_notifier_test.dart
```

## 注意事项

1. **并发数限制**：1-10 之间，超出范围会设置错误信息
2. **重试次数限制**：0-5 之间，超出范围会设置错误信息
3. **自动持久化**：所有更新方法都会自动保存到本地存储
4. **错误处理**：保存失败会设置 `error` 属性，但不会抛出异常
5. **线程安全**：所有方法都是异步的，适合在 UI 线程调用

## 相关文件

- 实现：`lib/providers/settings_notifier.dart`
- 测试：`test/providers/settings_notifier_test.dart`
- 数据源：`lib/data/datasources/local/settings_local_data_source.dart`
- 模型：`lib/data/models/app_settings.dart`
