import 'dart:io';
import 'package:flutter/services.dart';

/// Загружает Inter из assets под именами, которые даёт google_fonts:
/// ширина текста в тестах — как на телефоне, а не шрифтом-заглушкой.
Future<void> loadAppFonts() async {
  Future<ByteData> file(String name) async => ByteData.sublistView(
      await File('assets/google_fonts/Inter-$name.ttf').readAsBytes());
  const variants = {
    'regular': 'Regular',
    '500': 'Medium',
    '600': 'SemiBold',
    '700': 'Bold',
    '800': 'Bold',
    '900': 'Bold',
  };
  for (final MapEntry(:key, :value) in variants.entries) {
    await (FontLoader('Inter_$key')..addFont(file(value))).load();
  }
}
