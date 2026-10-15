import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import 'liquid_glass_fab.dart';
import 'liquid_glass_nav_shape.dart';

/// Элемент навигации для плавающего островка [LiquidGlassNavBar].
class LiquidGlassNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const LiquidGlassNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// Центральная кнопка действия, выступающая над островком навигации.
class LiquidGlassNavAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const LiquidGlassNavAction({
    this.icon = Icons.add_rounded,
    required this.tooltip,
    required this.onPressed,
  });
}

/// Плавающий островок нижней навигации с эффектом полированного жидкого стекла (Liquid Glass).
///
/// Вдохновлен One UI и modern glassmorphism.
/// Имеет полупрозрачную форму скругленной капсулы, парит над прокручиваемым контентом,
/// размывает фон под собой и плавно анимирует активный элемент в капсулу.
class LiquidGlassNavBar extends StatelessWidget {
  /// Фиксированная высота внутреннего контейнера навбара.
  static const double barHeight = 68.0;

  /// Диаметр центральной кнопки действия.
  static const double centerActionSize = 52.0;

  /// Зазор между кнопкой и огибающей её дугой островка.
  static const double centerActionGap = 6.0;

  /// На сколько дуга над кнопкой поднимается над верхним краем островка.
  static const double centerActionLift = 22.0;

  /// Вычисляет нижний отступ плавающего островка с учетом безопасной зоны устройства.
  static double bottomMargin(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return bottomPadding > 0 ? bottomPadding + 6.0 : 16.0;
  }

  /// Вычисляет полную высоту островка навигации от нижнего края экрана.
  static double totalHeight(BuildContext context) {
    return barHeight + bottomMargin(context);
  }

  /// Рекомендуемый отступ снизу для содержимого скроллящихся экранов
  /// (ListView/CustomScrollView) с учётом выступающей центральной кнопки.
  static double bottomContentPadding(BuildContext context) {
    return totalHeight(context) + centerActionLift + 12.0;
  }

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<LiquidGlassNavItem> destinations;

  /// Кнопка в центре островка; индексы [destinations] её не учитывают.
  final LiquidGlassNavAction? centerAction;

  const LiquidGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.centerAction,
  });

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
    final effectiveBottomMargin = bottomMargin(context);

    // С такой же полупрозрачностью и блюром Liquid Glass, как и хэдер
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

    final hasCenterAction = centerAction != null;
    final shape = LiquidGlassNavShape(
      bumpRadius: hasCenterAction ? centerActionSize / 2 + centerActionGap : 0,
      bumpHeight: hasCenterAction ? centerActionLift : 0,
      side: BorderSide(color: glassTheme.rim),
    );

    final Widget navContent = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: navColors,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          6,
          (hasCenterAction ? centerActionLift : 0) + 6,
          6,
          6,
        ),
        child: SizedBox(
          height: barHeight - 12,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++) ...[
                if (hasCenterAction && index == destinations.length ~/ 2)
                  const SizedBox(width: centerActionSize + 4),
                Expanded(
                  child: _LiquidGlassNavItemWidget(
                    item: destinations[index],
                    isSelected: selectedIndex == index,
                    onTap: () => onDestinationSelected(index),
                    glassTheme: glassTheme,
                    colorScheme: theme.colorScheme,
                    labelStyle: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final Widget glassBody = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: shouldUseBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: glassTheme.blurSigma,
                sigmaY: glassTheme.blurSigma,
              ),
              child: navContent,
            )
          : navContent,
    );

    return RepaintBoundary(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Center(
          child: Container(
            margin: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: effectiveBottomMargin,
            ),
            constraints: const BoxConstraints(maxWidth: 480),
            // Дуга над кнопкой входит в форму островка, поэтому вся кнопка
            // лежит внутри виджета и принимает нажатия.
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: shape,
                    shadows: [
                      BoxShadow(
                        color: glassTheme.shadow,
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -2,
                      ),
                      if (isDark)
                        BoxShadow(
                          color: glassTheme.accent.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 2),
                          spreadRadius: -2,
                        ),
                    ],
                  ),
                  child: glassBody,
                ),
                if (hasCenterAction)
                  Positioned(
                    top: centerActionGap,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: LiquidGlassFab(
                        key: const ValueKey('nav_center_action'),
                        icon: centerAction!.icon,
                        size: centerActionSize,
                        fillOpacity: 0.82,
                        tooltip: centerAction!.tooltip,
                        onPressed: centerAction!.onPressed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Внутренний интерактивный элемент навбара с поддержкой анимации нажатия и доступности.
class _LiquidGlassNavItemWidget extends StatefulWidget {
  final LiquidGlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final GlassTheme glassTheme;
  final ColorScheme colorScheme;
  final TextStyle? labelStyle;

  const _LiquidGlassNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.glassTheme,
    required this.colorScheme,
    required this.labelStyle,
  });

  @override
  State<_LiquidGlassNavItemWidget> createState() =>
      _LiquidGlassNavItemWidgetState();
}

class _LiquidGlassNavItemWidgetState extends State<_LiquidGlassNavItemWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activeBgColor = widget.glassTheme.activeItemBg;
    final activeContentColor = widget.glassTheme.accent;
    final inactiveContentColor = widget.glassTheme.inactiveItemColor;

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      selected: widget.isSelected,
      label: widget.item.label,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onHighlightChanged: (highlighted) {
              if (_isPressed != highlighted) {
                setState(() => _isPressed = highlighted);
              }
            },
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: widget.isSelected ? activeBgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: widget.isSelected
                    ? Border.all(
                        color: widget.glassTheme.rim,
                        width: 1,
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Icon(
                      widget.isSelected
                          ? (widget.item.activeIcon ?? widget.item.icon)
                          : widget.item.icon,
                      size: 22,
                      color: widget.isSelected
                          ? activeContentColor
                          : inactiveContentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Длинные подписи (kk/uz) уменьшаются, а не обрезаются.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        style: widget.labelStyle?.copyWith(
                          fontSize: 11,
                          height: 1.15,
                          fontWeight: widget.isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: widget.isSelected
                              ? activeContentColor
                              : inactiveContentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
