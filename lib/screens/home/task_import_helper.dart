import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/models/compression_task.dart';
import '../../services/file_service.dart';

/// 从文件/文件夹路径批量创建压缩任务
class TaskImportHelper {
  const TaskImportHelper._();

  /// 根据路径列表生成任务（自动识别文件与文件夹）
  static Future<List<CompressionTask>> buildTasksFromPaths(
    List<String> paths,
    FileService fileService, {
    bool recursiveDirectoryScan = false,
  }) async {
    final tasks = <CompressionTask>[];
    final seenPaths = <String>{};

    for (final path in paths) {
      if (path.isEmpty) continue;
      await _collectFromPath(
        path,
        fileService,
        tasks,
        seenPaths,
        recursiveDirectoryScan: recursiveDirectoryScan,
      );
    }

    return tasks;
  }

  static Future<void> _collectFromPath(
    String path,
    FileService fileService,
    List<CompressionTask> tasks,
    Set<String> seenPaths, {
    required bool recursiveDirectoryScan,
  }) async {
    if (await FileSystemEntity.isDirectory(path)) {
      final dir = Directory(path);
      await for (final entity in dir.list(
        recursive: recursiveDirectoryScan,
        followLinks: false,
      )) {
        if (entity is File) {
          await _addFileIfSupported(
            entity.path,
            fileService,
            tasks,
            seenPaths,
            baseDir: path,
          );
        }
      }
      return;
    }

    if (await FileSystemEntity.isFile(path)) {
      await _addFileIfSupported(path, fileService, tasks, seenPaths);
    }
  }

  static Future<void> _addFileIfSupported(
    String path,
    FileService fileService,
    List<CompressionTask> tasks,
    Set<String> seenPaths, {
    String? baseDir,
  }) async {
    if (!fileService.isSupportedImage(path) || seenPaths.contains(path)) {
      return;
    }

    seenPaths.add(path);
    final fileSize = await fileService.getFileSize(path);

    tasks.add(
      CompressionTask(
        id: const Uuid().v4(),
        filePath: path,
        fileName: p.basename(path),
        originalSize: fileSize,
        status: CompressionStatus.pending,
        createdAt: DateTime.now(),
        baseDir: baseDir,
      ),
    );
  }
}
