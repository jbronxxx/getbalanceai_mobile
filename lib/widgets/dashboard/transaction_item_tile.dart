import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import '../swipe_hint_wrapper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Строка операции в ленте дашборда: иконка категории, описание, категория
/// и сумма. Свайп влево удаляет (с отменой в тосте), тап открывает карточку.
///
/// [showDate] — для группировки по категориям: вместо категории (она уже в
/// заголовке группы) под описанием показывается день операции.
class TransactionItemTile extends StatelessWidget {
  final Transaction transaction;
  final bool isFirst;
  final bool showHint;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onHintShown;
  final bool showDate;

  const TransactionItemTile({
    super.key,
    required this.transaction,
    this.isFirst = false,
    this.showHint = false,
    required this.onTap,
    required this.onDelete,
    this.onHintShown,
    this.showDate = false,
  });

  /// Непрозрачный фон строки: сквозь него не просвечивает красная подложка
  /// удаления при свайпе.
  static Color backgroundColor(BuildContext context) =>
      AppColors.of(context).cardBackground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isExpense = transaction.type == TransactionType.expense;
    final category = transaction.category;
    final categoryColor = CategoryStyle.color(category);
    final categoryName = category.getLocalizedName(context);
    final hasDescription = transaction.description.trim().isNotEmpty;
    final secondary = showDate
        ? LanguageManager.formatDayMonth(transaction.date)
        : categoryName;
    final title = hasDescription ? transaction.description : secondary;

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: colorScheme.error,
      child: Icon(Icons.delete_rounded, color: colorScheme.onError),
    );

    final item = Dismissible(
      key: Key(transaction.localId.toString()),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: kSwipeDeleteThreshold,
      },
      onDismissed: (_) => onDelete(),
      background: background,
      child: Material(
        color: backgroundColor(context),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Icon(
              CategoryStyle.icon(category),
              color: categoryColor,
              size: 20,
            ),
          ),
          // Две строки: длинное описание читается в ленте без перехода
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: hasDescription
              ? Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                )
              : null,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CurrencyFormatter.formatText(
                  isExpense ? -transaction.amount : transaction.amount,
                  currency: transaction.currency,
                  textAlign: TextAlign.end,
                  showSign: true,
                  showSymbol: true,
                  useFittedBox: true,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isExpense
                        ? colorScheme.onSurface
                        : AppColors.of(context).accentText,
                  ),
                ),
                if (transaction.currency !=
                    CurrencyFormatter.currentCurrency) ...[
                  const SizedBox(height: 2),
                  CurrencyFormatter.formatText(
                    isExpense
                        ? -transaction.effectiveBaseAmount
                        : transaction.effectiveBaseAmount,
                    prefix: '≈ ',
                    textAlign: TextAlign.end,
                    useFittedBox: true,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: AppFontSize.micro,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (isFirst) {
      return SwipeHintWrapper(
        showHint: showHint,
        background: background,
        onHintShown: onHintShown,
        child: item,
      );
    }

    return item;
  }
}
