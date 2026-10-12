import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import 'category_group_widget.dart';

/// Виджет дневной группы транзакций, сгруппированных по категориям.
class DayGroupWidget extends StatelessWidget {
  final DateTime date;
  final Map<Category, List<Transaction>> categories;
  final bool showHintOnFirstCategory;
  final void Function(Transaction) onTransactionTap;
  final void Function(Transaction) onTransactionDelete;
  final VoidCallback? onHintShown;

  const DayGroupWidget({
    super.key,
    required this.date,
    required this.categories,
    this.showHintOnFirstCategory = false,
    required this.onTransactionTap,
    required this.onTransactionDelete,
    this.onHintShown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final formattedDate = LanguageManager.formatDayMonth(date);
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            isToday ? '${context.l10n.today}, $formattedDate' : formattedDate,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.outline,
            ),
          ),
        ),
        ...categories.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final categoryEntry = entry.value;
          final isFirst = idx == 0;

          return CategoryGroupWidget(
            key: ValueKey(
                'category_group_${date.millisecondsSinceEpoch}_${categoryEntry.key.name}'),
            date: date,
            category: categoryEntry.key,
            transactions: categoryEntry.value,
            showHintOnFirstTransaction: showHintOnFirstCategory && isFirst,
            onTransactionTap: onTransactionTap,
            onTransactionDelete: onTransactionDelete,
            onHintShown: isFirst ? onHintShown : null,
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}
