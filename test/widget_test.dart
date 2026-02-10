import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tinypng_gui/main.dart'; // 确保 main.dart 暴露了 TinyPngApp

void main() {
  testWidgets('App initializes', (WidgetTester tester) async {
    // 设置 mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(TinyPngApp(sharedPreferences: sharedPreferences));

    // 验证基本的 UI 结构是否存在
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
