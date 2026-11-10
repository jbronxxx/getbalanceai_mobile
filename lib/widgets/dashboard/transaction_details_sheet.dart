import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';
import '../category_icon_badge.dart';
import '../app_sheet.dart';
import '../sheet_buttons.dart';
import '../detail_row.dart';
import '../whole_words_text.dart';
import '../../theme/app_colors.dart';

/// Действие, выбранное в карточке операции.
enum TransactionDetailsAction {
  edit,
  delete,

  /// Открыть регулярный платёж, оплатой которого стала запись.
  recurring,
}

/// Карточка операции «только для чтения»: полное описание, категория, дата
/// и время, для иностранной валюты — сумма чека и пересчёт. Редактирование
/// и удаление — явными кнопками.
class TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;

  /// Регулярный платёж, оплатой которого стала запись: строка «Повтор»
  /// открывает его карточку.
  final RecurringOccurrence? recurring;

  const TransactionDetailsSheet({
    super.key,
    required this.transaction,
    this.recurring,
  });

  /// Поля кнопок уже стандартных (16 + 24 у кнопки с иконкой): в половине
  /// ширины телефона 360 dp иначе «Редактировать» не помещается в полный
  /// размер.
  /// Открывает карточку; возвращает выбранное действие или `null`.
  static Future<TransactionDetailsAction?> show(
    BuildContext context,
    Transaction transaction, {
    RecurringOccurrence? recurring,
  }) {
    return showModalBottomSheet<TransactionDetailsAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => TransactionDetailsSheet(
        transaction: transaction,
        recurring: recurring,
      ),
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
    final description = t.description.trim();

    return Container(
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SheetHandle(bottomMargin: 20),
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
                  color: isExpense
                      ? colorScheme.onSurface
                      : AppColors.of(context).accentText,
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
              DetailRow(
                label: context.l10n.category_label,
                child: CategoryInlineLabel(category: t.category),
              ),
              DetailRow(
                label: context.l10n.date_label,
                child: Text(
                  LanguageManager.formatDateTime(t.date),
                  style: textTheme.bodyMedium,
                ),
              ),
              if (recurring case final recurring?)
                DetailRow(
                  label: context.l10n.recurring_repeat_label,
                  child: InkWell(
                    key: const ValueKey('transaction_details_recurring'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(
                        context, TransactionDetailsAction.recurring),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat_rounded,
                            size: 18, color: AppColors.of(context).accentText),
                        const SizedBox(width: 6),
                        Flexible(
                          child: WholeWordsText(
                            context.l10n.recurring_every_day(
                                recurring.payment.dayOfMonth),
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.of(context).accentText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.of(context).accentText),
                      ],
                    ),
                  ),
                ),
              if (isForeign) ...[
                DetailRow(
                  label: context.l10n.details_original_amount,
                  child: CurrencyFormatter.formatText(
                    t.amount,
                    currency: t.currency,
                    style: textTheme.bodyMedium,
                    // Сумма не обрезается «…» при крупном шрифте
                    useFittedBox: true,
                  ),
                ),
                DetailRow(
                  label: context.l10n.details_in_base_currency,
                  child: CurrencyFormatter.formatText(
                    t.effectiveBaseAmount,
                    prefix: '≈ ',
                    style: textTheme.bodyMedium,
                    // Сумма не обрезается «…» при крупном шрифте
                    useFittedBox: true,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SheetOutlinedButton(
                      key: const ValueKey('transaction_details_delete'),
                      label: context.l10n.delete_btn,
                      color: colorScheme.error,
                      onPressed: () => Navigator.pop(
                          context, TransactionDetailsAction.delete),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SheetPrimaryButton(
                      key: const ValueKey('transaction_details_edit'),
                      label: context.l10n.edit_btn,
                      onPressed: () =>
                          Navigator.pop(context, TransactionDetailsAction.edit),
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
