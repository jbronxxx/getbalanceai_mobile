import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final progress = budget.limitAmount > 0
        ? (currentSpent / budget.limitAmount).clamp(0.0, 1.0)
        : 0.0;
    final isExceeded = currentSpent > budget.limitAmount;

    // Мягкий бежево-оранжевый цвет предупреждения вместо пугающего красного
    final exceededColor =
        isDark ? const Color(0xFFF59E0B) : const Color(0xFFEA7A35);

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFEF4444),
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Icon(Icons.delete_rounded, color: colorScheme.onError),
    );

    final glassBg = isExceeded
        ? exceededColor.withValues(alpha: isDark ? 0.14 : 0.08)
        : (isDark
            ? const Color(0xFF141416).withValues(alpha: 0.70)
            : Colors.white.withValues(alpha: 0.85));

    final glassBorder = isExceeded
        ? exceededColor.withValues(alpha: isDark ? 0.40 : 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFE2E8F0));

    final cardContent = Container(
      decoration: BoxDecoration(
        color: glassBg,
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxCategoryWidth = constraints.maxWidth * 0.45;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: maxCategoryWidth),
                          child: Text(
                            budget.category.getLocalizedName(context),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CurrencyFormatter.formatText(
                                    currentSpent,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isExceeded
                                          ? exceededColor
                                          : colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    ' / ',
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isExceeded
                                          ? exceededColor
                                          : colorScheme.primary,
                                    ),
                                  ),
                                  CurrencyFormatter.formatText(
                                    budget.limitAmount,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isExceeded
                                          ? exceededColor
                                          : colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  color: isExceeded ? exceededColor : colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                if (isExceeded) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${context.l10n.budget_exceeded} ${CurrencyFormatter.format(currentSpent - budget.limitAmount, showSymbol: true)}!',
                    style: textTheme.bodySmall?.copyWith(
                      color: exceededColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(24)),
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
