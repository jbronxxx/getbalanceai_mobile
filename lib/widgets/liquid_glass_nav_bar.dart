import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

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

/// Плавающий островок нижней навигации с эффектом полированного жидкого стекла (Liquid Glass).
///
/// Вдохновлен One UI и modern glassmorphism.
/// Имеет полупрозрачную форму скругленной капсулы, парит над прокручиваемым контентом,
/// размывает фон под собой и плавно анимирует активный элемент в капсулу.
class LiquidGlassNavBar extends StatelessWidget {
  /// Фиксированная высота внутреннего контейнера навбара.
  static const double barHeight = 68.0;

  /// Вычисляет нижний отступ плавающего островка с учетом безопасной зоны устройства.
  static double bottomMargin(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return bottomPadding > 0 ? bottomPadding + 6.0 : 16.0;
  }

  /// Вычисляет полную высоту островка навигации от нижнего края экрана.
  static double totalHeight(BuildContext context) {
    return barHeight + bottomMargin(context);
  }

  /// Рекомендуемый отступ снизу для содержимого скроллящихся экранов (ListView/CustomScrollView).
  static double bottomContentPadding(BuildContext context) {
    return totalHeight(context) + 16.0;
  }

  /// Рекомендуемый отступ снизу для плавающей кнопки FAB над навбаром.
  static double fabBottomPadding(BuildContext context) {
    return totalHeight(context) + 8.0;
  }

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<LiquidGlassNavItem> destinations;

  const LiquidGlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassTheme = GlassTheme.of(context);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final effectiveBottomMargin = bottomMargin(context);

    Widget navContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glassTheme.surface,
            glassTheme.surfaceEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: glassTheme.rim,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(destinations.length, (index) {
          final item = destinations[index];
          final isSelected = selectedIndex == index;

          return Expanded(
            child: _LiquidGlassNavItemWidget(
              item: item,
              isSelected: isSelected,
              onTap: () => onDestinationSelected(index),
              glassTheme: glassTheme,
              colorScheme: theme.colorScheme,
              labelStyle: theme.textTheme.labelSmall,
            ),
          );
        }),
      ),
    );

    Widget glassBody;
    if (disableAnimations || glassTheme.blurSigma <= 0) {
      glassBody = ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: navContent,
      );
    } else {
      glassBody = ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: glassTheme.blurSigma,
            sigmaY: glassTheme.blurSigma,
          ),
          child: navContent,
        ),
      );
    }

    return RepaintBoundary(
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Center(
          child: Container(
            margin: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: effectiveBottomMargin,
            ),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
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
                horizontal: 6,
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
                  Flexible(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
