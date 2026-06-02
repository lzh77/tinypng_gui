import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:tinypng_gui/data/datasources/remote/tinypng_api.dart';

void main() {
  group('TinyPngApi Mock 测试', () {
    late TinyPngApi api;
    late Dio dio;
    late DioAdapter dioAdapter;
    const String apiKey = 'test_api_key';

    setUp(() {
      dio = Dio();
      dioAdapter = DioAdapter(
        dio: dio,
        matcher: const UrlRequestMatcher(matchMethod: true),
      );
      api = TinyPngApi(apiKey: apiKey, dio: dio);
    });

    test('compressImage 全流程测试', () async {
      // 1. Mock /shrink (上传环节)
      // 使用极其宽松的匹配模式
      dioAdapter.onPost(
        RegExp(r'.*/shrink'),
        (server) => server.reply(201, {
          'input': {'size': 1024, 'type': 'image/png'},
          'output': {
            'url': 'https://api.tinify.com/out/1',
            'size': 512,
            'type': 'image/png'
          }
        }, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'compression-count': ['42'],
        }),
        data: Matchers.any,
      );

      // 2. Mock output url (Resize/Convert 环节)
      dioAdapter.onPost(
        'https://api.tinify.com/out/1',
        (server) => server.reply(200, {
          'output': {'size': 256, 'type': 'image/webp'}
        }, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Location': ['https://api.tinify.com/out/2'],
        }),
        data:
            '{"resize":{"method":"scale","width":300},"convert":{"type":"image/webp"}}',
      );

      // 3. Mock 下载环节
      dioAdapter.onGet(
        'https://api.tinify.com/out/2',
        (server) => server.reply(200, [0, 1, 2, 3]),
      );

      final tempFile =
          File('${Directory.systemTemp.path}/test_final_robust.png');
      await tempFile.writeAsBytes([1, 2, 3]);

      try {
        final result = await api.compressImage(
          tempFile,
          resize: ResizeOptions(method: 'scale', width: 300),
          targetFormat: 'image/webp',
        );

        expect(result.originalSize, 1024);
        expect(result.compressedSize, 256);
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
    });

    test('validateApiKey 基本逻辑测试', () async {
      dioAdapter.onPost(
        RegExp(r'.*/shrink'),
        (server) => server.reply(201, {
          'input': {'size': 100},
          'output': {'url': '...', 'size': 50}
        }),
        data: Matchers.any,
      );

      final isValid = await api.validateApiKey(apiKey);
      expect(isValid, isTrue);
    });
  });

  group('异常定义测试', () {
    test('ApiKeyInvalidException 状态码', () {
      expect(ApiKeyInvalidException().statusCode, 401);
    });
    group('ResizeOptions 测试', () {
      test('ResizeOptions 属性正确', () {
        final opt = ResizeOptions(method: 'scale', width: 100);
        expect(opt.method, 'scale');
        expect(opt.width, 100);
      });
    });
  });
}
