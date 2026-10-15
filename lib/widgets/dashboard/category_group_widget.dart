import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'transaction_item_tile.dart';

/// Виджет группы транзакций по категории с раскрывающимся списком (ExpansionTile).
class CategoryGroupWidget extends StatefulWidget {
  final Category category;
  final List<Transaction> transactions;
  final DateTime? date;
  final bool showHintOnFirstTransaction;
  final void Function(Transaction) onTransactionTap;
  final void Function(Transaction) onTransactionDelete;
  final VoidCallback? onHintShown;

  const CategoryGroupWidget({
    super.key,
    required this.category,
    required this.transactions,
    this.date,
    this.showHintOnFirstTransaction = false,
    required this.onTransactionTap,
    required this.onTransactionDelete,
    this.onHintShown,
  });

  static IconData getCategoryIcon(Category category) {
    switch (category) {
      case Category.food:
        return Icons.restaurant_rounded;
      case Category.transport:
        return Icons.directions_bus;
      case Category.salary:
        return Icons.monetization_on;
      case Category.entertainment:
        return Icons.movie;
      case Category.health:
        return Icons.medical_services;
      case Category.shopping:
        return Icons.shopping_bag;
      case Category.subscriptions:
        return Icons.subscriptions;
      case Category.freelance:
        return Icons.laptop_mac;
      case Category.investments:
        return Icons.trending_up;
      case Category.transfers:
        return Icons.swap_horiz;
      case Category.cashback:
        return Icons.savings;
      case Category.sales:
        return Icons.sell;
      case Category.other:
        return Icons.category;
    }
  }

  static Color getCategoryColor(Category category) {
    switch (category) {
      case Category.food:
        return const Color(0xFFF97316);
      case Category.transport:
        return const Color(0xFF3B82F6);
      case Category.salary:
        return const Color(0xFF0F766E);
      case Category.entertainment:
        return const Color(0xFFA855F7);
      case Category.health:
        return const Color(0xFFEF4444);
      case Category.shopping:
        return const Color(0xFFEC4899);
      case Category.subscriptions:
        return const Color(0xFF6366F1);
      case Category.freelance:
        return const Color(0xFFD97706);
      case Category.investments:
        return const Color(0xFF10B981);
      case Category.transfers:
        return const Color(0xFF06B6D4);
      case Category.cashback:
        return const Color(0xFF14B8A6);
      case Category.sales:
        return const Color(0xFFEA580C);
      case Category.other:
        return const Color(0xFF64748B);
    }
  }

  @override
  State<CategoryGroupWidget> createState() => _CategoryGroupWidgetState();
}

class _CategoryGroupWidgetState extends State<CategoryGroupWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.showHintOnFirstTransaction;
  }

  @override
  void didUpdateWidget(CategoryGroupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showHintOnFirstTransaction !=
            oldWidget.showHintOnFirstTransaction &&
        widget.showHintOnFirstTransaction) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Суммируем транзакции строго в базовой валюте, чтобы итог категории
    // полностью сходился с верхним общим балансом и расходом
    final totalBase = widget.transactions.fold<double>(0, (sum, t) {
      final baseAmt = t.effectiveBaseAmount;
      return t.type == TransactionType.income ? sum + baseAmt : sum - baseAmt;
    });

    final baseCurrency = CurrencyFormatter.currentCurrency;
    final foreignTransactions =
        widget.transactions.where((t) => t.currency != baseCurrency).toList();

    String? foreignSubtitle;
    if (foreignTransactions.isNotEmpty) {
      final firstForeignCurrency = foreignTransactions.first.currency;
      final isSingleForeignCurrency =
          widget.transactions.every((t) => t.currency == firstForeignCurrency);

      if (isSingleForeignCurrency) {
        // Если все транзакции в категории совершены в одной иностранной валюте,
        // показываем сумму в этой валюте
        final foreignTotal = widget.transactions.fold<double>(0, (sum, t) {
          return t.type == TransactionType.income
              ? sum + t.amount
              : sum - t.amount;
        });
        foreignSubtitle = CurrencyFormatter.format(
          foreignTotal,
          currency: firstForeignCurrency,
          showSign: true,
          showSymbol: true,
        );
      } else {
        // Если в категории операции в разных валютах, перечисляем уникальные коды
        final uniqueCodes =
            widget.transactions.map((t) => t.currency.code).toSet().join(' • ');
        foreignSubtitle = uniqueCodes;
      }
    }

    final categoryIcon = CategoryGroupWidget.getCategoryIcon(widget.category);
    final categoryColor = CategoryGroupWidget.getCategoryColor(widget.category);
    final bgColor = categoryColor.withValues(alpha: 0.12);

    final isDark = theme.brightness == Brightness.dark;
    final glassBg = isDark
        ? const Color(0xFF141416).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.85);
    final glassBorder =
        isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: glassBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'category_expansion_${widget.date?.millisecondsSinceEpoch ?? 0}_${widget.category.name}_${widget.showHintOnFirstTransaction}',
        ),
        initiallyExpanded: widget.showHintOnFirstTransaction,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: categoryColor.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Icon(categoryIcon, color: categoryColor, size: 20),
        ),
        title: Text(
          widget.category.getLocalizedName(context),
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          LanguageManager.formatOperationsCount(widget.transactions.length),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
            fontSize: 11,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CurrencyFormatter.formatText(
                    totalBase,
                    textAlign: TextAlign.end,
                    showSign: true,
                    showSymbol: true,
                    useFittedBox: true,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: totalBase >= 0
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (foreignSubtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      foreignSubtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colorScheme.outline,
                size: 22,
              ),
            ),
          ],
        ),
        children: widget.transactions.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          return TransactionItemTile(
            transaction: entry.value,
            isFirst: isFirst,
            showHint: widget.showHintOnFirstTransaction && isFirst,
            onTap: () => widget.onTransactionTap(entry.value),
            onDelete: () => widget.onTransactionDelete(entry.value),
            onHintShown: isFirst ? widget.onHintShown : null,
          );
        }).toList(),
      ),
    );
  }
}
