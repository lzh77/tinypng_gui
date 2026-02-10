# TinyPNG GUI 批量图片压缩工具 - 需求文档

## 1. 项目概述

### 1.1 项目背景
本项目旨在开发一个基于 Flutter 的桌面应用程序，用于批量压缩图片。应用程序将调用 [TinyPNG API](https://tinypng.com/developers) 进行图片压缩，初期仅支持 Windows 平台。

### 1.2 项目目标
- 提供简洁易用的图形界面
- 支持批量选择和压缩图片
- 实时显示压缩进度和结果
- 提供压缩统计信息（原始大小、压缩后大小、压缩率等）
- 支持多种图片格式（AVIF, WebP, JPEG, PNG）

### 1.3 技术栈
- **框架**: Flutter (Dart)
- **目标平台**: Windows Desktop
- **API**: TinyPNG Developer API
- **最低 Flutter SDK**: 3.10.7

---

## 2. 功能需求

### 2.1 核心功能

#### 2.1.1 API Key 管理
- **功能描述**: 用户需要配置 TinyPNG API Key 才能使用压缩功能
- **具体要求**:
  - 支持配置多个 API Key（每个 Key 可设置别名）
  - 支持 API Key 的添加、编辑、删除
  - 本地加密存储所有 API Key
  - 验证每个 API Key 的有效性
  - 显示每个 API Key 的使用配额（已压缩图片数量/总配额）
  - 支持设置默认 API Key
  - 支持自动轮换使用多个 API Key（当一个 Key 配额用完时自动切换到下一个）
  - 显示所有 API Key 的状态（可用/配额已满/无效）
  - 支持手动选择使用哪个 API Key 进行压缩

#### 2.1.2 文件选择
- **功能描述**: 用户可以选择需要压缩的图片文件
- **具体要求**:
  - 支持单个文件选择
  - 支持多个文件批量选择
  - 支持文件夹选择（递归扫描子文件夹）
  - 支持拖拽文件/文件夹到应用窗口
  - 自动过滤支持的图片格式（.jpg, .jpeg, .png, .webp, .avif）
  - 显示文件列表，包含：
    - 文件名
    - 文件路径
    - 原始大小
    - 文件类型
    - 状态（等待/压缩中/完成/失败）

#### 2.1.2 图片压缩核心功能
- **功能描述**: 调用 TinyPNG API 压缩图片
- **具体要求**:
  - **两步压缩流程**:
    1. 上传原图到 API 进行压缩
    2. 从返回的 URL 下载压缩后的图片
  - **配额管理**:
    - 每次请求后从 HTTP 响应头 `Compression-Count` 读取当月已用配额
    - 实时更新界面显示的已用数量
  - **原数据保留**: 支持保留 Exif 信息（版权、创建日期、GPS位置等）
  - **格式支持**: 支持 WebP、JPEG 和 PNG 自动转换

#### 2.1.3 批量压缩
- **功能描述**: 批量处理选中的图片文件
- **具体要求**:
  - 支持一键开始批量压缩
  - 支持暂停/继续压缩任务
  - 支持取消压缩任务
  - 支持移除列表中的文件
  - 支持清空文件列表
  - **并发控制**:
    - 可配置同时压缩的文件数量（默认 3 个，范围 1-10）
    - 使用任务队列管理待压缩文件
    - 动态调度：完成一个任务后自动从队列中取下一个
    - 并发限制：确保同时运行的任务数不超过设定值
    - 资源管理：合理分配网络连接和内存资源
    - 队列状态显示：
      - 正在压缩：X 个
      - 队列等待：Y 个
      - 已完成：Z 个
  - 失败重试机制（可配置重试次数，默认 3 次）
  - 智能重试：
    - 网络错误自动重试
    - API 限流错误延迟后重试
    - 文件错误不重试，直接标记失败

#### 2.1.4 进度显示
- **功能描述**: 实时显示压缩进度和状态
- **具体要求**:
  - 总体进度条（已完成/总数）
  - 单个文件压缩状态指示
  - 实时显示压缩速度（文件/秒）
  - 预计剩余时间
  - 成功/失败数量统计

#### 2.1.5 结果展示
- **功能描述**: 显示压缩结果和统计信息
- **具体要求**:
  - 每个文件的压缩结果：
    - 原始大小
    - 压缩后大小
    - 压缩率（百分比）
    - 状态（成功/失败）
  - 总体统计：
    - 总文件数
    - 成功/失败数量
    - 总原始大小
    - 总压缩后大小
    - 平均压缩率
    - 节省的空间

#### 2.1.6 文件保存
- **功能描述**: 保存压缩后的图片
- **具体要求**:
  - 支持覆盖原文件
  - 支持保存到指定目录
  - 支持自定义文件命名规则（如添加后缀 `_compressed`）
  - 保持原始文件夹结构（批量处理文件夹时）
  - 压缩失败时保留原文件

### 2.2 辅助功能

#### 2.2.1 设置选项
- **功能描述**: 提供应用程序配置选项
- **具体要求**:
  - API Key 管理
  - 输出目录设置
  - 文件命名规则设置
  - **并发压缩数量设置**:
    - 可设置范围：1-10 个并发任务
    - 默认值：3 个并发任务
    - 说明：同时进行压缩的文件数量，数值越大压缩速度越快，但会占用更多网络带宽和系统资源
    - UI 控件：滑块（Slider）或数字输入框
    - 实时生效：修改后立即应用于新的压缩任务
    - 性能提示：根据网络状况和系统性能建议合适的并发数
      - 网络较慢：建议 1-3
      - 网络正常：建议 3-5
      - 网络较快：建议 5-10
  - 重试次数设置（0-5）
  - 是否覆盖原文件选项
  - 语言设置（中文/英文）

#### 2.2.2 历史记录
- **功能描述**: 记录压缩历史
- **具体要求**:
  - 保存最近的压缩任务记录
  - 显示压缩时间、文件数量、压缩率等信息
  - 支持清空历史记录

#### 2.2.3 帮助与反馈
- **功能描述**: 提供用户帮助信息
- **具体要求**:
  - 使用说明
  - API Key 获取指引
  - 常见问题解答
  - 关于页面（版本信息、开源协议等）

---

## 3. 非功能需求

### 3.1 性能要求
- 应用启动时间 < 3 秒
- 单个文件压缩响应时间取决于网络和文件大小
- 支持至少 1000 个文件的批量处理
- 内存占用 < 500MB（处理大量文件时）

### 3.2 可用性要求
- 界面简洁直观，符合 Windows 设计规范
- 支持键盘快捷键操作
- 提供清晰的错误提示信息
- 支持中英文界面

### 3.3 安全性要求

**API Key 安全存储**:
- 使用 AES-256 加密算法对 API Key 进行加密后存储
- 加密后的数据通过 Windows 凭据管理器进行系统级保护
- 加密密钥基于设备唯一标识符生成，无法在其他设备上解密

> [!WARNING]
> **安全级别说明**：
> - Windows 凭据管理器提供系统级别的访问控制
> - 具有管理员权限的程序可能访问凭据管理器
> - 本应用使用额外的 AES 加密层增强安全性
> 
> **安全建议**：
> - 定期更换 API Key（建议每 3-6 个月）
> - 使用具有访问限制的付费 API Key
> - 不要在共享计算机或不可信环境中使用
> - 为 TinyPNG 账户启用访问限制（如 IP 白名单）

**其他安全措施**:
- 不上传或泄露用户文件信息
- 使用 HTTPS 与 TinyPNG API 通信
- 所有网络请求使用 TLS 1.2 或更高版本
- 本地不保存用户图片的压缩前后快照

### 3.4 兼容性要求
- 支持 Windows 10 及以上版本
- 支持高 DPI 显示屏
- 支持深色/浅色主题

---

## 4. TinyPNG API 限制

### 4.1 API 配额
- 免费账户：每月 500 次压缩
- 付费账户：根据订阅计划不同

### 4.2 文件限制
- 最大文件大小：500MB
- 最大画布尺寸：256MP（宽度或高度最大 32000 像素）

### 4.3 支持格式
- AVIF
- WebP
- JPEG
- PNG

### 4.4 API 认证
- 使用 HTTP Basic Auth
- 格式：`Authorization: Basic base64(api:YOUR_API_KEY)`
- 必须使用 HTTPS 连接

---

## 5. 用户界面设计要求

### 5.1 主窗口布局
```
+--------------------------------------------------+
|  TinyPNG 批量压缩工具                    [- □ ×] |
+--------------------------------------------------+
|  [选择文件] [选择文件夹] [清空列表]  [设置]      |
|  [清理失败] [重试失败] (批量操作)                |
+--------------------------------------------------+
|  文件列表区域                                     |
|  +--------------------------------------------+  |
|  | [x] 文件名 | 大小 | 压缩后 | 压缩率 | 状态 |  |
|  |------------|------|--------|--------|------|  |
|  | ...        | ...  | ...    | ...    | ...  |  |
|  +--------------------------------------------+  |
+--------------------------------------------------+
|  总体进度: [==================] 75% (15/20)      |
|  正在压缩: 3 | 队列等待: 2 | 已完成: 15           |
|  原始大小: 50MB | 压缩后: 25MB | 节省: 50%        |
+--------------------------------------------------+
|  [开始压缩] [暂停] [取消]                         |
+--------------------------------------------------+
```

### 5.2 设置界面
设置界面应包含以下几个标签页或分组：

#### 5.2.1 API Key 配置
- API Key 列表显示
- 添加/编辑/删除按钮
- 验证和配额显示

#### 5.2.2 压缩设置
+--------------------------------------------------+
|  压缩设置                                         |
+--------------------------------------------------+
|  并发压缩数量:                                    |
|  [====●=====] 3                                  |
|  1 ←                                        → 10  |
|  说明: 同时压缩 3 个文件                          |
|  💡 建议: 网络正常建议 3-5 个并发                 |
+--------------------------------------------------+
|  [ ] 调整图片大小 (Resize)                        |
|      宽度: [    ] px   高度: [    ] px            |
|      模式: (o) Scale ( ) Fit ( ) Cover            |
|  [ ] 转换格式 (Convert)                           |
|      目标格式: [ 保持原样 ▼ ]                     |
|                WebP                              |
|                JPEG                              |
|                PNG                               |
+--------------------------------------------------+
|  失败重试次数:                                    |
|  [==●========] 3                                 |
|  0 ←                                        → 5   |
+--------------------------------------------------+

#### 5.2.3 输出选项
- 输出目录选择
- 文件命名规则
- 是否覆盖原文件

#### 5.2.4 高级选项
- 语言设置
- 主题设置
- 日志级别

### 5.3 配色方案
- 遵循 Material Design 或 Fluent Design
- 支持浅色/深色主题
- 状态颜色：
  - 等待：灰色
  - 压缩中：蓝色
  - 成功：绿色
  - 失败：红色

---

## 6. 数据存储

### 6.1 配置文件
- 存储位置：用户应用数据目录
- 格式：JSON
- 内容：
  - API Key（加密）
  - 用户设置
  - 最近使用的目录

### 6.2 历史记录
- 存储位置：用户应用数据目录
- 格式：SQLite 或 JSON
- 内容：
  - 压缩时间
  - 文件列表
  - 压缩统计

---

## 7. 错误处理

### 7.1 网络错误
- 无网络连接
- API 请求超时
- API 服务不可用

### 7.2 API 错误
- API Key 无效
- 配额已用完
- 文件格式不支持
- 文件大小超限

### 7.3 文件错误
- 文件不存在
- 文件无法读取
- 文件无法写入
- 磁盘空间不足

### 7.4 错误提示
- 所有错误都应有清晰的中文提示
- 提供解决方案建议
- 记录错误日志

---

## 8. 开发阶段规划

### 8.1 第一阶段（MVP）
- API Key 管理
- 基本文件选择（单个/多个文件）
- 基本压缩功能
- 简单的进度显示
- 结果展示

### 8.2 第二阶段
- 文件夹批量处理
- 拖拽功能
- 并发控制
- 暂停/继续功能
- 设置界面

### 8.3 第三阶段
- 历史记录
- 高级设置
- 主题切换
- 多语言支持
- 性能优化

---

## 9. 技术实现要点

### 9.1 推荐的 Flutter 包
- `http` 或 `dio`: HTTP 请求（推荐 `dio`，功能更强大）
- `file_picker`: 文件选择
- `path_provider`: 获取应用目录
- `shared_preferences`: 简单配置存储
- `sqflite_common_ffi`: 历史记录存储（Windows 桌面必须使用 ffi 版本）
- `flutter_secure_storage`: API Key 加密存储
- **`provider`**: 状态管理（选择 Provider 6.x，稳定且易于上手）
- `desktop_drop`: 拖拽支持
- `logger`: 日志管理（用于调试和问题追踪）

> [!NOTE]
> **状态管理方案选择**：本项目使用 **Provider** 而非 Riverpod。
> 理由：Provider 更成熟稳定，学习曲线平缓，社区支持广泛，足以满足本项目需求。

### 9.2 架构建议
- 采用 MVVM 或 Clean Architecture
- 分离 UI、业务逻辑和数据层
- 使用依赖注入
- 单元测试覆盖核心逻辑

### 9.3 并发压缩实现要点
- **并发控制实现**:
  - 使用 Dart 的 `async`/`await` 和 `Future` 进行异步处理
  - 使用 `Stream` 和 `StreamController` 管理压缩任务流
  - **推荐使用 `pool` 包**限制并发数（最佳实践）
  - 示例代码结构（使用 pool 包）：
    ```dart
    import 'package:pool/pool.dart';
    
    class CompressionService {
      final Pool _pool;
      final CompressionApi _api;
      
      CompressionService({int maxConcurrent = 3}) 
          : _pool = Pool(maxConcurrent);
      
      /// 批量压缩文件，自动控制并发数
      Future<List<CompressionResult>> compressAll(
        List<CompressionTask> tasks,
      ) async {
        // 使用 Pool 确保同时运行的任务数不超过 maxConcurrent
        final results = await Future.wait(
          tasks.map((task) => _pool.withResource(
            () => _compressTask(task),
          )),
        );
        return results;
      }
      
      /// 压缩单个任务
      Future<CompressionResult> _compressTask(CompressionTask task) async {
        try {
          // 实际的压缩逻辑
          final result = await _api.compressImage(task.file);
          return CompressionResult.success(task, result);
        } catch (e) {
          return CompressionResult.failure(task, e);
        }
      }
      
      /// 释放资源
      Future<void> dispose() async {
        await _pool.close();
      }
    }
    ```
  - 使用 `Stream` 实现实时进度反馈：
    ```dart
    class CompressionService {
      final Pool _pool;
      final StreamController<CompressionProgress> _progressController;
      
      Stream<CompressionProgress> get progressStream => 
          _progressController.stream;
      
      /// 批量压缩并发送进度事件
      Future<void> compressBatch(List<CompressionTask> tasks) async {
        int completed = 0;
        final total = tasks.length;
        
        await Future.wait(
          tasks.map((task) => _pool.withResource(() async {
            final result = await _compressTask(task);
            completed++;
            
            // 发送进度更新
            _progressController.add(CompressionProgress(
              completed: completed,
              total: total,
              currentTask: task,
              result: result,
            ));
            
            return result;
          })),
        );
      }
    }
    ```
- **推荐的并发控制包**:
  - **`pool`**: 资源池管理（强烈推荐，简单可靠）
  - `async`: 提供 `FutureGroup` 和其他异步工具
  - `rxdart`: 响应式编程，适合复杂的异步流管理
- **性能优化建议**:
  - 使用 `compute()` 或 `Isolate` 处理大文件的**读取**操作（避免阻塞 UI 线程），但不要在 Isolate 中处理网络请求。
  - 实现智能调度算法：优先处理小文件，提升用户体验
  - 监控网络状态，动态调整并发数

  - 实现请求去重，避免重复压缩同一文件
- **错误处理**:
  - 单个任务失败不影响其他并发任务
  - 实现断点续传机制（记录已完成的文件）
  - 提供详细的错误日志，便于调试

---

## 10. 附录

### 10.1 参考链接
- [TinyPNG 官网](https://tinypng.com/)
- [TinyPNG API 文档](https://tinypng.com/developers)
- [TinyPNG API 参考](https://tinypng.com/developers/reference)
- [Flutter 桌面开发文档](https://docs.flutter.dev/desktop)

### 10.2 API 使用示例

#### 压缩图片
```bash
# 上传文件
POST https://api.tinify.com/shrink
Authorization: Basic base64(api:YOUR_API_KEY)
Content-Type: image/jpeg
[binary data]

# 响应
HTTP/1.1 201 Created
Compression-Count: 1
Location: https://api.tinify.com/output/xxxxx
{
  "input": {
    "size": 207565,
    "type": "image/jpeg"
  },
  "output": {
    "size": 46480,
    "type": "image/jpeg",
    "width": 530,
    "height": 300,
    "ratio": 0.224
  }
}

# 下载压缩后的图片
GET https://api.tinify.com/output/xxxxx
Authorization: Basic base64(api:YOUR_API_KEY)
```

---

**文档版本**: 1.0  
**创建日期**: 2026-01-15  
**最后更新**: 2026-01-15
