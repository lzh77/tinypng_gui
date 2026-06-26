import 'package:uuid/uuid.dart';
import 'package:equatable/equatable.dart';

/// API Key状态枚举
/// 表示API Key的不同状态
enum ApiKeyStatus {
  active,      // 可用 - API Key有效且可使用
  quotaFull,   // 配额已满 - API Key本月配额已用完
  invalid,     // 无效 - API Key无效或已过期
  disabled     // 已禁用 - API Key被用户手动禁用
}

/// TinyPNG 免费账户默认月度压缩配额
const int kTinyPngFreeMonthlyLimit = 500;

/// API Key信息模型
/// 用于存储和管理TinyPNG API Key的相关信息
class ApiKeyInfo extends Equatable {
  final String id;              // API Key唯一标识符
  final String key;             // API Key的实际值（加密存储）
  final String alias;           // API Key的别名，便于用户识别
  final int compressionCount;   // 本月已使用的压缩次数
  final int? monthlyLimit;      // 月度限额（null 表示未知）
  final ApiKeyStatus status;    // 当前状态
  final DateTime createdAt;     // API Key创建时间
  final DateTime? lastUsedAt;   // 最后使用时间
  final bool isDefault;         // 是否为默认使用的API Key

  ApiKeyInfo({
    String? id,
    required this.key,
    required this.alias,
    this.compressionCount = 0,
    this.monthlyLimit,
    this.status = ApiKeyStatus.active,
    DateTime? createdAt,
    this.lastUsedAt,
    this.isDefault = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// 创建一个新的ApiKeyInfo实例，其属性值来自当前实例，
  /// 但可以根据需要覆盖某些属性
  ApiKeyInfo copyWith({
    String? id,
    String? key,
    String? alias,
    int? compressionCount,
    int? monthlyLimit,
    ApiKeyStatus? status,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    bool? isDefault,
  }) {
    return ApiKeyInfo(
      id: id ?? this.id,
      key: key ?? this.key,
      alias: alias ?? this.alias,
      compressionCount: compressionCount ?? this.compressionCount,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// 将对象转换为JSON格式的映射
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'alias': alias,
      'compressionCount': compressionCount,
      'monthlyLimit': monthlyLimit,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'isDefault': isDefault,
    };
  }

  /// 从JSON格式的映射创建ApiKeyInfo实例
  factory ApiKeyInfo.fromJson(Map<String, dynamic> json) {
    return ApiKeyInfo(
      id: json['id'] as String,
      key: json['key'] as String,
      alias: json['alias'] as String,
      compressionCount: json['compressionCount'] as int? ?? 0,
      monthlyLimit: json['monthlyLimit'] as int?,
      status: _getStatusFromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// 根据字符串形式的状态转换为ApiKeyStatus枚举
  static ApiKeyStatus _getStatusFromString(String statusStr) {
    switch (statusStr) {
      case 'ApiKeyStatus.active':
        return ApiKeyStatus.active;
      case 'ApiKeyStatus.quotaFull':
        return ApiKeyStatus.quotaFull;
      case 'ApiKeyStatus.invalid':
        return ApiKeyStatus.invalid;
      case 'ApiKeyStatus.disabled':
        return ApiKeyStatus.disabled;
      default:
        return ApiKeyStatus.invalid;
    }
  }

  /// 配额用量文案（设置页与主页展示）
  String get quotaUsageLabel {
    if (monthlyLimit != null) {
      return '本月配额 $compressionCount / $monthlyLimit';
    }
    return '本月已压缩 $compressionCount 张';
  }

  /// 配额使用比例（0.0–1.0），无已知限额时返回 null
  double? get quotaUsageRatio {
    final limit = monthlyLimit;
    if (limit == null || limit <= 0) return null;
    return (compressionCount / limit).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    id,
    key,
    alias,
    compressionCount,
    monthlyLimit,
    status,
    createdAt,
    lastUsedAt,
    isDefault,
  ];
}