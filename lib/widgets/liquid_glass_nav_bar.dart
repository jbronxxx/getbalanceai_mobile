import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// Вдохновлен One UI (Samsung Galaxy Store) и modern glassmorphism.
/// Имеет полупрозрачную форму скругленной капсулы, парит над прокручиваемым контентом,
/// размывает фон под собой и плавно анимирует активный элемент в капсулу.
class LiquidGlassNavBar extends StatelessWidget {
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
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final effectiveBottomMargin = bottomPadding > 0 ? bottomPadding + 6 : 16.0;

    return Center(
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
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            if (isDark)
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF141418).withValues(alpha: 0.65),
                          const Color(0xFF09090D).withValues(alpha: 0.70),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.75),
                          const Color(0xFFF8FAFC).withValues(alpha: 0.70),
                        ],
                ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFCBD5E1).withValues(alpha: 0.60),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(destinations.length, (index) {
                  final item = destinations[index];
                  final isSelected = selectedIndex == index;

                  final activeBgColor = isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : colorScheme.primary.withValues(alpha: 0.10);

                  final activeContentColor =
                      isDark ? const Color(0xFF2DD4BF) : colorScheme.primary;

                  final inactiveContentColor =
                      colorScheme.onSurface.withValues(alpha: 0.55);

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onDestinationSelected(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? activeBgColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          border: isSelected
                              ? Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : colorScheme.primary
                                          .withValues(alpha: 0.15),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected
                                  ? (item.activeIcon ?? item.icon)
                                  : item.icon,
                              size: 22,
                              color: isSelected
                                  ? activeContentColor
                                  : inactiveContentColor,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? activeContentColor
                                      : inactiveContentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
