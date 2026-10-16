import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import '../swipe_hint_wrapper.dart';
import '../../theme/app_colors.dart';

/// Карточка элемента бюджета с индикатором выполнения и поддержкой свайпа для удаления.
///
/// [currentSpent] и все суммы карточки — в валюте лимита.
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
  static Color progressColorFor(double ratio, AppColors colors) {
    if (ratio > 1) return colors.exceeded;
    if (ratio >= 0.75) return colors.warning;
    return colors.accentText;
  }

  /// Суммы карточки — в валюте лимита.
  String _display(double amount, {bool showSymbol = true}) =>
      CurrencyFormatter.format(
        amount,
        showSymbol: showSymbol,
        currency: budget.currency,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final colors = AppColors.of(context);

    final ratio =
        budget.limitAmount > 0 ? currentSpent / budget.limitAmount : 0.0;
    final progress = ratio.clamp(0.0, 1.0);
    final isExceeded = currentSpent > budget.limitAmount;
    final percent = (ratio * 100).round();

    final exceededColor = colors.exceeded;
    final progressColor = progressColorFor(ratio, colors);

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(Icons.delete_rounded, color: colorScheme.onError),
    );

    final baseBg = colors.cardBackground;
    final cardBg = isExceeded
        ? Color.alphaBlend(
            exceededColor.withValues(alpha: isDark ? 0.16 : 0.08),
            baseBg,
          )
        : baseBg;

    final glassBorder = isExceeded
        ? exceededColor.withValues(alpha: isDark ? 0.40 : 0.35)
        : colors.cardBorder;

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
                : AppColors.of(context).cardShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Подпись отличает остаток от потраченного под шкалой
                          if (!isExceeded)
                            Text(
                              context.l10n.budget_remaining,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          CurrencyFormatter.formatText(
                            (budget.limitAmount - currentSpent).abs(),
                            currency: budget.currency,
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
                        ],
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
                          _display(currentSpent, showSymbol: false),
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
      dismissThresholds: const {
        DismissDirection.endToStart: kSwipeDeleteThreshold,
      },
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
