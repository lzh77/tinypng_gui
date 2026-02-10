# API Key 安全存储使用指南

## 概述

`SecureApiKeyStorage` 服务提供了 API Key 的安全存储功能，使用双重加密保护：
1. **AES-256加密**：对数据进行加密
2. **flutter_secure_storage**：Windows平台使用系统凭据管理器进行系统级保护

## 安全特性

- ✅ 基于设备唯一标识符生成加密密钥
- ✅ 加密数据无法在其他设备上解密
- ✅ Windows平台使用凭据管理器进行系统级访问控制
- ✅ 每次加密使用随机IV，相同数据每次加密结果不同

## 使用方法

### 1. 初始化

在应用启动时初始化存储服务：

```dart
import 'package:tinypng_gui/data/datasources/local/secure_api_key_storage.dart';

final storage = SecureApiKeyStorage();

// 必须先初始化
await storage.initialize();
```

### 2. 保存 API Keys

```dart
import 'package:tinypng_gui/data/models/api_key_info.dart';

// 创建API Key信息
final apiKeys = [
  ApiKeyInfo(
    key: 'your-api-key-here',
    alias: 'My Primary Key',
    compressionCount: 0,
    monthlyLimit: 500,
    status: ApiKeyStatus.active,
    isDefault: true,
  ),
  ApiKeyInfo(
    key: 'backup-api-key',
    alias: 'Backup Key',
    status: ApiKeyStatus.active,
  ),
];

// 保存到安全存储
await storage.saveApiKeys(apiKeys);
```

### 3. 读取 API Keys

```dart
// 获取所有已保存的API Keys
final apiKeys = await storage.getApiKeys();

// 处理API Keys
for (final apiKey in apiKeys) {
  print('Key: ${apiKey.alias}');
  print('Status: ${apiKey.status}');
  print('Used: ${apiKey.compressionCount}/${apiKey.monthlyLimit ?? "unlimited"}');
}
```

### 4. 删除 API Keys

```dart
// 删除所有API Keys（保留设备ID）
await storage.deleteAllApiKeys();

// 或者：完全清除所有数据（包括设备ID）
// 警告：这会使之前加密的数据无法解密！
await storage.clearAll();
```

## 完整示例

```dart
import 'package:tinypng_gui/data/datasources/local/secure_api_key_storage.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';

Future<void> main() async {
  // 1. 创建并初始化存储
  final storage = SecureApiKeyStorage();
  await storage.initialize();
  
  print('Device ID: ${storage.deviceId}');
  print('Initialized: ${storage.isInitialized}');
  
  // 2. 创建API Key
  final newKey = ApiKeyInfo(
    key: 'sk-1234567890abcdef',
    alias: 'Production Key',
    compressionCount: 150,
    monthlyLimit: 500,
    status: ApiKeyStatus.active,
    isDefault: true,
  );
  
  // 3. 保存
  await storage.saveApiKeys([newKey]);
  print('API Key saved successfully!');
  
  // 4. 读取
  final savedKeys = await storage.getApiKeys();
  print('Retrieved ${savedKeys.length} API key(s)');
  
  if (savedKeys.isNotEmpty) {
    final key = savedKeys.first;
    print('Alias: ${key.alias}');
    print('Used: ${key.compressionCount}/${key.monthlyLimit}');
  }
  
  // 5. 更新API Key（修改后重新保存）
  final updatedKey = newKey.copyWith(
    compressionCount: 151,
  );
  await storage.saveApiKeys([updatedKey]);
  print('API Key updated!');
}
```

## 在应用中集成

### 在 main.dart 中初始化

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinypng_gui/data/datasources/local/secure_api_key_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化API Key存储
  final apiKeyStorage = SecureApiKeyStorage();
  await apiKeyStorage.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        // 提供SecureApiKeyStorage实例给整个应用
        Provider.value(value: apiKeyStorage),
        // ... 其他providers
      ],
      child: MyApp(),
    ),
  );
}
```

### 在UI中使用

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tinypng_gui/data/datasources/local/secure_api_key_storage.dart';
import 'package:tinypng_gui/data/models/api_key_info.dart';

class ApiKeySettingsScreen extends StatefulWidget {
  @override
  _ApiKeySettingsScreenState createState() => _ApiKeySettingsScreenState();
}

class _ApiKeySettingsScreenState extends State<ApiKeySettingsScreen> {
  List<ApiKeyInfo> _apiKeys = [];
  
  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }
  
  Future<void> _loadApiKeys() async {
    final storage = context.read<SecureApiKeyStorage>();
    final keys = await storage.getApiKeys();
    setState(() {
      _apiKeys = keys;
    });
  }
  
  Future<void> _addApiKey(String key, String alias) async {
    final storage = context.read<SecureApiKeyStorage>();
    
    final newKey = ApiKeyInfo(
      key: key,
      alias: alias,
      status: ApiKeyStatus.active,
    );
    
    final updatedKeys = [..._apiKeys, newKey];
    await storage.saveApiKeys(updatedKeys);
    
    await _loadApiKeys();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('API Key Management')),
      body: ListView.builder(
        itemCount: _apiKeys.length,
        itemBuilder: (context, index) {
          final key = _apiKeys[index];
          return ListTile(
            title: Text(key.alias),
            subtitle: Text('Used: ${key.compressionCount}'),
            trailing: Icon(
              key.status == ApiKeyStatus.active
                  ? Icons.check_circle
                  : Icons.error,
              color: key.status == ApiKeyStatus.active
                  ? Colors.green
                  : Colors.red,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 显示添加API Key对话框
          _showAddKeyDialog();
        },
        child: Icon(Icons.add),
      ),
    );
  }
  
  void _showAddKeyDialog() {
    // 实现添加API Key对话框
    // ...
  }
}
```

## 错误处理

所有方法都可能抛出异常，建议使用 try-catch 处理：

```dart
try {
  await storage.saveApiKeys(apiKeys);
  print('保存成功');
} catch (e) {
  print('保存失败: $e');
  // 向用户显示错误提示
}
```

## 注意事项

⚠️ **重要提示**：

1. **必须先初始化**：在使用任何其他方法之前，必须先调用 `initialize()`
2. **clearAll** 的影响：`clearAll()` 会删除设备ID，导致之前加密的数据无法解密
3. **数据迁移**：如果需要在不同设备间迁移数据，需要在新设备上重新输入API Key
4. **并发访问**：虽然服务支持并发读写，但建议在单线程中顺序访问以避免数据竞争

## 测试

运行单元测试以验证功能：

```bash
flutter test test/data/datasources/local/secure_api_key_storage_test.dart
```

所有22个测试用例应该全部通过 ✅
