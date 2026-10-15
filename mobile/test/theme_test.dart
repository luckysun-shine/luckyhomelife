import 'package:family_os/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('亮色和深色主题使用正确亮度', () {
    expect(buildFamilyTheme(Brightness.light).brightness, Brightness.light);
    expect(buildFamilyTheme(Brightness.dark).brightness, Brightness.dark);
  });
}
