import 'local_db_models.dart';

class BudgetModel {
  final String? id;
  final String category;
  final double limitAmount;

  /// Код валюты лимита; `null` — ответ сервера без валюты лимита.
  final String? currency;
  final int month;
  final int year;
  final bool isDeleted;

  BudgetModel({
    this.id,
    required this.category,
    required this.limitAmount,
    this.currency,
    required this.month,
    required this.year,
    this.isDeleted = false,
  });

  /// Разбирает один элемент бюджета из ответа бэкенда.
  ///
  /// Поддерживает безопасный парсинг `limit_amount`, `month`, `year`
  /// как из числовых (num), так и из строковых представлений (Decimal/Numeric).
  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String?,
      category: json['category'] as String,
      limitAmount: parseAmount(json['limit_amount']),
      currency: (json['currency'] as String?)?.toUpperCase(),
      month: parseInteger(json['month']),
      year: parseInteger(json['year']),
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'limit_amount': limitAmount,
      if (currency != null) 'currency': currency,
      'month': month,
      'year': year,
      if (isDeleted) 'is_deleted': true,
    };
  }
}
