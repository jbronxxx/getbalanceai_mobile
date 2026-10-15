import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import 'transaction_item_tile.dart';

/// Операции одной категории за месяц.
class CategoryMonthSummary {
  final Category category;
  final List<Transaction> transactions;

  /// Итог в базовой валюте: доходы со знаком «+», расходы — «−».
  final double total;

  const CategoryMonthSummary({
    required this.category,
    required this.transactions,
    required this.total,
  });

  /// Группирует операции месяца по категориям. Сначала самые крупные по
  /// модулю итога (расходы и доходы вперемешку — важнее масштаб), внутри
  /// группы порядок исходного списка (новые сверху).
  static List<CategoryMonthSummary> fromTransactions(
    List<Transaction> transactions,
  ) {
    final byCategory = <Category, List<Transaction>>{};
    for (final t in transactions) {
      byCategory.putIfAbsent(t.category, () => []).add(t);
    }
    final summaries = [
      for (final entry in byCategory.entries)
        CategoryMonthSummary(
          category: entry.key,
          transactions: entry.value,
          total: entry.value.fold<double>(0, (sum, t) {
            final base = t.effectiveBaseAmount;
            return t.type == TransactionType.income ? sum + base : sum - base;
          }),
        ),
    ];
    summaries.sort((a, b) => b.total.abs().compareTo(a.total.abs()));
    return summaries;
  }
}

/// Карточка категории за месяц: итог и число операций, по тапу раскрывается
/// список операций с датами.
class CategoryMonthGroup extends StatefulWidget {
  final CategoryMonthSummary summary;
  final void Function(Transaction) onTransactionTap;
  final void Function(Transaction) onTransactionDelete;

  const CategoryMonthGroup({
    super.key,
    required this.summary,
    required this.onTransactionTap,
    required this.onTransactionDelete,
  });

  @override
  State<CategoryMonthGroup> createState() => _CategoryMonthGroupState();
}

class _CategoryMonthGroupState extends State<CategoryMonthGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final summary = widget.summary;
    final categoryColor = CategoryStyle.color(summary.category);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TransactionItemTile.backgroundColor(theme),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('category_group_${summary.category.name}'),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Container(
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
                          CategoryStyle.icon(summary.category),
                          color: categoryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.category.getLocalizedName(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              LanguageManager.formatOperationsCount(
                                summary.transactions.length,
                              ),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: CurrencyFormatter.formatText(
                          summary.total,
                          showSign: true,
                          textAlign: TextAlign.end,
                          useFittedBox: true,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: summary.total >= 0
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Column(
                      children: [
                        for (final t in summary.transactions) ...[
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 72,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                          TransactionItemTile(
                            key: ValueKey('category_transaction_${t.localId}'),
                            transaction: t,
                            showDate: true,
                            onTap: () => widget.onTransactionTap(t),
                            onDelete: () => widget.onTransactionDelete(t),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
