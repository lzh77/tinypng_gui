import 'dart:io';
import 'package:path/path.dart' as p;
import 'logger_service.dart';

class FileService {
  /// TinyPNG 支持的图片扩展名
  static const List<String> supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.avif',
  ];

  /// 根据扩展名检查文件是否为支持的图片
  bool isSupportedImage(String path) {
    try {
      final ext = p.extension(path).toLowerCase();
      return supportedExtensions.contains(ext);
    } catch (e) {
      LoggerService.e('检查路径扩展名时出错: $path', e);
      return false;
    }
  }

  /// 获取文件大小（字节）。如果文件不存在或发生错误，返回 0。
  Future<int> getFileSize(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return 0;
      }
      return await file.length();
    } catch (e) {
      LoggerService.e('获取文件大小时出错: $path', e);
      return 0;
    }
  }

  /// 获取易读的文件大小字符串（例如 "1.5 MB"）
  String getFileSizeString(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// 生成压缩文件的输出路径
  ///
  /// [originalPath]: 源文件的完整路径
  /// [outputDir]: 可选的目标目录。如果为空，则使用源文件所在目录。
  /// [baseDir]: 用于保持文件夹结构的可选基准目录（当设置了 [outputDir] 时使用）。
  ///            如果提供，[baseDir] 到 [originalPath] 的相对路径将被追加到 [outputDir]。
  /// [overwrite]: 如果为 true 且未指定 [outputDir]，则返回 [originalPath]。
  /// [suffix]: 追加到文件名的可选后缀（例如 "_compressed"）。
  String getOutputPath(
    String originalPath, {
    String? outputDir,
    String? baseDir,
    bool overwrite = false,
    String suffix = '',
  }) {
    try {
      String targetDir;

      // 确定目标目录
      if (outputDir == null || outputDir.isEmpty) {
        // 没有自定义输出目录，使用源目录
        if (overwrite) {
          return originalPath;
        }
        targetDir = p.dirname(originalPath);
      } else {
        // 自定义输出目录
        if (baseDir != null &&
            baseDir.isNotEmpty &&
            p.isWithin(baseDir, originalPath)) {
          // 保持文件夹结构: outputDir + relativePath
          final relative = p.relative(p.dirname(originalPath), from: baseDir);
          targetDir = p.join(outputDir, relative);
        } else {
          // 扁平结构或单个文件
          targetDir = outputDir;
        }
      }

      final filename = p.basenameWithoutExtension(originalPath);
      final ext = p.extension(originalPath);

      String newFilename = filename;

      // 如果提供了后缀且不是原地覆盖（或者如果是移动到新目录，通常我们添加后缀以示区别）。
      // 如果我们是移动到新目录，'overwrite' 参数通常指的是“覆盖源文件”，
      // 但在这里我们可能将其视为“不添加后缀”。
      if (suffix.isNotEmpty && !overwrite) {
        newFilename = '$filename$suffix';
      }

      return p.join(targetDir, '$newFilename$ext');
    } catch (e) {
      LoggerService.e('生成输出路径时出错: $originalPath', e);
      // 回退到原始路径以避免崩溃，尽管这种情况不应该发生
      return originalPath;
    }
  }

  /// 确保给定文件路径的目录存在。
  /// 如果 [path] 是目录路径，请设置 [isDirectory]=true。
  Future<void> ensureDirectoryExists(
    String path, {
    bool isDirectory = false,
  }) async {
    try {
      final dirPath = isDirectory ? path : p.dirname(path);
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        LoggerService.i('已创建目录: $dirPath');
      }
    } catch (e) {
      LoggerService.e('创建目录时出错: $path', e);
      rethrow;
    }
  }

  /// 检查文件是否为普通文件
  Future<bool> isFile(String path) async {
    return await FileSystemEntity.isFile(path);
  }

  /// 检查路径是否为目录
  Future<bool> isDirectory(String path) async {
    return await FileSystemEntity.isDirectory(path);
  }
}
