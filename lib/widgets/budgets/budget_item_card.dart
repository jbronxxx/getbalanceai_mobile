import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import '../one_line_label.dart';
import '../whole_words_text.dart';
import '../swipe_to_delete.dart';
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

  /// Цвет шкалы: перерасход, от 75% лимита — предупреждение, иначе основной.
  static Color progressColorFor(
    double ratio,
    AppColors colors, {
    required bool isExceeded,
  }) {
    if (isExceeded) return colors.exceeded;
    if (ratio >= 0.75) return colors.warning;
    return colors.accentText;
  }

  /// Сумма, которая не переносится посередине: пробелы между разрядами и
  /// перед символом валюты — неразрывные.
  static String _unbreakable(String amount) => amount.replaceAll(' ', '\u00A0');

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
    final categoryName = budget.category.getLocalizedName(context);
    final titleStyle = textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    );

    final ratio =
        budget.limitAmount > 0 ? currentSpent / budget.limitAmount : 0.0;
    final progress = ratio.clamp(0.0, 1.0);
    // Перерасход — по сумме, округлённой до знаков валюты: погрешность
    // double не должна давать «Превышен на $0.00».
    final isExceeded = CurrencyFormatter.roundToCurrency(
          currentSpent - budget.limitAmount,
          budget.currency,
        ) >
        0;
    final percent = (ratio * 100).round();

    final exceededColor = colors.exceeded;
    final progressColor =
        progressColorFor(ratio, colors, isExceeded: isExceeded);

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

    // Сдвигаемая часть — прямоугольная и непрозрачная: углы скругляет
    // SwipeToDelete сразу у карточки и красной подложки (см. его описание).
    final cardContent = Material(
      color: cardBg,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Icon(
                      CategoryStyle.icon(budget.category),
                      size: 20,
                      color: CategoryStyle.color(budget.category),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OneLineLabel(
                        categoryName,
                        alignment: AlignmentDirectional.centerStart,
                        style: titleStyle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Название категории получает свою ширину (при крупном
                    // шрифте не «Здор…»), сумма — остальное, но не меньше
                    // 40% строки; не помещаются — оба немного уменьшаются.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: OneLineLabel.spaceBeside(
                          context,
                          available: constraints.maxWidth - 20 - 8 - 12,
                          title: categoryName,
                          titleStyle: titleStyle,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Подпись «Осталось» / «Превышен на» — мелко над
                          // суммой: в одной строке с суммой она ужимала её.
                          OneLineLabel(
                            isExceeded
                                ? context.l10n.budget_exceeded
                                : context.l10n.budget_remaining,
                            alignment: AlignmentDirectional.centerEnd,
                            style: textTheme.labelSmall?.copyWith(
                              color: isExceeded
                                  ? exceededColor
                                  : colorScheme.outline,
                            ),
                          ),
                          CurrencyFormatter.formatText(
                            (budget.limitAmount - currentSpent).abs(),
                            currency: budget.currency,
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
                    // Потраченное и лимит — без переносов внутри суммы;
                    // длинная строка (сотни миллионов сумов) переходит на
                    // вторую строку целиком перед «из …»; при крупном шрифте
                    // — и на третью, без «…».
                    child: WholeWordsText(
                      context.l10n.budget_spent_of(
                        _unbreakable(_display(currentSpent, showSymbol: false)),
                        _unbreakable(_display(budget.limitAmount)),
                      ),
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
    );

    const radius = BorderRadius.all(Radius.circular(24));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        // Тень — под карточкой, рамка — поверх: при свайпе рамка остаётся
        // на месте и обводит и карточку, и подложку.
        decoration: BoxDecoration(
          borderRadius: radius,
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
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: glassBorder,
            width: isExceeded ? 1.2 : 1.0,
          ),
        ),
        child: SwipeToDelete(
          dismissKey: Key('budget_${budget.localId}'),
          borderRadius: radius,
          showHint: isFirst && showSwipeHint,
          onHintShown: onHintShown,
          onDelete: onDelete,
          child: cardContent,
        ),
      ),
    );
  }
}
