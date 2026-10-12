import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Универсальный контейнер с эффектом полированного жидкого стекла (Liquid Glass / Frosted Glass).
///
/// Реализует размытие фона ([BackdropFilter]), полупрозрачную подложку из [GlassTheme],
/// деликатную световую грань ([border]) и рассеянные тени без затемнения центра стекла.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? blurSigma;
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
    this.blurSigma,
    this.color,
    this.gradient,
    this.border,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final glassTheme = GlassTheme.of(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effectiveSigma = blurSigma ?? glassTheme.blurSigma;

    final effectiveColor =
        color ?? (gradient == null ? glassTheme.surface : null);

    final effectiveBorder = border ??
        Border.all(
          color: glassTheme.rim,
          width: 1.0,
        );

    // Отрицательный spreadRadius предотвращает просвечивание темной тени сквозь стекло
    final effectiveShadow = boxShadow ??
        [
          BoxShadow(
            color: glassTheme.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ];

    Widget body = Container(
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
    );

    Widget content;
    if (disableAnimations || effectiveSigma <= 0) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: body,
      );
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveSigma,
            sigmaY: effectiveSigma,
          ),
          child: body,
        ),
      );
    }

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
