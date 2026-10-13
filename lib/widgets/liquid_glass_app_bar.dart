import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';

/// Хэдер экрана в стиле полированного полупрозрачного жидкого стекла (Liquid Glass).
///
/// Имеет полупрозрачную стеклянную подложку с размытием фона ([BackdropFilter])
/// без резких разделительных линий, позволяя прокручиваемому контенту мягко
/// скользить под хэдером.
/// Поддерживает fallback без размытия для неподдерживаемых устройств.
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final bool? centerTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final double toolbarHeight;
  final double bottomRadius;
  final SystemUiOverlayStyle? systemOverlayStyle;

  const LiquidGlassAppBar({
    super.key,
    this.title,
    this.centerTitle = true,
    this.actions,
    this.leading,
    this.toolbarHeight = kToolbarHeight,
    this.bottomRadius = 20.0,
    this.systemOverlayStyle,
  });

  /// Безопасный верхний отступ для контента под прозрачным хэдером при `extendBodyBehindAppBar: true`.
  static double topContentPadding(BuildContext context) {
    return MediaQuery.paddingOf(context).top + kToolbarHeight;
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassTheme = GlassTheme.of(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isBlurSupported = DeviceCapabilityService.instance.isBlurSupported;
    final shouldUseBlur =
        !disableAnimations && glassTheme.blurSigma > 0 && isBlurSupported;

    // Повышенная прозрачность для эффекта скольжения контента под хэдером
    final navColors = shouldUseBlur
        ? (isDark
            ? [
                glassTheme.surface.withValues(alpha: 0.35),
                glassTheme.surfaceEnd.withValues(alpha: 0.45),
              ]
            : [
                glassTheme.surface.withValues(alpha: 0.45),
                glassTheme.surfaceEnd.withValues(alpha: 0.55),
              ])
        : (isDark
            ? [const Color(0xDD18181C), const Color(0xDD121216)]
            : [const Color(0xDDFFFFFF), const Color(0xDDF1F5F9)]);

    final bottomBorderRadius = BorderRadius.vertical(
      bottom: Radius.circular(bottomRadius),
    );

    final glassBg = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: navColors,
        ),
        borderRadius: bottomBorderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
    );

    final Widget flexibleSpace;
    if (shouldUseBlur) {
      flexibleSpace = RepaintBoundary(
        child: ClipRRect(
          borderRadius: bottomBorderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: glassTheme.blurSigma,
              sigmaY: glassTheme.blurSigma,
            ),
            child: glassBg,
          ),
        ),
      );
    } else {
      flexibleSpace = ClipRRect(
        borderRadius: bottomBorderRadius,
        child: glassBg,
      );
    }

    return AppBar(
      title: title,
      centerTitle: centerTitle ?? true,
      actions: actions,
      leading: leading,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: toolbarHeight,
      shape: RoundedRectangleBorder(
        borderRadius: bottomBorderRadius,
      ),
      systemOverlayStyle: systemOverlayStyle ??
          (isDark
              ? SystemUiOverlayStyle.light
                  .copyWith(statusBarColor: Colors.transparent)
              : SystemUiOverlayStyle.dark
                  .copyWith(statusBarColor: Colors.transparent)),
      flexibleSpace: flexibleSpace,
    );
  }
}
