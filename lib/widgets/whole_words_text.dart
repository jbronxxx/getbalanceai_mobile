import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'one_line_label.dart';

/// Текст в несколько строк, который переносится только между словами.
/// Если при крупном шрифте (до ×2 — максимум системного меню) самое длинное
/// слово не помещается в ширину («синхро / низированы»), весь текст немного
/// уменьшается — настолько, чтобы каждое слово встало целиком.
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
      final child = Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
      if (!constraints.hasBoundedWidth) return child;
      final fontSize = effective.fontSize ?? 14;
      final scale = MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
      final factor = text
          .split(_spaces)
          .map((word) => _fittingScale(
              context, word, effective, scale, constraints.maxWidth))
          .fold(scale, math.min);
      if (factor >= scale) return child;
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: factor,
        child: child,
      );
    });
  }

  /// Наибольший масштаб не больше [scale], при котором [word] помещается в
  /// [maxWidth]. Межбуквенный интервал не растёт вместе со шрифтом, поэтому
  /// ширина слова падает медленнее масштаба и одного пропорционального
  /// пересчёта мало («конфиденциальност / и»): уточняем несколькими замерами.
  static double _fittingScale(BuildContext context, String word,
      TextStyle style, double scale, double maxWidth) {
    double widthAt(double k) => OneLineLabel.widthOf(context, word, style,
        textScaler: TextScaler.linear(k));
    var fit = scale;
    var width = widthAt(fit);
    for (var i = 0; i < 5 && width > maxWidth; i++) {
      fit *= maxWidth / width;
      width = widthAt(fit);
    }
    return fit;
  }
}
