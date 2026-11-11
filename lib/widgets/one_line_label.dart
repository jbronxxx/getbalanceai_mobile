import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Короткая подпись (кнопка, переключатель, строка настроек) в одну строку.
/// Слово не переносится посреди («Редактиров / ать») и не обрезается
/// троеточием: если подпись не помещается при крупном шрифте или на узком
/// экране, она немного уменьшается.
class OneLineLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  /// Положение подписи, когда места больше, чем ей нужно.
  final AlignmentGeometry alignment;

  const OneLineLabel(
    this.text, {
    super.key,
    this.style,
    this.alignment = Alignment.center,
  });

  /// Ширина [text] в одну строку с учётом масштаба шрифта — сколько места
  /// нужно подписи, чтобы не уменьшаться. [textScaler] — другой масштаб
  /// вместо системного (подбор уменьшения в [WholeWordsText]).
  static double widthOf(
    BuildContext context,
    String text,
    TextStyle? style, {
    TextScaler? textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble() + 1;
    painter.dispose();
    return width;
  }

  /// Место для суммы рядом с названием в строке шириной [available]:
  /// название получает свою ширину (плюс [titleExtra] — значок рядом с
  /// ним), сумма — остальное, но не меньше [minShare] строки (тогда
  /// уменьшается и название).
  static double spaceBeside(
    BuildContext context, {
    required double available,
    required String title,
    TextStyle? titleStyle,
    double titleExtra = 0,
    double minShare = 0.4,
  }) =>
      math.max(
        available - widthOf(context, title, titleStyle) - titleExtra,
        available * minShare,
      );

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}
