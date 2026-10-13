import 'package:flutter/material.dart';

/// Каркас контента экрана с закругленными верхними краями в стиле M3 Expressive / Sheet.
///
/// Обрамляет основное содержимое экрана скруглением верхних углов ([topRadius])
/// без резких разделительных границ, обеспечивая бесшовное скольжение под хэдером.
class ScreenBodyCard extends StatelessWidget {
  final Widget child;
  final double topRadius;
  final Color? backgroundColor;

  const ScreenBodyCard({
    super.key,
    required this.child,
    this.topRadius = 28.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveBg = backgroundColor ??
        (isDark ? const Color(0xFF09090B) : const Color(0xFFEFF2F6));

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(topRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
