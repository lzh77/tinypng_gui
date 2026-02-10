# TinyPNG GUI - 编码实施计划

## 1. 项目概述

根据需求文档([requirements.md](file:///c:/code/tinypng_gui/docs/requirements.md))和架构文档([architecture.md](file:///c:/code/tinypng_gui/docs/architecture.md))，本项目是一个基于Flutter的桌面应用程序，用于批量压缩图片，调用TinyPNG API进行图片压缩，初期支持Windows平台。

## 2. 开发阶段规划

### 2.1 第一阶段（MVP - 核心功能实现）

#### 2.1.1 核心基础设施
- [ ] 创建项目结构（按照架构文档的目录结构）
- [ ] 配置Flutter项目，确保Windows桌面支持
- [ ] 添加必要依赖（按架构文档中的依赖包清单）
- [ ] 实现基本的应用入口([main.dart](file:///c:/code/tinypng_gui/lib/main.dart))
- [ ] 配置窗口管理（最小/推荐尺寸、高DPI支持）

#### 2.1.2 数据模型层
- [x] 实现[CompressionTask](file:///c:/code/tinypng_gui/lib/data/models/compression_task.dart)和[CompressionStatus](file:///c:/code/tinypng_gui/lib/core/enums/compression_status.dart)
- [x] 实现[ApiKeyInfo](file:///c:/code/tinypng_gui/lib/data/models/api_key_info.dart)和[ApiKeyStatus](file:///c:/code/tinypng_gui/lib/core/enums/api_key_status.dart)
- [x] 实现[AppSettings](file:///c:/code/tinypng_gui/lib/data/models/app_settings.dart)
- [x] 实现[CompressionResultData](file:///c:/code/tinypng_gui/lib/data/models/compression_result_data.dart)

#### 2.1.3 数据层实现
- [x] 实现[TinyPngApi](file:///c:/code/tinypng_gui/lib/services/compression_service.dart#L34-L144)类，包含压缩、验证等功能
- [x] 实现API Key安全存储（flutter_secure_storage + AES-256加密）
- [x] 实现应用设置存储（shared_preferences）
- [ ] 实现HistoryDatabase（sqflite_common_ffi）

#### 2.1.4 服务层实现
- [x] 实现[FileService](file:///c:/code/tinypng_gui/lib/services/file_service.dart)（文件选择、路径处理、输出路径生成）
- [ ] 实现[ApiKeyService](file:///c:/code/tinypng_gui/lib/services/compression_service.dart#L34-L144)（API Key管理、验证、轮换）
- [ ] 实现[CompressionService](file:///c:/code/tinypng_gui/lib/services/compression_service.dart)（压缩单个/批量文件、Key轮换）
- [ ] 实现[QueueService](file:///c:/code/tinypng_gui/lib/services/queue_service.dart)（任务队列管理、并发控制）

#### 2.1.5 异常处理
- [ ] 实现所有自定义异常（ApiException、NetworkException等）
- [ ] 实现ErrorHandler错误处理器
- [ ] 实现LoggerService日志服务

#### 2.1.6 状态管理层（Provider）
- [x] 实现TasksNotifier（任务状态管理）
- [x] 实现SettingsNotifier（设置状态管理）
- [x] 实现QueueStatusNotifier（队列状态管理）

#### 2.1.7 基础UI界面
- [ ] 创建Provider状态管理配置
- [ ] 实现主界面框架([HomeScreen](file:///c:/code/tinypng_gui/lib/presentation/screens/home/home_screen.dart))
- [ ] 实现API Key管理界面
- [ ] 实现文件选择功能（单个/多个文件）
- [ ] 实现文件列表显示（FileListView和FileListItem）
- [ ] 实现压缩功能按钮和进度显示
- [ ] 实现统计面板（StatisticsPanel）
- [ ] 实现基本设置界面

### 2.2 第二阶段（完整功能实现 - 按架构文档补充）

#### 2.2.1 完善UI组件
- [ ] 实现所有屏幕（Home、Settings、History）
- [ ] 实现所有设置选项卡/分组
- [ ] 实现拖拽功能（desktop_drop）
- [ ] 实现历史记录查看界面

#### 2.2.2 完善业务逻辑
- [ ] 实现并发压缩控制（使用pool包）
- [ ] 实现失败重试机制
- [ ] 实现自动轮换API Key
- [ ] 实现配额管理

#### 2.2.3 完善数据持久化
- [ ] 实现完整的API Key加密存储机制
- [ ] 实现历史记录存储
- [ ] 实现应用设置存储

#### 2.2.4 完善错误处理
- [ ] 实现完整的错误处理和用户提示
- [ ] 实现错误日志记录

### 2.3 第三阶段（平台特定配置和优化）

#### 2.3.1 Windows平台配置
- [ ] 配置OLE支持（[windows/runner/main.cpp](file:///c:/code/tinypng_gui/windows/runner/main.cpp)中添加OleInitialize）
- [ ] 实现窗口管理功能（大小、状态、事件处理）
- [ ] 配置高DPI支持（manifest文件）
- [ ] 实现应用打包（MSIX格式）

#### 2.3.2 测试
- [ ] 实现所有单元测试
- [ ] 实现所有Widget测试
- [ ] 实现集成测试

## 3. 核心组件实现顺序

### 3.1 数据层实现
1. **数据模型** ([data/models](file:///c:/code/tinypng_gui/lib/data/models))
   - [ApiKeyInfo](file:///c:/code/tinypng_gui/lib/data/models/api_key_info.dart) - API Key信息模型
   - [CompressionTask](file:///c:/code/tinypng_gui/lib/data/models/compression_task.dart) - 压缩任务模型
   - [AppSettings](file:///c:/code/tinypng_gui/lib/data/models/app_settings.dart) - 应用设置模型
   - [CompressionResultData](file:///c:/code/tinypng_gui/lib/data/models/compression_result_data.dart) - 压缩结果数据模型

2. **数据源** ([data/datasources](file:///c:/code/tinypng_gui/lib/data/datasources))
   - [TinyPngApi](file:///c:/code/tinypng_gui/lib/services/compression_service.dart#L34-L144) - API接口实现
   - 本地存储实现（设置、历史记录）

### 3.2 业务逻辑层实现
1. **服务层** ([services](file:///c:/code/tinypng_gui/lib/services))
   - [FileService](file:///c:/code/tinypng_gui/lib/services/file_service.dart) - 文件操作服务
   - [ApiKeyService](file:///c:/code/tinypng_gui/lib/services/compression_service.dart#L34-L144) - API Key管理服务
   - [CompressionService](file:///c:/code/tinypng_gui/lib/services/compression_service.dart) - 压缩核心服务
   - [QueueService](file:///c:/code/tinypng_gui/lib/services/queue_service.dart) - 队列管理服务

2. **异常处理**
   - 实现所有自定义异常类
   - 实现错误处理器
   - 实现日志服务

### 3.3 表示层实现
1. **状态管理** ([providers](file:///c:/code/tinypng_gui/lib/providers))
   - [x] TasksNotifier - 任务状态管理
   - [x] SettingsNotifier - 设置状态管理
   - [x] QueueStatusNotifier - 队列状态管理

2. **UI组件** ([widgets](file:///c:/code/tinypng_gui/lib/widgets))
   - FileListItem - 文件列表项组件
   - ProgressBar - 进度条组件
   - StatisticsPanel - 统计面板组件

3. **页面** ([screens](file:///c:/code/tinypng_gui/lib/screens))
   - HomeScreen - 主页面
   - SettingsScreen - 设置页面
   - HistoryScreen - 历史记录页面

## 4. 关键技术实现要点

### 4.1 API Key安全存储
- 使用flutter_secure_storage + AES-256双重加密
- 基于设备ID生成加密密钥
- Windows凭据管理器系统级保护

### 4.2 并发控制实现
- 使用pool包实现并发控制
- 确保同时进行的任务数不超过设定值

### 4.3 Windows平台特定配置
- 在[windows/runner/main.cpp](file:///c:/code/tinypng_gui/windows/runner/main.cpp)中添加OleInitialize()以支持文件拖拽
- 配置高DPI感知支持
- 设置窗口管理选项

## 5. 测试计划

### 5.1 单元测试
- [ ] 数据模型测试
- [ ] 服务层单元测试
- [ ] API Key加密存储测试
- [ ] 并发控制测试

### 5.2 Widget测试
- [ ] 主界面渲染测试
- [ ] 文件列表交互测试
- [ ] 设置页面测试

## 6. 依赖项清单

根据架构文档，主要依赖如下：

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

- **第一阶段**: 第1-3周完成（核心功能跑通）
- **第二阶段**: 第4-5周完成（完整功能）
- **第三阶段**: 第6周完成（平台配置和测试）