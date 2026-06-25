import 'package:equatable/equatable.dart';

import 'compression_task.dart';

/// 压缩历史记录模型
/// 持久化于 SQLite，表示单次压缩任务的结果快照
class HistoryRecord extends Equatable {
  final String id;
  final String fileName;
  final String filePath;
  final int originalSize;
  final int? compressedSize;
  final CompressionStatus status;
  final String? errorMessage;
  final DateTime timestamp;

  const HistoryRecord({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.originalSize,
    this.compressedSize,
    required this.status,
    this.errorMessage,
    required this.timestamp,
  });

  /// 从压缩任务创建历史记录（仅 completed / failed 状态有意义）
  factory HistoryRecord.fromTask(CompressionTask task) {
    return HistoryRecord(
      id: task.id,
      fileName: task.fileName,
      filePath: task.filePath,
      originalSize: task.originalSize,
      compressedSize: task.compressedSize,
      status: task.status,
      errorMessage: task.errorMessage,
      timestamp: task.completedAt ?? DateTime.now(),
    );
  }

  /// 压缩节省比例（0.0–1.0），仅成功记录有效
  double? get savingsRatio {
    if (status != CompressionStatus.completed) return null;
    if (compressedSize == null || originalSize <= 0) return null;
    return 1 - (compressedSize! / originalSize);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'originalSize': originalSize,
      'compressedSize': compressedSize,
      'status': status.name,
      'errorMessage': errorMessage,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory HistoryRecord.fromMap(Map<String, dynamic> map) {
    return HistoryRecord(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      originalSize: map['originalSize'] as int,
      compressedSize: map['compressedSize'] as int?,
      status: _statusFromString(map['status'] as String),
      errorMessage: map['errorMessage'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  static CompressionStatus _statusFromString(String value) {
    return CompressionStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => CompressionStatus.completed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        filePath,
        originalSize,
        compressedSize,
        status,
        errorMessage,
        timestamp,
      ];
}
