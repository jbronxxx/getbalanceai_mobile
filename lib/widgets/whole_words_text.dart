import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'one_line_label.dart';

/// Текст в несколько строк, который переносится только между словами.
/// Если при крупном шрифте (до ×2 — максимум системного меню) самое длинное
/// слово не помещается в ширину («синхро / низированы»), весь текст немного
/// уменьшается — настолько, чтобы это слово встало целиком.
class WholeWordsText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const WholeWordsText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  /// Обычные пробелы и переводы строк; неразрывный пробел (суммы
  /// «€35 891 556,00») — часть слова, по нему строка не переносится.
  static final _spaces = RegExp('[ \t\n]+');

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(builder: (context, constraints) {
      final widest = text
          .split(_spaces)
          .map((word) => OneLineLabel.widthOf(context, word, effective))
          .fold(0.0, math.max);
      final child = Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
      if (!constraints.hasBoundedWidth || widest <= constraints.maxWidth) {
        return child;
      }
      final fontSize = effective.fontSize ?? 14;
      final scaler = MediaQuery.textScalerOf(context);
      final factor =
          scaler.scale(fontSize) / fontSize * (constraints.maxWidth / widest);
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: factor,
        child: child,
      );
    });
  }
}
