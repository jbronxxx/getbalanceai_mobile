import 'package:flutter/material.dart';

/// Подпись кнопки в одну строку. Слово не переносится посреди
/// («Редактиров / ать»): если подпись не помещается при крупном шрифте или
/// на узком экране, она немного уменьшается.
class OneLineLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const OneLineLabel(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}
