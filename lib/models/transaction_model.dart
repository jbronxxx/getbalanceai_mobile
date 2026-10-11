import 'local_db_models.dart';

class TransactionModel {
  final String id;
  final double amount;
  final String description;
  final String category;
  final String type;
  final DateTime date;
  final DateTime? createdAt;
  final String currency;
  final double exchangeRate;
  final double baseAmount;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.type,
    required this.date,
    this.createdAt,
    this.currency = 'RUB',
    this.exchangeRate = 1.0,
    this.baseAmount = 0.0,
  });

  /// Разбирает транзакцию из ответа бэкенда REST API.
  ///
  /// Поддерживает парсинг `amount` из чисел и строкового формата `Decimal(12, 2)`,
  /// а также разбор полей дат `date` и `created_at` (с обратной совместимостью для `date_created`).
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final parsedDate = parseServerDate(json['date']) ??
        DateTime.parse(json['date'] as String).toLocal();
    final parsedCreatedAt = parseServerDate(json['created_at']) ??
        parseServerDate(json['date_created']);
    final parsedAmount = parseAmount(json['amount']);
    final parsedCurrency = (json['currency'] as String?) ??
        (json['currency_code'] as String?) ??
        'RUB';
    final parsedRate = json['exchange_rate'] != null
        ? parseAmount(json['exchange_rate'], 1.0)
        : 1.0;
    final parsedBaseAmount = json['base_amount'] != null
        ? parseAmount(json['base_amount'], parsedAmount * parsedRate)
        : (parsedAmount * parsedRate);

    return TransactionModel(
      id: json['id'] as String,
      amount: parsedAmount,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? Category.other.name,
      type: json['type'] as String? ?? TransactionType.expense.name,
      date: parsedDate,
      createdAt: parsedCreatedAt,
      currency: parsedCurrency,
      exchangeRate: parsedRate,
      baseAmount: parsedBaseAmount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'base_amount': baseAmount,
      'description': description,
      'category': category,
      'type': type,
      'date': date.toUtc().toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }
}
