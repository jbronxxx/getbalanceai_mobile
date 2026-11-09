import 'package:flutter/material.dart';
import '../whole_words_text.dart';
import '../../models/models.dart';
import '../../services/local_db_service.dart';
import '../../utils/utils.dart';
import '../app_sheet.dart';
import '../category_style.dart';
import '../../theme/app_colors.dart';

/// Список операций, которые сервер не принял при выгрузке, с причиной
/// отказа у каждой. Тап по записи закрывает лист и возвращает её для правки.
class SyncRejectedSheet extends StatelessWidget {
  final List<Transaction> transactions;

  const SyncRejectedSheet({super.key, required this.transactions});

  /// Открывает лист с текущими отклонёнными операциями; возвращает
  /// выбранную для правки или `null`.
  static Future<Transaction?> show(BuildContext context) {
    return showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => SyncRejectedSheet(
        transactions: LocalDbService.instance.getRejectedTransactions(),
      ),
    );
  }

  /// Локализованная причина отказа по [Transaction.syncRejectCode].
  static String reasonText(AppLocalizations l10n, Transaction transaction) {
    switch (transaction.syncRejectCode) {
      case 'INVALID_CURRENCY':
        return l10n.sync_reject_invalid_currency;
      case 'INVALID_TRANSACTION_AMOUNT':
        return l10n.sync_reject_invalid_amount;
      case 'INVALID_CATEGORY':
        return l10n.sync_reject_invalid_category;
      case 'INVALID_AMOUNT':
        return l10n.sync_reject_invalid_amount_range;
      default:
        return l10n.sync_reject_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = context.l10n;

    return Container(
      decoration: AppSheet.decoration(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: SheetHandle(bottomMargin: 20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: WholeWordsText(
                l10n.sync_rejected_title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.sync_rejected_hint,
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: transactions.length,
                itemBuilder: (context, index) => _RejectedTile(
                  transaction: transactions[index],
                  onTap: () => Navigator.pop(context, transactions[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectedTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const _RejectedTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final t = transaction;
    final isExpense = t.type == TransactionType.expense;
    final categoryColor = CategoryStyle.color(t.category);
    final description = t.description.trim();
    final details = [
      LanguageManager.formatDayMonthYear(t.date),
      if (description.isNotEmpty) description,
    ].join(' · ');

    // Причина — под строкой на всю ширину, а не в колонке рядом с суммой:
    // длинный текст причины при крупном шрифте не рвёт слова.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CategoryStyle.icon(t.category),
                  color: categoryColor,
                  size: 20,
                ),
              ),
              title: Text(
                t.category.getLocalizedName(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              // Две строки: рядом с суммой в сотни миллионов сумов дата и описание
              // в одну строку обрезались.
              subtitle: WholeWordsText(
                details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: CurrencyFormatter.formatText(
                  isExpense ? -t.amount : t.amount,
                  currency: t.currency,
                  showSign: true,
                  useFittedBox: true,
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isExpense
                        ? colorScheme.onSurface
                        : AppColors.of(context).accentText,
                  ),
                ),
              ),
            ),
            Padding(
              // Под текстом строки: отступ 24 + иконка 40 + зазор 16
              padding: const EdgeInsetsDirectional.only(start: 80, end: 24),
              child: Text(
                SyncRejectedSheet.reasonText(context.l10n, t),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
