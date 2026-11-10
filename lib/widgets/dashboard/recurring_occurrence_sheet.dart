import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../category_icon_badge.dart';
import '../detail_row.dart';
import '../sheet_buttons.dart';
import '../whole_words_text.dart';
import '../../theme/app_colors.dart';

/// Действие, выбранное в карточке регулярного платежа.
enum RecurringOccurrenceAction { pay, skip, edit, stop }

/// Карточка регулярного платежа за месяц (в том же стиле, что карточка
/// операции): сумма, название, категория, дата платежа, повтор и срок.
/// Ожидающий платёж — «Оплачено» и «Пропустить месяц»; любой —
/// «Редактировать» и «Остановить».
class RecurringOccurrenceSheet extends StatelessWidget {
  final RecurringOccurrence occurrence;

  /// Текущий момент; параметр нужен для детерминированных тестов.
  final DateTime? now;

  const RecurringOccurrenceSheet({
    super.key,
    required this.occurrence,
    this.now,
  });

  /// Открывает карточку; возвращает выбранное действие или `null`.
  static Future<RecurringOccurrenceAction?> show(
    BuildContext context,
    RecurringOccurrence occurrence,
  ) {
    return showModalBottomSheet<RecurringOccurrenceAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => RecurringOccurrenceSheet(occurrence: occurrence),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;
    final payment = occurrence.payment;
    final isExpense = payment.type == TransactionType.expense;
    final description = payment.description.trim();
    final total = payment.totalPayments;
    final overdue = occurrence.isOverdue(now ?? DateTime.now());
    void pop(RecurringOccurrenceAction action) =>
        Navigator.pop(context, action);

    return Container(
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle(bottomMargin: 20)),
              WholeWordsText(
                isExpense
                    ? l10n.recurring_payment_title
                    : l10n.recurring_income_title,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              CurrencyFormatter.formatText(
                isExpense ? -payment.amount : payment.amount,
                currency: payment.currency,
                showSign: true,
                useFittedBox: true,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExpense
                      ? colorScheme.onSurface
                      : AppColors.of(context).accentText,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                WholeWordsText(
                  description,
                  style: textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
              ],
              const SizedBox(height: 20),
              DetailRow(
                label: l10n.category_label,
                child: CategoryInlineLabel(category: payment.category),
              ),
              DetailRow(
                label: l10n.recurring_due_label,
                child: WholeWordsText(
                  LanguageManager.formatDayMonthYear(occurrence.dueDate),
                  style: textTheme.bodyMedium?.copyWith(
                    color: overdue ? colorScheme.error : null,
                  ),
                ),
              ),
              DetailRow(
                label: l10n.recurring_repeat_label,
                child: WholeWordsText(
                  total == null
                      ? l10n.recurring_every_day(payment.dayOfMonth)
                      : l10n.recurring_progress(
                          payment.paymentNumberIn(occurrence.period), total),
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              if (occurrence.isPending) ...[
                SheetPrimaryButton(
                  key: const ValueKey('recurring_pay'),
                  label: isExpense
                      ? l10n.recurring_paid_btn
                      : l10n.recurring_received_btn,
                  onPressed: () => pop(RecurringOccurrenceAction.pay),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SheetOutlinedButton(
                    key: const ValueKey('recurring_skip'),
                    label: l10n.recurring_skip_btn,
                    onPressed: () => pop(RecurringOccurrenceAction.skip),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: SheetOutlinedButton(
                      key: const ValueKey('recurring_stop'),
                      label: l10n.recurring_stop_btn,
                      color: colorScheme.error,
                      onPressed: () => pop(RecurringOccurrenceAction.stop),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SheetPrimaryButton(
                      key: const ValueKey('recurring_edit'),
                      label: l10n.edit_btn,
                      onPressed: () => pop(RecurringOccurrenceAction.edit),
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
