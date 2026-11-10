import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_icon_badge.dart';
import '../one_line_label.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'transaction_item_tile.dart';

/// Строка ожидаемого регулярного платежа в ленте дня: бледная, название
/// платежа (без названия — категория), пометка «Ожидается» (или «Не
/// оплачено», если срок прошёл) и ожидаемая сумма.
/// Тап открывает карточку платежа с «Оплачено».
class RecurringOccurrenceTile extends StatelessWidget {
  final RecurringOccurrence occurrence;
  final VoidCallback onTap;

  /// Текущий момент; параметр нужен для детерминированных тестов.
  final DateTime? now;

  /// Насколько бледнее строки записи: платёж ещё не совершён.
  static const pendingOpacity = 0.6;

  /// Отступ между значком ⟳ и пометкой «Ожидается».
  static const _statusIconGap = 4.0;

  const RecurringOccurrenceTile({
    super.key,
    required this.occurrence,
    required this.onTap,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final payment = occurrence.payment;
    final isExpense = payment.type == TransactionType.expense;
    final overdue = occurrence.isOverdue(now ?? DateTime.now());
    final status = overdue
        ? context.l10n.recurring_not_paid
        : context.l10n.recurring_expected;
    final statusColor = overdue ? colorScheme.error : colorScheme.outline;
    // Название платежа («Интернет»); категорию показывает иконка
    final title = payment.displayName(context);
    final titleStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );
    final statusStyle = textTheme.bodySmall?.copyWith(
      color: statusColor,
      fontSize: AppFontSize.hint,
    );

    return Material(
      color: TransactionItemTile.backgroundColor(context),
      child: LayoutBuilder(
        builder: (context, constraints) => ListTile(
          key: ValueKey('recurring_${payment.uid}'),
          onTap: onTap,
          leading: Opacity(
            opacity: pendingOpacity,
            child: CategoryIconBadge(category: payment.category),
          ),
          title: Opacity(
            opacity: pendingOpacity,
            child: OneLineLabel(
              title,
              alignment: AlignmentDirectional.centerStart,
              style: titleStyle,
            ),
          ),
          // Как OneLineLabel: при нехватке места пометка слегка
          // уменьшается, а не обрезается «…»
          subtitle: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text.rich(
              TextSpan(children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.only(end: _statusIconGap),
                    child: Icon(Icons.repeat_rounded,
                        size: AppFontSize.hint, color: statusColor),
                  ),
                ),
                TextSpan(text: status),
              ]),
              maxLines: 1,
              softWrap: false,
              style: statusStyle,
            ),
          ),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(
              // Сумма не теснит ни название, ни пометку со значком ⟳ под ним
              maxWidth: math.min(
                TransactionItemTile.amountMaxWidth(
                  context,
                  tileWidth: constraints.maxWidth,
                  title: title,
                  titleStyle: titleStyle,
                ),
                TransactionItemTile.amountMaxWidth(
                  context,
                  tileWidth: constraints.maxWidth,
                  title: status,
                  titleStyle: statusStyle,
                  titleExtra:
                      MediaQuery.textScalerOf(context).scale(AppFontSize.hint) +
                          _statusIconGap,
                ),
              ),
            ),
            child: Opacity(
              opacity: pendingOpacity,
              child: CurrencyFormatter.formatText(
                isExpense ? -payment.amount : payment.amount,
                currency: payment.currency,
                showSign: true,
                useFittedBox: true,
                textAlign: TextAlign.end,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isExpense
                      ? colorScheme.onSurface
                      : AppColors.of(context).accentText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
