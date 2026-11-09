import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';
import 'transaction_item_tile.dart';
import '../../theme/app_colors.dart';

/// Операции одной категории одного типа за месяц.
///
/// Тип входит в группу: «Прочее» бывает и доходом, и расходом, и в общей
/// группе они взаимно гасились бы до нуля.
class CategoryMonthSummary {
  final Category category;
  final TransactionType type;
  final List<Transaction> transactions;

  /// Итог в базовой валюте: доходы со знаком «+», расходы — «−».
  final double total;

  const CategoryMonthSummary({
    required this.category,
    required this.type,
    required this.transactions,
    required this.total,
  });

  /// Уникальный в пределах месяца ключ группы.
  String get id => '${category.name}_${type.name}';

  /// Группирует операции месяца по категориям и типу. Сначала самые крупные по
  /// модулю итога (расходы и доходы вперемешку — важнее масштаб), внутри
  /// группы порядок исходного списка (новые сверху).
  static List<CategoryMonthSummary> fromTransactions(
    List<Transaction> transactions,
  ) {
    final groups = <(Category, TransactionType), List<Transaction>>{};
    for (final t in transactions) {
      groups.putIfAbsent((t.category, t.type), () => []).add(t);
    }
    final summaries = [
      for (final entry in groups.entries)
        CategoryMonthSummary(
          category: entry.key.$1,
          type: entry.key.$2,
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
    final summary = widget.summary;
    final categoryColor = CategoryStyle.color(summary.category);
    final borderColor = AppColors.of(context).cardBorder;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            Semantics(
              container: true,
              button: true,
              expanded: _expanded,
              onTapHint: _expanded
                  ? context.l10n.category_group_collapse_hint
                  : context.l10n.category_group_expand_hint,
              child: Material(
                color: AppColors.transparent,
                child: InkWell(
                  key: ValueKey('category_group_${summary.id}'),
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
                        // Название — во всю ширину, сумма — второй строкой
                        // справа от числа операций: суммы в сотни миллионов
                        // сумов в одной строке с названием обрезали его.
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
                              const SizedBox(height: 2),
                              LayoutBuilder(
                                builder: (context, constraints) => Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.l10n.operations_count(
                                          summary.transactions.length,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      // Числу операций остаётся хотя бы
                                      // четверть строки
                                      constraints: BoxConstraints(
                                        maxWidth: constraints.maxWidth * 0.75,
                                      ),
                                      child: CurrencyFormatter.formatText(
                                        summary.total,
                                        showSign: true,
                                        textAlign: TextAlign.end,
                                        useFittedBox: true,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: summary.total >= 0
                                              ? AppColors.of(context).accentText
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
