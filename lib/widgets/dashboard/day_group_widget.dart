import 'package:flutter/material.dart';
import '../whole_words_text.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'recurring_occurrence_tile.dart';
import 'transaction_item_tile.dart';
import '../../theme/app_colors.dart';

/// Операции одного дня: заголовок с датой и итогом дня, под ним — карточка
/// со строками операций и ожидаемых в этот день регулярных платежей.
class DayGroupWidget extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;

  /// Регулярные платежи этого дня, ещё не оплаченные: в итог дня не входят.
  final List<RecurringOccurrence> occurrences;
  final void Function(RecurringOccurrence)? onOccurrenceTap;

  /// `serverId` записей «Оплачено» регулярных платежей — со значком ⟳.
  final Set<String> recurringRecordIds;
  final bool showHintOnFirstTransaction;
  final void Function(Transaction) onTransactionTap;
  final void Function(Transaction) onTransactionDelete;
  final VoidCallback? onHintShown;

  /// Показывать год в заголовке, если он не текущий, — для списков за
  /// несколько лет (поиск); в ленте месяца год и так виден в шапке.
  final bool showYear;

  const DayGroupWidget({
    super.key,
    required this.date,
    required this.transactions,
    this.occurrences = const [],
    this.onOccurrenceTap,
    this.recurringRecordIds = const {},
    this.showHintOnFirstTransaction = false,
    required this.onTransactionTap,
    required this.onTransactionDelete,
    this.onHintShown,
    this.showYear = false,
  });

  /// Группирует операции по дням (новые дни сверху). Внутри дня сохраняется
  /// порядок выборки — новые операции сверху.
  static Map<DateTime, List<Transaction>> groupByDay(
    List<Transaction> transactions,
  ) {
    final grouped = <DateTime, List<Transaction>>{};
    for (final t in transactions) {
      grouped.putIfAbsent(DateUtils.dateOnly(t.date), () => []).add(t);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final day in days) day: grouped[day]!};
  }

  /// Итог дня в базовой валюте: доходы минус расходы. Суммы берутся в
  /// базовой валюте, чтобы итоги дней сходились с карточкой месяца.
  static double dayTotal(List<Transaction> transactions) {
    return transactions.fold<double>(0, (sum, t) {
      final base = t.effectiveBaseAmount;
      return t.type == TransactionType.income ? sum + base : sum - base;
    });
  }

  /// Дни ленты: дни операций и дни ожидаемых платежей, новые сверху.
  static List<DateTime> mergeDays(
    Iterable<DateTime> transactionDays,
    Iterable<DateTime> occurrenceDays,
  ) =>
      {...transactionDays, ...occurrenceDays.map(DateUtils.dateOnly)}.toList()
        ..sort((a, b) => b.compareTo(a));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final formattedDate = showYear
        ? LanguageManager.formatDayMonthYear(date)
        : LanguageManager.formatDayMonth(date);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final headerStyle = textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: colorScheme.outline,
    );
    final borderColor = AppColors.of(context).cardBorder;
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: WholeWordsText(
                  isToday
                      ? '${context.l10n.today}, $formattedDate'
                      : formattedDate,
                  style: headerStyle,
                ),
              ),
              if (transactions.isNotEmpty)
                CurrencyFormatter.formatText(
                  dayTotal(transactions),
                  showSign: true,
                  textAlign: TextAlign.end,
                  style: headerStyle,
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: TransactionItemTile.backgroundColor(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.of(context).cardShadow,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                for (var i = 0; i < transactions.length; i++) ...[
                  if (i > 0) divider,
                  TransactionItemTile(
                    key: ValueKey('transaction_${transactions[i].localId}'),
                    transaction: transactions[i],
                    isFirst: i == 0,
                    showHint: showHintOnFirstTransaction && i == 0,
                    onTap: () => onTransactionTap(transactions[i]),
                    onDelete: () => onTransactionDelete(transactions[i]),
                    onHintShown: i == 0 ? onHintShown : null,
                    isRecurring:
                        recurringRecordIds.contains(transactions[i].serverId),
                  ),
                ],
                for (var i = 0; i < occurrences.length; i++) ...[
                  if (transactions.isNotEmpty || i > 0) divider,
                  RecurringOccurrenceTile(
                    occurrence: occurrences[i],
                    onTap: () => onOccurrenceTap?.call(occurrences[i]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
