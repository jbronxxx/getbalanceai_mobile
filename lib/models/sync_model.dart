class SyncModel {
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;
  final List<Map<String, dynamic>> recurringPayments;
  final List<String>? deletedBudgetIds;
  final List<String>? deletedTransactionIds;
  final List<String>? deletedRecurringPaymentIds;

  SyncModel({
    required this.transactions,
    required this.budgets,
    this.recurringPayments = const [],
    this.deletedBudgetIds,
    this.deletedTransactionIds,
    this.deletedRecurringPaymentIds,
  });

  Map<String, dynamic> toJson() => {
        'transactions': transactions,
        'budgets': budgets,
        if (recurringPayments.isNotEmpty)
          'recurring_payments': recurringPayments,
        if (deletedBudgetIds != null && deletedBudgetIds!.isNotEmpty)
          'deleted_budget_ids': deletedBudgetIds,
        if (deletedTransactionIds != null && deletedTransactionIds!.isNotEmpty)
          'deleted_transaction_ids': deletedTransactionIds,
        if (deletedRecurringPaymentIds != null &&
            deletedRecurringPaymentIds!.isNotEmpty)
          'deleted_recurring_payment_ids': deletedRecurringPaymentIds,
      };
}
