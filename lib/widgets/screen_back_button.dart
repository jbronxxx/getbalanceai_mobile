import 'package:flutter/material.dart';

/// Стрелка «Назад» в шапке экрана без AppBar (вход, шаги первой настройки).
///
/// Ставится без горизонтального поля содержимого: иконка оказывается в 16 от
/// края экрана — там же, где `leading` у AppBar на остальных экранах.
class ScreenBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ScreenBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: Theme.of(context).colorScheme.onSurface,
        onPressed: onPressed,
      ),
    );
  }
}
