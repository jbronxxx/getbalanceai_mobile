import 'dart:ui';
import 'package:flutter/material.dart';

/// Универсальный контейнер с эффектом полированного жидкого стекла (Liquid Glass / Frosted Glass).
///
/// Реализует размытие фона ([BackdropFilter]), настраиваемый полупрозрачный фон,
/// деликатную световую грань ([border]) и мягкие рассеянные тени ([boxShadow]).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.blurSigma = 16.0,
    this.color,
    this.gradient,
    this.border,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveColor = color ??
        (gradient == null
            ? (isDark
                ? const Color(0xFF141416).withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.78))
            : null);

    final effectiveBorder = border ??
        Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.65),
          width: 1.0,
        );

    final effectiveShadow = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveColor,
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: effectiveBorder,
          ),
          child: child,
        ),
      ),
    );

    if (margin != null || effectiveShadow.isNotEmpty) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: effectiveShadow,
        ),
        child: content,
      );
    }

    return content;
  }
}
