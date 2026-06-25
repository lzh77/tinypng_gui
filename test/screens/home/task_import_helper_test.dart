import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinypng_gui/data/models/compression_task.dart';
import 'package:tinypng_gui/screens/home/task_import_helper.dart';
import 'package:tinypng_gui/services/file_service.dart';

void main() {
  late Directory tempDir;
  late FileService fileService;

  setUp(() async {
    fileService = FileService();
    tempDir = await Directory.systemTemp.createTemp('task_import_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TaskImportHelper', () {
    test('应从文件路径创建任务', () async {
      final image = File('${tempDir.path}/photo.png');
      await image.writeAsBytes(List.filled(128, 0));

      final tasks = await TaskImportHelper.buildTasksFromPaths(
        [image.path],
        fileService,
      );

      expect(tasks, hasLength(1));
      expect(tasks.first.fileName, 'photo.png');
      expect(tasks.first.originalSize, 128);
      expect(tasks.first.status, CompressionStatus.pending);
    });

    test('应忽略不支持的扩展名', () async {
      final textFile = File('${tempDir.path}/notes.txt');
      await textFile.writeAsString('hello');

      final tasks = await TaskImportHelper.buildTasksFromPaths(
        [textFile.path],
        fileService,
      );

      expect(tasks, isEmpty);
    });

    test('文件夹扫描应遵循 recursiveDirectoryScan 参数', () async {
      final nestedDir = Directory('${tempDir.path}/nested');
      await nestedDir.create();
      final top = File('${tempDir.path}/top.jpg');
      final nested = File('${nestedDir.path}/nested.jpg');
      await top.writeAsBytes(List.filled(10, 0));
      await nested.writeAsBytes(List.filled(20, 0));

      final shallow = await TaskImportHelper.buildTasksFromPaths(
        [tempDir.path],
        fileService,
      );
      final deep = await TaskImportHelper.buildTasksFromPaths(
        [tempDir.path],
        fileService,
        recursiveDirectoryScan: true,
      );

      expect(shallow, hasLength(1));
      expect(deep, hasLength(2));
      expect(deep.every((task) => task.baseDir == tempDir.path), isTrue);
    });

    test('单文件导入不应设置 baseDir', () async {
      final image = File('${tempDir.path}/solo.png');
      await image.writeAsBytes(List.filled(10, 0));

      final tasks = await TaskImportHelper.buildTasksFromPaths(
        [image.path],
        fileService,
      );

      expect(tasks.single.baseDir, isNull);
    });
  });
}
