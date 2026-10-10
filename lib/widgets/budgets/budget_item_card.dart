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

    final progress = budget.limitAmount > 0
        ? (currentSpent / budget.limitAmount).clamp(0.0, 1.0)
        : 0.0;
    final isExceeded = currentSpent > budget.limitAmount;

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: colorScheme.error,
      child: Icon(Icons.delete, color: colorScheme.onError),
    );

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExceeded
              ? colorScheme.error.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Material(
          color: theme.cardColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        budget.category.getLocalizedName(context),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
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
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  ' / ',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isExceeded
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                  ),
                                ),
                                CurrencyFormatter.formatText(
                                  budget.limitAmount,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isExceeded
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    color: isExceeded ? colorScheme.error : colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  if (isExceeded) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${context.l10n.budget_exceeded} ${CurrencyFormatter.format(currentSpent - budget.limitAmount, showSymbol: true)}!',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
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

    if (isFirst) {
      return SwipeHintWrapper(
        showHint: showSwipeHint,
        background: background,
        onHintShown: onHintShown,
        child: dismissibleItem,
      );
    }

    return dismissibleItem;
  }
}
