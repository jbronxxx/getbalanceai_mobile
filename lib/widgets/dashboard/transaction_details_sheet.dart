import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_style.dart';

/// Действие, выбранное в карточке операции.
enum TransactionDetailsAction { edit, delete }

/// Карточка операции «только для чтения»: полное описание, категория, дата
/// и время, для иностранной валюты — сумма чека и пересчёт. Редактирование
/// и удаление — явными кнопками.
class TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailsSheet({super.key, required this.transaction});

  /// Открывает карточку; возвращает выбранное действие или `null`.
  static Future<TransactionDetailsAction?> show(
    BuildContext context,
    Transaction transaction,
  ) {
    return showModalBottomSheet<TransactionDetailsAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailsSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final t = transaction;
    final isExpense = t.type == TransactionType.expense;
    final isForeign = t.currency != CurrencyFormatter.currentCurrency;
    final categoryColor = CategoryStyle.color(t.category);
    final description = t.description.trim();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                t.type.getLocalizedName(context),
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              CurrencyFormatter.formatText(
                isExpense ? -t.amount : t.amount,
                currency: t.currency,
                showSign: true,
                useFittedBox: true,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isExpense ? colorScheme.onSurface : colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                description.isNotEmpty
                    ? description
                    : context.l10n.no_description,
                key: const ValueKey('transaction_details_description'),
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                  color: description.isNotEmpty
                      ? colorScheme.onSurface
                      : colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              _DetailRow(
                label: context.l10n.category_label,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CategoryStyle.icon(t.category),
                      size: 18,
                      color: categoryColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        t.category.getLocalizedName(context),
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              _DetailRow(
                label: context.l10n.date_label,
                child: Text(
                  LanguageManager.formatDateTime(t.date),
                  style: textTheme.bodyMedium,
                ),
              ),
              if (isForeign) ...[
                _DetailRow(
                  label: context.l10n.details_original_amount,
                  child: CurrencyFormatter.formatText(
                    t.amount,
                    currency: t.currency,
                    style: textTheme.bodyMedium,
                  ),
                ),
                _DetailRow(
                  label: context.l10n.details_in_base_currency,
                  child: CurrencyFormatter.formatText(
                    t.effectiveBaseAmount,
                    prefix: '≈ ',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('transaction_details_delete'),
                      onPressed: () => Navigator.pop(
                          context, TransactionDetailsAction.delete),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(context.l10n.delete_btn),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('transaction_details_edit'),
                      onPressed: () =>
                          Navigator.pop(context, TransactionDetailsAction.edit),
                      icon: const Icon(Icons.edit_rounded),
                      label: Text(context.l10n.edit_btn),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}
