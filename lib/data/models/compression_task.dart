import 'package:equatable/equatable.dart';

/// 压缩状态枚举
/// 用于表示压缩任务的不同状态
enum CompressionStatus {
  pending,    // 等待中 - 任务已创建但尚未开始处理
  processing, // 压缩中 - 任务正在处理过程中
  completed,  // 已完成 - 任务已成功完成
  failed,     // 失败 - 任务处理失败
  cancelled   // 已取消 - 任务已被用户取消
}

/// 压缩任务模型
/// 用于表示单个图片压缩任务的详细信息
class CompressionTask extends Equatable {
  final String id;              // 任务唯一标识符
  final String filePath;        // 原始文件的完整路径
  final String fileName;        // 文件名（不含路径）
  final int originalSize;       // 原始文件大小（字节）
  final int? compressedSize;    // 压缩后文件大小（字节），如果未完成则为null
  final CompressionStatus status; // 当前压缩状态
  final String? errorMessage;   // 错误信息，仅在失败时存在
  final double? compressionRatio; // 压缩比率（压缩后大小/原始大小），仅在完成后存在
  final DateTime createdAt;     // 任务创建时间
  final DateTime? completedAt;  // 任务完成时间，仅在完成后存在
  final String? baseDir;        // 批量导入时的根目录，用于保持输出目录结构

  const CompressionTask({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.originalSize,
    this.compressedSize,
    required this.status,
    this.errorMessage,
    this.compressionRatio,
    required this.createdAt,
    this.completedAt,
    this.baseDir,
  });

  /// 创建一个新的CompressionTask实例，其属性值来自当前实例，
  /// 但可以根据需要覆盖某些属性
  CompressionTask copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? originalSize,
    int? compressedSize,
    CompressionStatus? status,
    String? errorMessage,
    double? compressionRatio,
    DateTime? createdAt,
    DateTime? completedAt,
    String? baseDir,
  }) {
    return CompressionTask(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      originalSize: originalSize ?? this.originalSize,
      compressedSize: compressedSize ?? this.compressedSize,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      compressionRatio: compressionRatio ?? this.compressionRatio,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      baseDir: baseDir ?? this.baseDir,
    );
  }

  /// 将对象转换为JSON格式的映射
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'originalSize': originalSize,
      'compressedSize': compressedSize,
      'status': status.toString(),
      'errorMessage': errorMessage,
      'compressionRatio': compressionRatio,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'baseDir': baseDir,
    };
  }

  /// 从JSON格式的映射创建CompressionTask实例
  factory CompressionTask.fromJson(Map<String, dynamic> json) {
    return CompressionTask(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      originalSize: json['originalSize'] as int,
      compressedSize: json['compressedSize'] as int?,
      status: _getStatusFromString(json['status'] as String),
      errorMessage: json['errorMessage'] as String?,
      compressionRatio: (json['compressionRatio'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      baseDir: json['baseDir'] as String?,
    );
  }

  /// 根据字符串形式的状态转换为CompressionStatus枚举
  static CompressionStatus _getStatusFromString(String statusStr) {
    switch (statusStr) {
      case 'CompressionStatus.pending':
        return CompressionStatus.pending;
      case 'CompressionStatus.processing':
        return CompressionStatus.processing;
      case 'CompressionStatus.completed':
        return CompressionStatus.completed;
      case 'CompressionStatus.failed':
        return CompressionStatus.failed;
      case 'CompressionStatus.cancelled':
        return CompressionStatus.cancelled;
      default:
        return CompressionStatus.pending;
    }
  }

  @override
  List<Object?> get props => [
    id,
    filePath,
    fileName,
    originalSize,
    compressedSize,
    status,
    errorMessage,
    compressionRatio,
    createdAt,
    completedAt,
    baseDir,
  ];
}