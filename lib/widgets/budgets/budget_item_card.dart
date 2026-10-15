import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import '../swipe_hint_wrapper.dart';

/// Карточка элемента бюджета с индикатором выполнения и поддержкой свайпа для удаления.
class BudgetItemCard extends StatelessWidget {
  final Budget budget;
  final double currentSpent;
  final bool isFirst;
  final bool showSwipeHint;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onHintShown;

  const BudgetItemCard({
    super.key,
    required this.budget,
    required this.currentSpent,
    required this.isFirst,
    required this.showSwipeHint,
    required this.onTap,
    required this.onDelete,
    required this.onHintShown,
  });

  /// Цвет шкалы по доле потраченного: до 75% — основной, 75–100% —
  /// предупреждение, выше лимита — перерасход.
  static Color progressColorFor(
    double ratio,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (ratio > 1) {
      return isDark ? const Color(0xFFF59E0B) : const Color(0xFFEA7A35);
    }
    if (ratio >= 0.75) {
      return isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
    }
    return colorScheme.primary;
  }

  static String _display(double amount) => CurrencyFormatter.format(amount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final ratio =
        budget.limitAmount > 0 ? currentSpent / budget.limitAmount : 0.0;
    final progress = ratio.clamp(0.0, 1.0);
    final isExceeded = currentSpent > budget.limitAmount;
    final percent = (ratio * 100).round();

    // Мягкий бежево-оранжевый цвет предупреждения вместо пугающего красного
    final exceededColor =
        isDark ? const Color(0xFFF59E0B) : const Color(0xFFEA7A35);
    final progressColor = progressColorFor(ratio, colorScheme, isDark);

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(Icons.delete_rounded, color: colorScheme.onError),
    );

    final baseBg = theme.cardTheme.color ??
        (isDark ? const Color(0xFF141416) : Colors.white);
    final cardBg = isExceeded
        ? Color.alphaBlend(
            exceededColor.withValues(alpha: isDark ? 0.16 : 0.08),
            baseBg,
          )
        : baseBg;

    final glassBorder = isExceeded
        ? exceededColor.withValues(alpha: isDark ? 0.40 : 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFE2E8F0));

    final cardContent = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: glassBorder,
          width: isExceeded ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isExceeded
                ? exceededColor.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CategoryStyle.icon(budget.category),
                      size: 20,
                      color: CategoryStyle.color(budget.category),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        budget.category.getLocalizedName(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CurrencyFormatter.formatText(
                          (budget.limitAmount - currentSpent).abs(),
                          prefix: isExceeded
                              ? '${context.l10n.budget_exceeded} '
                              : '',
                          useFittedBox: true,
                          textAlign: TextAlign.end,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isExceeded
                                ? exceededColor
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  color: progressColor,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.budget_spent_of(
                          _display(currentSpent),
                          _display(budget.limitAmount),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final dismissibleItem = Dismissible(
      key: Key('budget_${budget.localId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: background,
      child: cardContent,
    );

    final itemWithHint = isFirst
        ? SwipeHintWrapper(
            showHint: showSwipeHint,
            background: background,
            borderRadius: BorderRadius.circular(24),
            onHintShown: onHintShown,
            child: dismissibleItem,
          )
        : dismissibleItem;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: itemWithHint,
    );
  }
}
