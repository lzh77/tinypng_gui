# TinyPNG GUI - 技术架构设计

## 1. 整体架构

本项目采用 **分层架构** + **MVVM 模式**，确保代码的可维护性和可测试性。

```
┌─────────────────────────────────────────────┐
│           Presentation Layer                │
│  (UI Widgets + ViewModels/Controllers)      │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│           Business Logic Layer              │
│     (Services + Use Cases + Models)         │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│            Data Layer                       │
│  (Repositories + Data Sources + Storage)    │
└─────────────────────────────────────────────┘
```

---

## 2. 项目目录结构

```
lib/
├── main.dart                      # 应用入口
├── app/
│   ├── app.dart                   # App 配置
│   └── routes.dart                # 路由配置
├── core/
│   ├── constants/                 # 常量定义
│   ├── utils/                     # 工具类
│   ├── theme/                     # 主题配置
│   └── errors/                    # 错误定义
├── data/
│   ├── models/                    # 数据模型
│   │   ├── compression_task.dart
│   │   ├── compression_result.dart
│   │   ├── api_key_info.dart
│   │   └── app_settings.dart
│   ├── repositories/              # 数据仓库
│   │   ├── tinypng_repository.dart
│   │   └── settings_repository.dart
│   └── datasources/               # 数据源
│       ├── remote/
│       │   └── tinypng_api.dart
│       └── local/
│           ├── settings_storage.dart
│           └── history_storage.dart
├── domain/
│   ├── entities/                  # 业务实体
│   └── usecases/                  # 业务用例
│       ├── compress_images.dart
│       └── manage_settings.dart
├── presentation/
│   ├── screens/                   # 页面
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── home_viewmodel.dart
│   │   ├── settings/
│   │   │   ├── settings_screen.dart
│   │   │   └── settings_viewmodel.dart
│   │   └── history/
│   │       ├── history_screen.dart
│   │       └── history_viewmodel.dart
│   └── widgets/                   # 可复用组件
│       ├── file_list_item.dart
│       ├── progress_indicator.dart
│       └── statistics_panel.dart
└── services/
    ├── compression_service.dart   # 压缩服务
    ├── file_service.dart          # 文件服务
    └── queue_service.dart         # 队列管理服务
```

---

## 3. 核心模块设计

### 3.1 数据模型

#### CompressionTask (压缩任务)
```dart
class CompressionTask {
  final String id;
  final String filePath;
  final String fileName;
  final int originalSize;
  int? compressedSize;
  CompressionStatus status;
  String? errorMessage;
  double? compressionRatio;
  DateTime createdAt;
  DateTime? completedAt;
}

enum CompressionStatus {
  pending,    // 等待中
  processing, // 压缩中
  completed,  // 已完成
  failed,     // 失败
  cancelled   // 已取消
}
```

#### ApiKeyInfo (API Key 信息)
```dart
class ApiKeyInfo {
  final String id;              // 唯一标识
  final String key;             // API Key
  final String alias;           // 别名
  int compressionCount;         // 已使用次数
  int? monthlyLimit;            // 月度限额（null 表示未知）
  ApiKeyStatus status;          // 状态
  DateTime createdAt;           // 创建时间
  DateTime? lastUsedAt;         // 最后使用时间
  bool isDefault;               // 是否为默认 Key
}

enum ApiKeyStatus {
  active,      // 可用
  quotaFull,   // 配额已满
  invalid,     // 无效
  disabled     // 已禁用
}
```

#### AppSettings (应用设置)
```dart
class AppSettings {
  List<ApiKeyInfo> apiKeys;     // 多个 API Key
  String? defaultApiKeyId;      // 默认 API Key ID
  bool autoRotateKeys;          // 自动轮换 Key
  String outputDirectory;
  bool overwriteOriginal;
  String fileNameSuffix;
  int concurrentLimit;
  int retryCount;
  String language;
  ThemeMode themeMode;
}
```

### 3.2 TinyPNG API 服务

### 3.2 TinyPNG API 服务

处理与 TinyPNG API 的所有交互，包括认证、上传、下载和配额管理。

```dart
import 'package:dio/dio.dart';
import 'dart:convert';

class ResizeOptions {
  final String method; // scale, fit, cover, thumb
  final int? width;
  final int? height;
  
  ResizeOptions({required this.method, this.width, this.height});
}

class TinyPngApi {
  final Dio _dio;
  String? _currentApiKey;
  
  static const String _baseUrl = 'https://api.tinify.com';
  
  // 构造函数
  TinyPngApi({String? apiKey}) : _dio = Dio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 300); // 压缩可能耗时
    
    if (apiKey != null) {
      setApiKey(apiKey);
    }
  }
  
  // 设置/更新 API Key
  void setApiKey(String apiKey) {
    _currentApiKey = apiKey;
    // 设置 Basic Auth 头
    final basicAuth = 'api:$apiKey';
    final encoded = base64Encode(utf8.encode(basicAuth));
    _dio.options.headers['Authorization'] = 'Basic $encoded';
  }
  
  /// 完整的压缩流程：上传 -> 压缩 -> (可选Resize/Convert) -> 下载
  /// 返回压缩结果和最新的配额使用量
  Future<CompressionResultData> compressImage(
    File file, {
    ResizeOptions? resize,
    String? targetFormat, // 'image/webp', etc.
  }) async {
    if (_currentApiKey == null) throw ApiException('未设置 API Key');
    
    try {
      // 1. 上传图片进行压缩
      final response = await _dio.post(
        '/shrink',
        data: file.openRead(),
        options: Options(
          headers: {
            Headers.contentLengthHeader: await file.length(),
          },
        ),
      );
      
      // 2. 从响应头获取配额信息
      final compressionCount = _parseCompressionCount(response.headers);
      
      // 3. 解析响应体获取下载 URL
      final outputUrl = response.data['output']['url'] as String;
      final compressedSize = response.data['output']['size'] as int;
      final type = response.data['output']['type'] as String;
      
      // 4. 下载压缩后的图片
      final compressedBytes = await _downloadImage(outputUrl);
      
      return CompressionResultData(
        originalSize: response.data['input']['size'],
        compressedSize: compressedSize,
        mimeType: type,
        data: compressedBytes,
        monthlyCompressionCount: compressionCount,
      );
      
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
  
  /// 下载压缩后的图片
  Future<Uint8List> _downloadImage(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }
  
  /// 验证 API Key 是否有效
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final oldKey = _currentApiKey;
      setApiKey(apiKey);
      
      // 发送一个空请求或者压缩一个极小的图片来验证
      // 这里可以尝试压缩一个 1x1 的透明像素文件，或者仅检查是否返回 401
      // 更好的方式是压缩一个已知的微小 buffer
      
      // 临时方案：发送一个错误的请求并检查是否是 401
      // 注意：TinyPNG 没有专门的验证端点，通常通过一次实际操作来验证
      
      setApiKey(apiKey); // 恢复之前的 Key
      return true;
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        return false;
      }
      // 其他错误可能意味着 Key 有效但网络有问题
      return true; 
    }
  }
  
  /// 从响应头解析 compression-count
  int? _parseCompressionCount(Headers headers) {
    final list = headers['Compression-Count'];
    if (list != null && list.isNotEmpty) {
      return int.tryParse(list.first);
    }
    return null;
  }
  
  /// 统一错误处理
  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final message = e.response!.data['message'] ?? e.message;
      final errorType = e.response!.data['error']; // error 字段
      
      if (statusCode == 401) {
        return ApiException('API Key 无效或未授权', 401);
      } else if (statusCode == 429) {
        return QuotaExceededException();
      } else {
        return ApiException('API 错误 ($errorType): $message', statusCode);
      }
    }
    return NetworkException('网络请求失败: ${e.message}');
  }
}

/// 压缩结果数据封装
class CompressionResultData {
  final int originalSize;
  final int compressedSize;
  final String mimeType;
  final Uint8List data;
  final int? monthlyCompressionCount;
  
  CompressionResultData({
    required this.originalSize,
    required this.compressedSize,
    required this.mimeType,
    required this.data,
    this.monthlyCompressionCount,
  });
}
```

> [!NOTE]
> TinyPNG API 响应包含 `input` 和 `output` 两部分信息。`output.url` 用于下载压缩后的图片。
> `Compression-Count` 响应头表示当月已压缩的图片总数。

### 3.3 API Key 管理服务

```dart
class ApiKeyService {
  final List<ApiKeyInfo> _apiKeys = [];
  int _currentKeyIndex = 0;
  final bool _autoRotate;
  
  ApiKeyService({bool autoRotate = true}) : _autoRotate = autoRotate;
  
  // 添加 API Key
  Future<void> addApiKey(String key, String alias);
  
  // 删除 API Key
  void removeApiKey(String keyId);
  
  // 更新 API Key 信息
  void updateApiKey(String keyId, {String? alias, bool? isDefault});
  
  // 获取可用的 API Key
  ApiKeyInfo? getAvailableKey();
  
  // 获取默认 API Key
  ApiKeyInfo? getDefaultKey();
  
  // 设置默认 API Key
  void setDefaultKey(String keyId);
  
  // 验证 API Key
  Future<ApiKeyStatus> validateKey(String key);
  
  // 更新 Key 使用统计
  void updateKeyUsage(String keyId, int compressionCount);
  
  // 自动轮换到下一个可用 Key
  ApiKeyInfo? rotateToNextKey();
  
  // 获取所有 Key
  List<ApiKeyInfo> getAllKeys();
  
  // 刷新所有 Key 的状态
  Future<void> refreshAllKeyStatus();
}
```

### 3.4 压缩服务

```dart
class CompressionService {
  final TinyPngApi _api;
  final ApiKeyService _keyService;
  final FileService _fileService;
  
  // 压缩单个文件（自动处理 Key 轮换）
  Future<CompressionResult> compressFile(CompressionTask task) async {
    try {
      return await _compressWithCurrentKey(task);
    } on QuotaExceededException {
      // 配额用完，尝试轮换 Key
      final nextKey = _keyService.rotateToNextKey();
      if (nextKey != null) {
        _api.setApiKey(nextKey.key);
        return await _compressWithCurrentKey(task);
      }
      rethrow;
    }
  }
  
  Future<CompressionResult> _compressWithCurrentKey(CompressionTask task);
  
  // 批量压缩（带并发控制和自动 Key 轮换）
  Stream<CompressionTask> compressBatch(
    List<CompressionTask> tasks,
    {int concurrentLimit = 3}
  );
}
```

### 3.4 队列管理服务

```dart
class QueueService {
  final List<CompressionTask> _queue = [];
  final StreamController<QueueEvent> _eventController;
  
  int _concurrentLimit = 3;
  int _activeCount = 0;
  bool _isPaused = false;
  
  // 添加任务
  void addTask(CompressionTask task);
  void addTasks(List<CompressionTask> tasks);
  
  // 控制队列
  void start();
  void pause();
  void resume();
  void cancel();
  
  // 移除任务
  void removeTask(String taskId);
  void clear();
  
  // 队列状态
  Stream<QueueEvent> get events;
  QueueStatus get status;
}
```

### 3.5 文件服务

负责文件系统操作，必须使用 `path` 包处理所有路径，以确保 Windows/macOS/Linux 跨平台兼容性。

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

class FileService {
  /// 生成输出文件路径
  /// [originalPath]: 原始文件路径
  /// [outputDir]: 输出目录（如果为空，则默认与原文件同目录）
  /// [suffix]: 文件名后缀（例如 "_compressed"）
  String generateOutputPath(String originalPath, {
    String? outputDir, 
    String suffix = ''
  }) {
    final filename = p.basenameWithoutExtension(originalPath);
    final extension = p.extension(originalPath);
    final newFilename = '$filename$suffix$extension';
    
    if (outputDir != null && outputDir.isNotEmpty) {
      return p.join(outputDir, newFilename);
    } else {
      return p.join(p.dirname(originalPath), newFilename);
    }
  }

  /// 选择文件
  Future<List<File>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    
    if (result != null) {
      return result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();
    }
    return [];
  }
  
  /// 选择文件夹并递归查找图片
  Future<List<File>> pickDirectory({bool recursive = false}) async {
    final String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    
    if (selectedDirectory == null) return [];
    
    final dir = Directory(selectedDirectory);
    final List<File> images = [];
    
    try {
      if (recursive) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && _isSupportedImage(entity.path)) {
            images.add(entity);
          }
        }
      } else {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File && _isSupportedImage(entity.path)) {
            images.add(entity);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory: $e');
    }
    
    return images;
  }
  
  /// 保存文件到指定路径 (自动创建目录)
  Future<void> saveFile(Uint8List data, String path) async {
    // 确保父目录存在
    final directory = Directory(p.dirname(path));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    final file = File(path);
    await file.writeAsBytes(data);
  }
  
  /// 判断是否为支持的图片格式
  bool _isSupportedImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp'].contains(ext);
  }
  
  /// 获取文件大小的可读字符串
  String getFileSizeString(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(1)) + ' ' + suffixes[i];
  }
}
```

---

## 4. 状态管理

使用 **Provider** 进行状态管理。

> [!NOTE]
> 本项目选择 **Provider** 作为状态管理方案，而不是 Riverpod。
> Provider 更成熟、稳定，学习曲线平缓，适合中小型项目。

### 4.1 主要 ChangeNotifier

```dart
import 'package:flutter/foundation.dart';

/// 压缩任务管理器
class TasksNotifier extends ChangeNotifier {
  List<CompressionTask> _tasks = [];
  
  List<CompressionTask> get tasks => List.unmodifiable(_tasks);
  
  void addTask(CompressionTask task) {
    _tasks.add(task);
    notifyListeners();
  }
  
  void addTasks(List<CompressionTask> tasks) {
    _tasks.addAll(tasks);
    notifyListeners();
  }
  
  void updateTask(String taskId, CompressionTask updatedTask) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }
  
  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
  
  void clearAll() {
    _tasks.clear();
    notifyListeners();
  }

  void clearFailed() {
    _tasks.removeWhere((t) => t.status == CompressionStatus.failed);
    notifyListeners();
  }
}

/// 应用设置管理器
class SettingsNotifier extends ChangeNotifier {
  AppSettings _settings = AppSettings.defaultSettings();
  
  AppSettings get settings => _settings;
  
  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }
  
  void updateConcurrentLimit(int limit) {
    _settings = _settings.copyWith(concurrentLimit: limit);
    notifyListeners();
  }
}

/// 队列状态管理器
class QueueStatusNotifier extends ChangeNotifier {
  QueueStatus _status = QueueStatus.idle;
  
  QueueStatus get status => _status;
  
  void updateStatus(QueueStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }
}
```

### 4.2 Provider 设置

在应用根部配置所有 Provider：

```dart
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ChangeNotifier Providers
        ChangeNotifierProvider(
          create: (_) => TasksNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsNotifier(),
        ),
        ChangeNotifierProvider(
          create: (_) => QueueStatusNotifier(),
        ),
        
        // Service Providers (单例)
        Provider(
          create: (_) => CompressionService(
            api: TinyPngApi(''),
            maxConcurrent: 3,
          ),
        ),
        Provider(
          create: (_) => FileService(),
        ),
        
        // Proxy Providers (依赖其他 Provider)
        ProxyProvider<TasksNotifier, Statistics>(
          update: (_, tasksNotifier, __) {
            return Statistics.fromTasks(tasksNotifier.tasks);
          },
        ),
      ],
      child: MaterialApp(
        title: 'TinyPNG GUI',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: HomeScreen(),
      ),
    );
  }
}
```

### 4.3 StreamProvider 示例

对于异步数据流，使用 StreamProvider：

```dart
// 在 MultiProvider 中添加
StreamProvider<QueueEvent>(
  create: (context) {
    final queueService = context.read<QueueService>();
    return queueService.events;
  },
  initialData: QueueEvent.idle(),
)
```

---

## 5. UI 设计

### 5.1 主界面 (HomeScreen)

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 使用 context.watch 监听状态变化
    final tasks = context.watch<TasksNotifier>().tasks;
    final queueStatusProvider = context.watch<QueueStatusNotifier>();
    final statistics = context.watch<Statistics>(); // ProxyProvider 提供的
    
    return Scaffold(
      appBar: AppBar(
        title: Text('TinyPNG 批量压缩工具'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 工具栏
          ActionToolbar(),
          
          // 文件列表
          Expanded(
            child: FileListView(tasks: tasks),
          ),
          
          // 统计面板
          StatisticsPanel(statistics: statistics),
          
          // 进度条
          ProgressBar(status: queueStatusProvider.status),
          
          // 控制按钮
          ControlButtons(),
        ],
      ),
    );
  }
}
```

### 5.2 关键组件

#### FileListItem (文件列表项)
```dart
class FileListItem extends StatelessWidget {
  final CompressionTask task;
  
  const FileListItem({Key? key, required this.task}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _buildStatusIcon(),
      title: Text(task.fileName),
      subtitle: Text(task.filePath),
      trailing: _buildTrailing(context),
    );
  }
  
  Widget _buildTrailing(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.delete),
      onPressed: () {
        // 使用 context.read 调用方法（不监听变化）
        context.read<TasksNotifier>().removeTask(task.id);
      },
    );
  }

  Widget _buildStatusIcon() {
    switch (task.status) {
      case CompressionStatus.pending:
        return Icon(Icons.schedule, color: Colors.grey);
      case CompressionStatus.processing:
        return CircularProgressIndicator();
      case CompressionStatus.completed:
        return Icon(Icons.check_circle, color: Colors.green);
      case CompressionStatus.failed:
        return Icon(Icons.error, color: Colors.red);
      default:
        return Icon(Icons.cancel, color: Colors.grey);
    }
  }
}
```

---

## 6. 数据持久化

### 6.1 API Key 存储（增强加密）

使用 `flutter_secure_storage` + **AES-256 加密**双层保护 API Key。

> [!IMPORTANT]
> `flutter_secure_storage` 在 Windows 上使用凭据管理器，提供系统级保护。
> 为了增强安全性，我们在此基础上添加 AES 加密层，确保即使凭据管理器被访问，
> 攻击者也无法直接读取 API Key。

#### 6.1.1 安全存储实现

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class SecureApiKeyStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final encrypt.Encrypter _encrypter;
  late final String _deviceId;
  
  static const String _keysStorageKey = 'tinypng_api_keys_encrypted';
  static const String _deviceIdKey = 'device_identifier';
  
  /// 初始化加密器（应用启动时调用一次）
  Future<void> initialize() async {
    _deviceId = await _getOrCreateDeviceId();
    final key = _deriveEncryptionKey(_deviceId);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }
  
  Future<String> _getOrCreateDeviceId() async {
    String? existingId = await _storage.read(key: _deviceIdKey);
    if (existingId != null) return existingId;
    
    final newId = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: newId);
    return newId;
  }
  
  encrypt.Key _deriveEncryptionKey(String deviceId) {
    // 使用设备ID和盐生成密钥
    final bytes = utf8.encode(deviceId + 'tinypng_gui_salt_v1');
    final hash = sha256.convert(bytes);
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }
  
  String _encrypt(String plainText) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }
  
  String _decrypt(String encryptedText) {
    final parts = encryptedText.split(':');
    if (parts.length != 2) throw Exception('无效的加密格式');
    
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    return _encrypter.decrypt(encrypted, iv: iv);
  }
  
  Future<void> saveApiKeys(List<ApiKeyInfo> apiKeys) async {
    final jsonData = jsonEncode(apiKeys.map((k) => k.toJson()).toList());
    final encryptedData = _encrypt(jsonData);
    await _storage.write(key: _keysStorageKey, value: encryptedData);
  }
  
  Future<List<ApiKeyInfo>> getApiKeys() async {
    try {
      final encryptedData = await _storage.read(key: _keysStorageKey);
      if (encryptedData == null) return [];
      
      final jsonData = _decrypt(encryptedData);
      final List<dynamic> decoded = jsonDecode(jsonData);
      return decoded.map((j) => ApiKeyInfo.fromJson(j)).toList();
    } catch (e) {
      print('API Key 解密失败: $e');
      return [];
    }
  }
}
```

### 6.2 应用设置存储

使用 `shared_preferences` 存储非敏感配置。

```dart
class SettingsStorage {
  static const String _keyOutputDir = 'output_dir';
  static const String _keyOverwrite = 'overwrite';
  
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutputDir, settings.outputDirectory);
    await prefs.setBool(_keyOverwrite, settings.overwriteOriginal);
  }
  
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      outputDirectory: prefs.getString(_keyOutputDir) ?? '',
      overwriteOriginal: prefs.getBool(_keyOverwrite) ?? false,
    );
  }
}
```

### 6.3 历史记录存储（Windows FFI 支持）

使用 `sqflite_common_ffi` 在 Windows 桌面端实现 SQLite 数据库支持。

> [!IMPORTANT]
> Windows 桌面不支持标准的 `sqflite` 包，必须使用 `sqflite_common_ffi` 并进行初始化。

#### 6.3.1 初始化代码

在 `main.dart` 或应用初始化逻辑中：

```dart
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initializeDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    // 初始化 FFI 加载器
    sqfliteFfiInit();
    // 设置数据库工厂
    databaseFactory = databaseFactoryFfi;
  }
}

Future<void> main() async {
  // 确保 FFI 初始化
  initializeDatabaseFactory();
  
  runApp(const MyApp());
}
```

#### 6.3.2 数据库服务实现

```dart
class HistoryDatabase {
  static const String _tableName = 'compression_history';
  Database? _db;
  
  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tinypng_history.db');
    
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $_tableName('
          'id TEXT PRIMARY KEY, '
          'fileName TEXT, '
          'originalSize INTEGER, '
          'compressedSize INTEGER, '
          'timestamp INTEGER)'
        );
      },
    );
  }
  
  Future<void> addRecord(HistoryRecord record) async {
    await _db?.insert(
      _tableName,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<HistoryRecord>> getHistory({int limit = 100}) async {
    final maps = await _db?.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    
    if (maps == null) return [];
    return maps.map((m) => HistoryRecord.fromMap(m)).toList();
  }
}
```

---

## 7. 错误处理

### 7.1 自定义异常

```dart
abstract class AppException implements Exception {
  final String message;
  final String? details;
  
  AppException(this.message, [this.details]);
}

class ApiException extends AppException {
  final int? statusCode;
  ApiException(String message, [this.statusCode, String? details])
      : super(message, details);
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message);
}

class FileException extends AppException {
  FileException(String message) : super(message);
}

class QuotaExceededException extends ApiException {
  QuotaExceededException() 
      : super('API 配额已用完', 429, '请升级您的 TinyPNG 订阅计划');
}
```

### 7.2 错误处理器

```dart
class ErrorHandler {
  static String getUserFriendlyMessage(Exception e) {
    if (e is ApiException) {
      switch (e.statusCode) {
        case 401:
          return 'API Key 无效，请检查设置';
        case 429:
          return 'API 配额已用完';
        default:
          return 'API 请求失败: ${e.message}';
      }
    } else if (e is NetworkException) {
      return '网络连接失败，请检查网络';
    } else if (e is FileException) {
      return '文件操作失败: ${e.message}';
    }
    return '未知错误: ${e.toString()}';
  }
}
```

### 7.3 日志管理

使用 `logger` 包进行结构化日志记录，帮助调试和生产环境问题追踪。

```dart
import 'package:logger/logger.dart';

class LoggerService {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void d(String message) => _logger.d(message);
  static void i(String message) => _logger.i(message);
  static void w(String message) => _logger.w(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) => 
      _logger.e(message, error: error, stackTrace: stackTrace);
}
```

---

## 8. 性能优化

### 8.1 并发控制

**推荐方案：使用 `pool` 包**

`pool` 包提供了简单可靠的资源池管理，确保并发请求不会超过设定限制。

```dart
import 'package:pool/pool.dart';

class CompressionService {
  final Pool _pool;
  final TinyPngApi _api;
  final StreamController<CompressionProgress> _progressController;
  
  CompressionService({
    required TinyPngApi api,
    int maxConcurrent = 3,
  })  : _api = api,
        _pool = Pool(maxConcurrent),
        _progressController = StreamController.broadcast();
  
  // ... 完整实现见上文
}
```

### 8.2 内存管理

- **流式处理**: 对于大文件，使用 `Stream` 而不是一次性加载到内存。
- **及时释放**: 这里使用 `FileImage` 时，注意缓存管理。
- **分页加载**: 历史记录和列表使用分页加载，避免 UI 卡顿。

### 8.3 UI 优化

- 使用 `const` 构造函数减少 Widget 重建。
- 列表使用 `ListView.builder` 实现虚拟滚动。
- 复杂计算放在后台 Isolate 中进行（如果需要）。

---

## 9. 测试策略

### 9.1 单元测试

测试核心业务逻辑：

```dart
test('should derive correct encryption key', () {
  final storage = SecureApiKeyStorage();
  // ... 测试密钥派生逻辑
});

test('should parse compression count from headers', () {
  final api = TinyPngApi();
  // ... 测试配额解析
});
```

### 9.2 Widget 测试

测试 UI 组件的渲染和交互：

```dart
testWidgets('should display file list', (tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TasksNotifier()),
        // ... 其他必要的 mock providers
      ],
      child: MaterialApp(home: HomeScreen()),
    ),
  );
  
  expect(find.byType(FileListView), findsOneWidget);
});
```

---

## 10. 依赖包清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 网络请求
  dio: ^5.4.0
  
  # 文件选择
  file_picker: ^6.1.1
  desktop_drop: ^0.4.4
  
  # Windows 桌面支持
  window_manager: ^0.3.0  # 窗口管理
  
  # 状态管理
  provider: ^6.1.1
  
  # 本地存储
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  path_provider: ^2.1.1
  
  # 数据库（可选）
  sqflite_common_ffi: ^2.3.0
  
  # UI 组件
  cupertino_icons: ^1.0.8
  
  # 工具
  path: ^1.8.3
  uuid: ^4.3.3
  intl: ^0.19.0
  pool: ^1.5.1  # 并发控制
  
  # 安全/加密
  encrypt: ^5.0.3  # AES加密
  crypto: ^3.0.3   # SHA-256等哈希算法
  logger: ^2.0.0   # 日志管理

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.7
```

```

---

## 11. Windows 平台配置

由于本项目是 Windows 桌面应用，需要进行以下平台特定配置以确保核心功能正常工作。

### 11.1 文件拖拽支持（OLE 初始化）

`desktop_drop` 包在 Windows 上依赖 OLE（Object Linking and Embedding）。需要在 `windows/runner/main.cpp` 中初始化 OLE。

**修改文件**: `windows/runner/main.cpp`

```cpp
#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

// 添加 OLE 支持
#include <ole2.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // 初始化 OLE（必须在创建窗口之前）
  ::OleInitialize(nullptr);

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"tinypng_gui", origin, size)) {
    // 清理 OLE
    ::OleUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // 清理 OLE（程序退出时）
  ::OleUninitialize();
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
```

> [!IMPORTANT]
> 如果不添加 `OleInitialize()` 和 `OleUninitialize()`，文件拖拽功能将无法工作。

---

### 11.2 窗口管理配置

使用 `window_manager` 包可以精确控制窗口大小、位置、状态等。

**在 `main.dart` 中配置**:

```dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 配置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),           // 初始窗口大小
    minimumSize: Size(800, 600),     // 最小窗口大小
    center: true,                     // 居中显示
    backgroundColor: Colors.transparent,
    skipTaskbar: false,               // 在任务栏显示
    titleBarStyle: TitleBarStyle.normal, // 使用标准标题栏
    title: 'TinyPNG 批量压缩工具',
  );
  
  // 等待窗口准备好后再显示（避免闪烁）
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const MyApp());
}
```

**可选功能**：监听窗口事件

```dart
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 窗口关闭前的清理工作
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // 可以在这里显示确认对话框
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('确认退出'),
          content: const Text('确定要退出应用吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                windowManager.destroy();
              },
              child: const Text('退出'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TinyPNG GUI',
      home: const HomeScreen(),
    );
  }
}
```

---

### 11.3 高 DPI 支持

Windows 10/11 的高分辨率显示器需要特殊配置以避免界面模糊。

#### 11.3.1 修改 CMakeLists.txt

**文件路径**: `windows/runner/CMakeLists.txt`

确保包含以下配置：

```cmake
# 已有的配置...
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# 设置 Windows 子系统
set_target_properties(${BINARY_NAME} PROPERTIES
  WIN32_EXECUTABLE TRUE
)

# 链接库
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")

# 添加 DPI 感知支持（如果使用 MSVC）
if(MSVC)
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /MANIFESTUAC:\"level='asInvoker' uiAccess='false'\"")
endif()
```

#### 11.3.2 配置 Manifest 文件

**文件路径**: `windows/runner/Runner.exe.manifest`

确保包含 DPI 感知配置：

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity
    version="1.0.0.0"
    processorArchitecture="*"
    name="tinypng_gui"
    type="win32" />

  <!-- DPI 感知配置 -->
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <!-- Windows 7/8 兼容性 -->
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware>
      <!-- Windows 10 1607+ Per-Monitor V2 -->
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
    </windowsSettings>
  </application>

  <!-- Windows 版本兼容性 -->
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <!-- Windows 10/11 -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>
      <!-- Windows 8.1 -->
      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>
      <!-- Windows 8 -->
      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>
      <!-- Windows 7 -->
      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>
    </application>
  </compatibility>

  <dependency>
    <dependentAssembly>
      <assemblyIdentity
        type="win32"
        name="Microsoft.Windows.Common-Controls"
        version="6.0.0.0"
        processorArchitecture="*"
        publicKeyToken="6595b64144ccf1df"
        language="*" />
    </dependentAssembly>
  </dependency>
</assembly>
```

---

### 11.4 应用打包

使用 `msix` 包将应用打包为 MSIX 格式（Windows 推荐的安装包格式）。

#### 11.4.1 添加 msix 依赖

在 `pubspec.yaml` 中添加：

```yaml
dev_dependencies:
  msix: ^3.16.0
```

#### 11.4.2 配置 MSIX 打包选项

在 `pubspec.yaml` 中添加 `msix_config` 配置：

```yaml
msix_config:
  display_name: TinyPNG 批量压缩工具
  publisher_display_name: Your Name
  identity_name: com.yourcompany.tinypng_gui
  msix_version: 1.0.0.0
  logo_path: assets\images\logo.png
  capabilities: internetClient
  
  # 应用程序信息
  app_description: 基于 TinyPNG API 的批量图片压缩工具
  
  # 语言设置
  languages: zh-cn, en-us
  
  # 安装位置
  install_location: ProgramFiles
```

#### 11.4.3 准备应用图标

创建应用图标并放置在项目中：

```
assets/
  images/
    logo.png       # 至少 400x400 像素
    icon.ico       # Windows 图标文件
```

在 `windows/runner/Runner.rc` 中引用图标：

```rc
IDI_APP_ICON ICON "resources\\app_icon.ico"
```

#### 11.4.4 打包命令

**构建 Release 版本**:
```bash
flutter build windows --release
```

**创建 MSIX 安装包**:
```bash
flutter pub run msix:create
```

生成的 MSIX 文件位于：`build\windows\runner\Release\tinypng_gui.msix`

#### 11.4.5 分发方式

1. **直接分发 MSIX 文件**
   - 用户双击安装（需要开启开发者模式或证书信任）
   
2. **发布到 Microsoft Store**
   - 需要注册开发者账户
   - 审核后可在应用商店分发

3. **便携版本（Portable）**
   - 直接分发 `build\windows\runner\Release` 文件夹
   - 解压即用，无需安装

> [!NOTE]
> 本文档不包含代码签名相关配置。如需发布生产版本，建议申请代码签名证书以避免 Windows SmartScreen 警告。

---

### 11.5 平台检查

在代码中检查当前平台：

```dart
import 'dart:io' show Platform;

void initializePlatformSpecific() {
  if (Platform.isWindows) {
    // Windows 特定初始化
    print('运行在 Windows 平台');
  } else if (Platform.isMacOS) {
    // macOS 特定初始化（未来支持）
    print('运行在 macOS 平台');
  } else if (Platform.isLinux) {
    // Linux 特定初始化（未来支持）
    print('运行在 Linux 平台');
  }
}
```

---

## 12. 开发规范

### 12.1 代码规范
- 遵循 Dart 官方代码风格
- 使用 `flutter_lints` 进行代码检查
- 所有公共 API 必须有文档注释

### 12.2 Git 提交规范
```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式调整
refactor: 重构
test: 测试相关
chore: 构建/工具相关
```

### 12.3 分支管理
- `main`: 主分支（稳定版本）
- `develop`: 开发分支
- `feature/*`: 功能分支
- `bugfix/*`: 修复分支

---

**文档版本**: 1.0  
**创建日期**: 2026-01-15  
**最后更新**: 2026-01-15
