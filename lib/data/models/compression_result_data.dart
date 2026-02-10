import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// 压缩结果数据封装
/// 用于存储图片压缩操作的结果数据
class CompressionResultData extends Equatable {
  final int originalSize;           // 原始文件大小（字节）
  final int compressedSize;         // 压缩后文件大小（字节）
  final String mimeType;            // 压缩后文件的MIME类型
  final Uint8List data;             // 压缩后文件的二进制数据
  final int? monthlyCompressionCount; // 本月累计压缩次数（从API响应头获取）

  const CompressionResultData({
    required this.originalSize,
    required this.compressedSize,
    required this.mimeType,
    required this.data,
    this.monthlyCompressionCount,
  });

  /// 创建一个新的CompressionResultData实例，其属性值来自当前实例，
  /// 但可以根据需要覆盖某些属性
  CompressionResultData copyWith({
    int? originalSize,
    int? compressedSize,
    String? mimeType,
    Uint8List? data,
    int? monthlyCompressionCount,
  }) {
    return CompressionResultData(
      originalSize: originalSize ?? this.originalSize,
      compressedSize: compressedSize ?? this.compressedSize,
      mimeType: mimeType ?? this.mimeType,
      data: data ?? this.data,
      monthlyCompressionCount: monthlyCompressionCount ?? this.monthlyCompressionCount,
    );
  }

  @override
  List<Object?> get props => [
    originalSize,
    compressedSize,
    mimeType,
    data,
    monthlyCompressionCount,
  ];
}