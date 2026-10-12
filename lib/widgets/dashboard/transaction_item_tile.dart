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
      child: Icon(Icons.delete_rounded, color: colorScheme.onError),
    );

    final item = Dismissible(
      key: Key(transaction.localId.toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: background,
      child: Material(
        color: Colors.transparent,
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
            constraints: const BoxConstraints(maxWidth: 140),
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
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                ),
                if (transaction.currency !=
                    CurrencyFormatter.currentCurrency) ...[
                  const SizedBox(height: 2),
                  Text(
                    '≈ ${CurrencyFormatter.format(isExpense ? -transaction.effectiveBaseAmount : transaction.effectiveBaseAmount, showSign: false)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
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
