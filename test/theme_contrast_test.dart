import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';

/// UX-20: текст и иконки на основном цвете (кнопки шторок, «+», выбранный
/// месяц) читаются в обеих темах — контраст не ниже 4.5:1 (WCAG AA).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  for (final (name, theme) in [
    ('светлая', AppTheme.lightTheme),
    ('тёмная', AppTheme.darkTheme),
  ]) {
    test('$name тема: onPrimary на primary контрастен', () {
      final scheme = theme.colorScheme;
      expect(contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5));
    });
  }
}
