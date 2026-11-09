import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import '../one_line_label.dart';
import '../swipe_to_delete.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Строка операции в ленте дашборда: иконка категории, категория, описание
/// под ней и сумма. Свайп влево удаляет (с отменой в тосте), тап открывает
/// карточку.
///
/// [showDate] — для группировки по категориям: без иконки (она уже в
/// заголовке группы), с отступом под текст заголовка; вместо категории
/// показывается день операции.
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

  static const _iconSize = 40.0;
  static const _gap = 16.0; // ListTile.horizontalTitleGap по умолчанию
  static const _groupIndent = 72.0;

  /// Сколько места отдать сумме: название категории (или день) получает
  /// свою ширину — при крупном шрифте не «Пита…», сумма — остальное, но не
  /// меньше 40% строки.
  double _amountMaxWidth(
    BuildContext context,
    double tileWidth,
    String title,
    TextStyle? style,
  ) =>
      OneLineLabel.spaceBeside(
        context,
        available: tileWidth -
            (showDate ? _groupIndent + _gap : 2 * _gap + _iconSize + _gap) -
            _gap,
        title: title,
        titleStyle: style,
      );

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
    final title = showDate
        ? LanguageManager.formatDayMonth(transaction.date)
        : categoryName;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );

    // Строка прямоугольная: углы скругляет карточка дня или категории,
    // в которой она лежит.
    return SwipeToDelete(
      dismissKey: Key(transaction.localId.toString()),
      showHint: isFirst && showHint,
      onHintShown: onHintShown,
      onDelete: onDelete,
      child: LayoutBuilder(
        builder: (context, constraints) => Material(
          color: backgroundColor(context),
          child: ListTile(
            onTap: onTap,
            // В группе категории текст выравнивается по заголовку группы
            contentPadding: showDate
                ? const EdgeInsets.only(left: _groupIndent, right: _gap)
                : const EdgeInsets.symmetric(horizontal: _gap),
            leading: showDate
                ? null
                : Container(
                    width: _iconSize,
                    height: _iconSize,
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
            // Длинное название при крупном шрифте слегка уменьшается,
            // а не обрезается «…»
            title: OneLineLabel(
              title,
              alignment: AlignmentDirectional.centerStart,
              style: titleStyle,
            ),
            subtitle: hasDescription
                ? Text(
                    transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: AppFontSize.hint,
                    ),
                  )
                : null,
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _amountMaxWidth(
                    context, constraints.maxWidth, title, titleStyle),
              ),
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
      ),
    );
  }
}
