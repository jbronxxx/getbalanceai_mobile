import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../swipe_hint_wrapper.dart';

/// Элемент строки транзакции с поддержкой свайпа для удаления.
class TransactionItemTile extends StatelessWidget {
  final Transaction transaction;
  final bool isFirst;
  final bool showHint;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onHintShown;

  const TransactionItemTile({
    super.key,
    required this.transaction,
    this.isFirst = false,
    this.showHint = false,
    required this.onTap,
    required this.onDelete,
    this.onHintShown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isExpense = transaction.type == TransactionType.expense;

    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: colorScheme.error,
      child: Icon(Icons.delete, color: colorScheme.onError),
    );

    final item = Dismissible(
      key: Key(transaction.localId.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: background,
      child: Material(
        color: theme.cardColor,
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          title: Text(
            transaction.description.isEmpty
                ? context.l10n.no_description
                : transaction.description,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: CurrencyFormatter.formatText(
              isExpense ? -transaction.amount : transaction.amount,
              textAlign: TextAlign.end,
              showSign: true,
              showSymbol: false,
              useFittedBox: true,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isExpense
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
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
