import 'package:flutter_test/flutter_test.dart';
import 'package:tinypng_gui/services/file_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileService 测试', () {
    late FileService fileService;

    setUp(() {
      fileService = FileService();
    });

    test('isSupportedImage 识别有效扩展名', () {
      expect(fileService.isSupportedImage('test.jpg'), true);
      expect(fileService.isSupportedImage('test.jpeg'), true);
      expect(fileService.isSupportedImage('test.png'), true);
      expect(fileService.isSupportedImage('test.webp'), true);
      expect(fileService.isSupportedImage('test.AVIF'), true); // 不区分大小写
      expect(fileService.isSupportedImage('test.txt'), false);
    });

    test('getFileSizeString 格式化正确', () {
      expect(fileService.getFileSizeString(500), '500.0 B');
      expect(fileService.getFileSizeString(1024), '1.0 KB');
      expect(fileService.getFileSizeString(1536), '1.5 KB');
      expect(fileService.getFileSizeString(1024 * 1024), '1.0 MB');
    });

    group('getOutputPath 测试', () {
      test('当 outputDir 为空时返回原始路径', () {
        final path = p.join('C:', 'Users', 'Photo', 'image.png');
        final result = fileService.getOutputPath(path);
        // 假设没有后缀的默认行为是相同路径（或相同目录）
        // 默认实现：targetDir = dirname(original), filename = original
        expect(result, path);
      });

      test('正确追加后缀', () {
        final path = p.join('C:', 'Images', 'test.png');
        final result = fileService.getOutputPath(path, suffix: '_compressed');
        expect(result, p.join('C:', 'Images', 'test_compressed.png'));
      });

      test('使用 outputDir', () {
        final original = p.join('source', 'image.jpg');
        final output = p.join('target');
        final result = fileService.getOutputPath(original, outputDir: output);
        expect(result, p.join('target', 'image.jpg'));
      });

      test('使用 baseDir 保持目录结构', () {
        final base = p.join('C:', 'Source');
        final original = p.join('C:', 'Source', 'Sub', 'image.png');
        final output = p.join('D:', 'Output');

        final result = fileService.getOutputPath(
          original,
          outputDir: output,
          baseDir: base,
        );

        // 应该是 D:\Output\Sub\image.png
        expect(result, p.join('D:', 'Output', 'Sub', 'image.png'));
      });
    });
  });
}
