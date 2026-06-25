# TinyPNG GUI - 编码实施计划

## 1. 项目概述

根据需求文档([requirements.md](file:///c:/code/tinypng_gui/docs/requirements.md))和架构文档([architecture.md](file:///c:/code/tinypng_gui/docs/architecture.md))，本项目是一个基于Flutter的桌面应用程序，用于批量压缩图片，调用TinyPNG API进行图片压缩，初期支持Windows平台。

## 2. 开发阶段规划

> **进度核对日期**：2026-06-25（以 `lib/` 源码为准；`[x]` 表示已完成，`[ ]` 表示未完成或仅有部分实现，括号内为说明）

### 2.1 第一阶段（MVP - 核心功能实现）

#### 2.1.1 核心基础设施
- [x] 创建项目结构（按架构文档的 `data/`、`services/`、`providers/`、`screens/` 分层已实现；`core/`、`domain/`、`presentation/` 等规划目录未建）
- [x] 配置Flutter项目，确保Windows桌面支持
- [x] 添加必要依赖（按架构文档中的依赖包清单，`pubspec.yaml` 已配置）
- [x] 实现基本的应用入口([main.dart](file:///c:/code/tinypng_gui/lib/main.dart))
- [x] 配置窗口管理（最小/推荐尺寸、高DPI支持；`window_manager` + `runner.exe.manifest`）

#### 2.1.2 数据模型层
- [x] 实现[CompressionTask](file:///c:/code/tinypng_gui/lib/data/models/compression_task.dart)和 CompressionStatus（枚举定义于模型文件内，非独立 `core/enums/`）
- [x] 实现[ApiKeyInfo](file:///c:/code/tinypng_gui/lib/data/models/api_key_info.dart)和 ApiKeyStatus（枚举定义于模型文件内）
- [x] 实现[AppSettings](file:///c:/code/tinypng_gui/lib/data/models/app_settings.dart)
- [x] 实现[CompressionResultData](file:///c:/code/tinypng_gui/lib/data/models/compression_result_data.dart)

#### 2.1.3 数据层实现
- [x] 实现[TinyPngApi](file:///c:/code/tinypng_gui/lib/data/datasources/remote/tinypng_api.dart)类，包含压缩、验证等功能
- [x] 实现API Key安全存储（[SecureApiKeyStorage](file:///c:/code/tinypng_gui/lib/data/datasources/local/secure_api_key_storage.dart)：flutter_secure_storage + AES-256加密）
- [x] 实现应用设置存储（[SettingsLocalDataSource](file:///c:/code/tinypng_gui/lib/data/datasources/local/settings_local_data_source.dart)：shared_preferences）
- [ ] 实现HistoryDatabase（sqflite_common_ffi 已在 `main.dart` 初始化，无数据库读写实现）

#### 2.1.4 服务层实现
- [x] 实现[FileService](file:///c:/code/tinypng_gui/lib/services/file_service.dart)（文件选择、路径处理、输出路径生成）
- [x] 实现[ApiKeyService](file:///c:/code/tinypng_gui/lib/services/api_key_service.dart)（API Key管理、验证、轮换）
- [x] 实现[CompressionService](file:///c:/code/tinypng_gui/lib/services/compression_service.dart)（压缩单个任务、Key轮换）
- [x] 实现[QueueService](file:///c:/code/tinypng_gui/lib/services/queue_service.dart)（任务队列管理、并发控制）

#### 2.1.5 异常处理
- [x] 实现所有自定义异常（ApiException、NetworkException 等，定义于 [tinypng_api.dart](file:///c:/code/tinypng_gui/lib/data/datasources/remote/tinypng_api.dart)）
- [ ] 实现ErrorHandler错误处理器（架构文档规划类，当前未实现）
- [x] 实现[LoggerService](file:///c:/code/tinypng_gui/lib/services/logger_service.dart)日志服务

#### 2.1.6 状态管理层（Provider）
- [x] 实现TasksNotifier（任务状态管理）
- [x] 实现SettingsNotifier（设置状态管理）
- [x] 实现QueueStatusNotifier（队列状态管理）

#### 2.1.7 基础UI界面
- [x] 创建Provider状态管理配置（[main.dart](file:///c:/code/tinypng_gui/lib/main.dart) 中 `MultiProvider` + `ProxyProvider` 依赖链）
- [x] 实现主界面框架([HomeScreen](file:///c:/code/tinypng_gui/lib/screens/home/home_screen.dart))
- [x] 实现API Key管理界面（[ApiKeySection](file:///c:/code/tinypng_gui/lib/screens/settings/widgets/api_key_section.dart)；经 [ApiKeyNotifier](file:///c:/code/tinypng_gui/lib/providers/api_key_notifier.dart) 与安全存储打通，添加时调用 `validateKey`）
- [x] 实现文件选择功能（单个/多个文件）（[ActionToolbar](file:///c:/code/tinypng_gui/lib/screens/home/widgets/action_toolbar.dart)；缺 `avif` 扩展名、文件夹仅扫描顶层、未传 `baseDir`）
- [x] 实现文件列表显示（[FileListItem](file:///c:/code/tinypng_gui/lib/screens/home/widgets/file_list_item.dart)；`HomeScreen` 内联 `ListView.builder`，无独立 FileListView 组件）
- [x] 实现压缩功能按钮和进度显示（[QueueControlButtons](file:///c:/code/tinypng_gui/lib/screens/home/widgets/queue_control_buttons.dart)）
- [x] 实现统计面板（[StatisticsPanel](file:///c:/code/tinypng_gui/lib/screens/home/widgets/statistics_panel.dart)）
- [x] 实现基本设置界面（[SettingsScreen](file:///c:/code/tinypng_gui/lib/screens/settings/settings_screen.dart)：API Key / 压缩 / 输出 / 外观四区块）

### 2.2 第二阶段（完整功能实现 - 按架构文档补充）

#### 2.2.1 完善UI组件
- [ ] 实现所有屏幕（Home ✅、Settings ✅、History ❌）
- [x] 实现所有设置选项卡/分组（四区块已完成；`language` 字段无对应 UI，未接入国际化）
- [ ] 实现拖拽功能（`desktop_drop` 已声明依赖且 OLE 已初始化，`lib/` 中未使用）
- [ ] 实现历史记录查看界面（`HomeScreen` 历史按钮为 TODO SnackBar）

#### 2.2.2 完善业务逻辑
- [x] 实现并发压缩控制（[QueueService](file:///c:/code/tinypng_gui/lib/services/queue_service.dart) 使用 `pool`；`QueueStatusNotifier.start()` 启动前同步 `concurrentLimit`）
- [x] 实现失败重试机制（`CompressionService` 按 `retryCount` 重试网络错误与 5xx）
- [x] 实现自动轮换API Key（`CompressionService._compressWithKeyRotation` + `autoRotateKeys`）
- [ ] 实现配额管理（服务层有 `updateKeyUsage`；设置页已读安全存储，压缩中用量不会实时刷新）

#### 2.2.3 完善数据持久化
- [x] 实现完整的API Key加密存储机制（`SecureApiKeyStorage` + `ApiKeyService` + `ApiKeyNotifier`；`AppSettings.toJson` 不再持久化明文 Key）
- [ ] 实现历史记录存储
- [x] 实现应用设置存储（`SettingsLocalDataSource` 已实现；`main.dart` 启动时调用 `loadSettings()`）

#### 2.2.4 完善错误处理
- [ ] 实现完整的错误处理和用户提示（异常映射已有；无集中 `ErrorHandler`；UI 以 SnackBar / 任务 `errorMessage` 为主）
- [x] 实现错误日志记录（`LoggerService` 已在服务层与 UI 中使用）

### 2.3 第三阶段（平台特定配置和优化）

#### 2.3.1 Windows平台配置
- [x] 配置OLE支持（[windows/runner/main.cpp](file:///c:/code/tinypng_gui/windows/runner/main.cpp) 中已添加 `OleInitialize`）
- [x] 实现窗口管理功能（`window_manager`：1024×768、最小 800×600、居中显示）
- [x] 配置高DPI支持（[runner.exe.manifest](file:///c:/code/tinypng_gui/windows/runner/runner.exe.manifest)：`PerMonitorV2`）
- [ ] 实现应用打包（MSIX格式；仅架构文档有说明，`pubspec.yaml` 无 `msix` 配置）

#### 2.3.2 测试
- [ ] 实现所有单元测试（部分已有：TinyPngApi、SecureApiKeyStorage、SettingsLocalDataSource、QueueService、FileService、TasksNotifier、SettingsNotifier、QueueStatusNotifier）
- [ ] 实现所有Widget测试（仅 [widget_test.dart](file:///c:/code/tinypng_gui/test/widget_test.dart) 验证 App 初始化）
- [ ] 实现集成测试

## 3. 核心组件实现顺序

### 3.1 数据层实现
1. **数据模型** ([data/models](file:///c:/code/tinypng_gui/lib/data/models))
   - [x] [ApiKeyInfo](file:///c:/code/tinypng_gui/lib/data/models/api_key_info.dart) - API Key信息模型
   - [x] [CompressionTask](file:///c:/code/tinypng_gui/lib/data/models/compression_task.dart) - 压缩任务模型
   - [x] [AppSettings](file:///c:/code/tinypng_gui/lib/data/models/app_settings.dart) - 应用设置模型
   - [x] [CompressionResultData](file:///c:/code/tinypng_gui/lib/data/models/compression_result_data.dart) - 压缩结果数据模型

2. **数据源** ([data/datasources](file:///c:/code/tinypng_gui/lib/data/datasources))
   - [x] [TinyPngApi](file:///c:/code/tinypng_gui/lib/data/datasources/remote/tinypng_api.dart) - API接口实现
   - [x] 本地设置存储（SettingsLocalDataSource + SecureApiKeyStorage）
   - [ ] 历史记录存储（HistoryDatabase 未实现）

### 3.2 业务逻辑层实现
1. **服务层** ([services](file:///c:/code/tinypng_gui/lib/services))
   - [x] [FileService](file:///c:/code/tinypng_gui/lib/services/file_service.dart) - 文件操作服务
   - [x] [ApiKeyService](file:///c:/code/tinypng_gui/lib/services/api_key_service.dart) - API Key管理服务
   - [x] [CompressionService](file:///c:/code/tinypng_gui/lib/services/compression_service.dart) - 压缩核心服务
   - [x] [QueueService](file:///c:/code/tinypng_gui/lib/services/queue_service.dart) - 队列管理服务

2. **异常处理**
   - [x] 实现所有自定义异常类（tinypng_api.dart）
   - [ ] 实现错误处理器（ErrorHandler）
   - [x] 实现日志服务（LoggerService）

### 3.3 表示层实现
1. **状态管理** ([providers](file:///c:/code/tinypng_gui/lib/providers))
   - [x] TasksNotifier - 任务状态管理
   - [x] SettingsNotifier - 设置状态管理
   - [x] QueueStatusNotifier - 队列状态管理

2. **UI组件**（位于各 screen 的 `widgets/` 子目录，非独立 `lib/widgets/`）
   - [x] FileListItem - 文件列表项组件
   - [x] 进度显示 - QueueControlButtons 内 `LinearProgressIndicator`（无独立 ProgressBar 组件）
   - [x] StatisticsPanel - 统计面板组件

3. **页面** ([screens](file:///c:/code/tinypng_gui/lib/screens))
   - [x] HomeScreen - 主页面
   - [x] SettingsScreen - 设置页面
   - [ ] HistoryScreen - 历史记录页面

## 4. 关键技术实现要点

### 4.1 API Key安全存储
- [x] 使用flutter_secure_storage + AES-256双重加密（SecureApiKeyStorage）
- [x] 基于设备ID生成加密密钥
- [x] Windows凭据管理器系统级保护
- [x] UI 与 ApiKeyService 打通（ApiKeyNotifier + 启动迁移旧版 SharedPreferences Key）

### 4.2 并发控制实现
- [x] 使用pool包实现并发控制（QueueService）
- [x] 确保同时进行的任务数不超过设定值（启动队列前从设置同步 `concurrentLimit`）

### 4.3 Windows平台特定配置
- [x] 在[windows/runner/main.cpp](file:///c:/code/tinypng_gui/windows/runner/main.cpp)中添加OleInitialize()以支持文件拖拽
- [x] 配置高DPI感知支持
- [x] 设置窗口管理选项
- [ ] desktop_drop 拖拽导入（Dart 侧未实现）

## 5. 测试计划

### 5.1 单元测试
- [x] 数据模型测试（`app_settings_test`、`compression_task_test`）
- [x] 服务层单元测试（FileService、QueueService、ApiKeyService、CompressionService）
- [x] API Key加密存储测试（secure_api_key_storage_test.dart）
- [x] 并发控制测试（queue_service_test.dart）
- [x] TinyPngApi 测试（tinypng_api_test.dart）
- [x] Provider 测试（tasks_notifier、settings_notifier、queue_status_notifier、api_key_notifier）
- [x] 设置数据源测试（settings_local_data_source_test.dart）

### 5.2 Widget测试
- [x] 基础 App 初始化测试（widget_test.dart）
- [ ] 主界面渲染测试
- [ ] 文件列表交互测试
- [ ] 设置页面测试

## 6. 依赖项清单

根据架构文档，主要依赖如下（均已加入 [pubspec.yaml](file:///c:/code/tinypng_gui/pubspec.yaml)）：

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # 网络请求
  dio: ^5.4.0
  
  # 文件选择
  file_picker: ^6.1.1
  desktop_drop: ^0.4.4
  
  # 窗口管理
  window_manager: ^0.3.0
  
  # 状态管理
  provider: ^6.1.1
  
  # 本地存储
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0
  path_provider: ^2.1.1
  
  # 数据库（Windows）
  sqflite_common_ffi: ^2.3.0
  
  # UI组件
  cupertino_icons: ^1.0.8
  
  # 工具
  path: ^1.8.3
  uuid: ^4.3.3
  intl: ^0.19.0
  pool: ^1.5.1
  
  # 安全/加密
  encrypt: ^5.0.3
  crypto: ^3.0.3
  logger: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

## 7. 里程碑

- **第一阶段**: 第1-3周完成（核心功能跑通）— **主体已完成**，遗留：文件导入细节（`avif`、递归、`baseDir`）
- **第二阶段**: 第4-5周完成（完整功能）— **进行中**，历史记录、拖拽、重试、设置贯通等待完成
- **第三阶段**: 第6周完成（平台配置和测试）— Windows 运行时配置基本完成；MSIX 打包与测试体系待完善

## 8. 已知集成缺口（2026-06 核对）

修改相关代码前请参考，完整说明见 `.cursor/rules/known-gaps.mdc`：

1. ~~**API Key 双轨存储**~~：已通过 `ApiKeyNotifier` 打通（2026-06-25）
2. ~~**启动未调用 `loadSettings()`**~~：已在 `MainApp._bootstrap()` 中调用（2026-06-25）
3. ~~**`concurrentLimit` / `retryCount`**~~：已接入队列与压缩服务（2026-06-25）
4. **历史记录**：UI、数据库、页面均未实现
5. **拖拽导入**：`desktop_drop` 依赖已添加，`lib/` 未使用
