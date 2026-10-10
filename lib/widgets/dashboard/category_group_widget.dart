import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'transaction_item_tile.dart';

/// Виджет группы транзакций по категории с раскрывающимся списком (ExpansionTile).
class CategoryGroupWidget extends StatelessWidget {
  final Category category;
  final List<Transaction> transactions;
  final bool showHintOnFirstTransaction;
  final void Function(Transaction) onTransactionTap;
  final void Function(Transaction) onTransactionDelete;
  final VoidCallback? onHintShown;

  const CategoryGroupWidget({
    super.key,
    required this.category,
    required this.transactions,
    this.showHintOnFirstTransaction = false,
    required this.onTransactionTap,
    required this.onTransactionDelete,
    this.onHintShown,
  });

  static IconData getCategoryIcon(Category category) {
    switch (category) {
      case Category.food:
        return Icons.shopping_cart;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final total = transactions.fold<double>(0, (sum, t) {
      return t.type == TransactionType.income ? sum + t.amount : sum - t.amount;
    });

    final categoryIcon = getCategoryIcon(category);
    final categoryColor = getCategoryColor(category);
    final bgColor = categoryColor.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: ExpansionTile(
        key: Key('expansion_${category.name}_$showHintOnFirstTransaction'),
        initiallyExpanded: showHintOnFirstTransaction,
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
          ),
          child: Icon(categoryIcon, color: categoryColor, size: 20),
        ),
        title: Text(
          category.getLocalizedName(context),
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: CurrencyFormatter.formatText(
            total,
            textAlign: TextAlign.end,
            showSign: true,
            showSymbol: false,
            useFittedBox: true,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: total >= 0 ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
        ),
        children: transactions.asMap().entries.map((entry) {
          final isFirst = entry.key == 0;
          return TransactionItemTile(
            transaction: entry.value,
            isFirst: isFirst,
            showHint: showHintOnFirstTransaction && isFirst,
            onTap: () => onTransactionTap(entry.value),
            onDelete: () => onTransactionDelete(entry.value),
            onHintShown: isFirst ? onHintShown : null,
          );
        }).toList(),
      ),
    );
  }
}
