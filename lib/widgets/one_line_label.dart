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

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}
