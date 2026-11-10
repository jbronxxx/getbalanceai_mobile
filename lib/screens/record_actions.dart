import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/utils.dart';
import '../widgets/dashboard/dashboard.dart';
import '../widgets/widgets.dart';
import 'add_transaction_sheet.dart';

/// Действия из карточек записи и регулярного платежа — общие для «Баланса»
/// и поиска: правка, удаление с отменой, «Оплачено», пропуск месяца,
/// остановка регулярного платежа.
abstract final class RecordActions {
  /// Карточка записи: «Редактировать», «Удалить» ([onDelete] — экран
  /// скрывает запись и предлагает отмену) и, для оплаты регулярного платежа,
  /// переход к нему.
  static Future<void> openTransaction(
    BuildContext context,
    Transaction transaction, {
    required void Function(Transaction) onDelete,
  }) async {
    final recurring =
        RecurringPaymentService.instance.occurrenceForRecord(transaction);
    final action = await TransactionDetailsSheet.show(
      context,
      transaction,
      recurring: recurring,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case TransactionDetailsAction.edit:
        AddTransactionSheet.show(context, transactionToEdit: transaction);
      case TransactionDetailsAction.delete:
        onDelete(transaction);
      case TransactionDetailsAction.recurring:
        if (recurring != null) await openRecurring(context, recurring);
    }
  }

  /// Карточка регулярного платежа за месяц и выбранное в ней действие.
  static Future<void> openRecurring(
    BuildContext context,
    RecurringOccurrence occurrence,
  ) async {
    final action = await RecurringOccurrenceSheet.show(context, occurrence);
    if (!context.mounted || action == null) return;
    final service = RecurringPaymentService.instance;
    final l10n = context.l10n;
    switch (action) {
      case RecurringOccurrenceAction.pay:
        AddTransactionSheet.show(context, occurrence: occurrence);
      case RecurringOccurrenceAction.edit:
        AddTransactionSheet.show(context, recurringToEdit: occurrence.payment);
      case RecurringOccurrenceAction.skip:
        service.skip(occurrence);
        AppAlerts.showToast(
          context,
          message: l10n.recurring_skipped_toast,
          // Столько же, сколько на отмену остановки и удаления
          duration: UndoableDeletions.recurringPayments.delay,
          actionLabel: l10n.undo_action,
          onAction: () => service.unskip(occurrence),
        );
      case RecurringOccurrenceAction.stop:
        final deletions = UndoableDeletions.recurringPayments;
        deletions.schedule(occurrence.payment);
        AppAlerts.showToast(
          context,
          message: l10n.recurring_stopped_toast,
          duration: deletions.delay,
          actionLabel: l10n.undo_action,
          onAction: () => deletions.undo(occurrence.payment),
        );
    }
  }
}
