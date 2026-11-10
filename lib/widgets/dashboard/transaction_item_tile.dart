import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_icon_badge.dart';
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

  /// Запись «Оплачено» регулярного платежа — рядом с названием значок ⟳.
  final bool isRecurring;

  const TransactionItemTile({
    super.key,
    required this.transaction,
    this.isFirst = false,
    this.showHint = false,
    required this.onTap,
    required this.onDelete,
    this.onHintShown,
    this.showDate = false,
    this.isRecurring = false,
  });

  /// Непрозрачный фон строки: сквозь него не просвечивает красная подложка
  /// удаления при свайпе.
  static Color backgroundColor(BuildContext context) =>
      AppColors.of(context).cardBackground;

  static const _iconSize = CategoryIconBadge.size;
  static const _gap = 16.0; // ListTile.horizontalTitleGap по умолчанию
  static const _groupIndent = 72.0;

  /// Сколько места отдать сумме в строке ленты: название категории (или
  /// день) получает свою ширину — при крупном шрифте не «Пита…», сумма —
  /// остальное, но не меньше 40% строки. [titleExtra] — ширина значка
  /// рядом с названием. [withIcon] — строка с иконкой
  /// категории слева, иначе — с отступом под текст заголовка группы.
  static double amountMaxWidth(
    BuildContext context, {
    required double tileWidth,
    required String title,
    required TextStyle? titleStyle,
    double titleExtra = 0,
    bool withIcon = true,
  }) =>
      OneLineLabel.spaceBeside(
        context,
        available: tileWidth -
            (withIcon ? 2 * _gap + _iconSize + _gap : _groupIndent + _gap) -
            _gap,
        title: title,
        titleStyle: titleStyle,
        titleExtra: titleExtra,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isExpense = transaction.type == TransactionType.expense;
    final category = transaction.category;
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
            leading: showDate ? null : CategoryIconBadge(category: category),
            // Длинное название при крупном шрифте слегка уменьшается,
            // а не обрезается «…»
            title: Row(
              children: [
                Flexible(
                  child: OneLineLabel(
                    title,
                    alignment: AlignmentDirectional.centerStart,
                    style: titleStyle,
                  ),
                ),
                if (isRecurring)
                  Padding(
                    key: const ValueKey('transaction_recurring_mark'),
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: AppFontSize.hint,
                      color: colorScheme.outline,
                    ),
                  ),
              ],
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
                maxWidth: amountMaxWidth(
                  context,
                  tileWidth: constraints.maxWidth,
                  title: title,
                  titleStyle: titleStyle,
                  withIcon: !showDate,
                ),
              ),
              // Сумма и «≈ в основной валюте» при крупном шрифте могут не
              // поместиться и по высоте строки — тогда обе слегка уменьшаются
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
