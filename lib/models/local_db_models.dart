import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:objectbox/objectbox.dart';

/// Разбирает дату из ответа бэкенда, возвращая `null` вместо исключения.
///
/// Бэкенд отдаёт ISO-строку, но поле может отсутствовать или прийти не
/// строкой; `DateTime.parse` в этих случаях бросает исключение и роняет
/// разбор всей выгрузки, поэтому используется `tryParse`.
DateTime? parseServerDate(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Безопасно разбирает денежную сумму / число с плавающей точкой из JSON.
///
/// Поддерживает форматы:
/// - [num] (int / double, например: `150.5`, `100`)
/// - [String] (например: `"150.50"`, `"100.00"`, `"100"` — формат Decimal / Numeric(12, 2))
///
/// Если значение `null`, некорректная строка или неподдерживаемый тип,
/// возвращает [fallback] (по умолчанию `0.0`).
double parseAmount(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    return parsed?.toDouble() ?? fallback;
  }
  return fallback;
}

/// Безопасно разбирает целочисленное значение из JSON.
///
/// Поддерживает форматы [num] и [String].
/// Если значение `null` или некорректно, возвращает [fallback] (по умолчанию `0`).
int parseInteger(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value.trim());
    return parsed?.toInt() ?? fallback;
  }
  return fallback;
}

/// Тип операции: доход или расход.
enum TransactionType {
  income,
  expense;

  /// Строковое значение из БД/JSON -> enum. Неизвестное значение трактуется
  /// как расход — самый безопасный дефолт для финансового приложения (лучше
  /// по ошибке показать лишний расход, чем скрыть трату).
  static TransactionType fromString(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => TransactionType.expense,
    );
  }

  /// Возвращает локализованное название типа транзакции.
  String getLocalizedName([BuildContext? context]) {
    final l = context != null ? context.l10n : LanguageManager.l10n;
    switch (this) {
      case TransactionType.income:
        return l.type_income;
      case TransactionType.expense:
        return l.type_expense;
    }
  }
}

/// Категория транзакции/бюджета.
enum Category {
  food,
  transport,
  entertainment,
  health,
  subscriptions,
  shopping,
  salary,
  freelance,
  investments,
  transfers,
  cashback,
  sales,
  other;

  /// Допустимые категории для доходов.
  static const incomeCategories = [
    Category.salary,
    Category.freelance,
    Category.investments,
    Category.transfers,
    Category.cashback,
    Category.sales,
    Category.other,
  ];

  /// Допустимые категории для расходов.
  static const expenseCategories = [
    Category.food,
    Category.transport,
    Category.entertainment,
    Category.health,
    Category.subscriptions,
    Category.shopping,
    Category.other,
  ];

  /// Строковое значение из БД/JSON -> enum. Неизвестная категория
  /// (например, добавленная бэкендом позже, но ещё не поддержанная в
  /// клиенте) сворачивается в [Category.other], а не падает с ошибкой.
  static Category fromString(String type) {
    return Category.values.firstWhere(
      (e) => e.name == type,
      orElse: () => Category.other,
    );
  }

  /// Возвращает локализованное название категории.
  String getLocalizedName([BuildContext? context]) {
    final l = context != null ? context.l10n : LanguageManager.l10n;
    switch (this) {
      case Category.food:
        return l.category_food;
      case Category.transport:
        return l.category_transport;
      case Category.entertainment:
        return l.category_entertainment;
      case Category.health:
        return l.category_health;
      case Category.subscriptions:
        return l.category_subscriptions;
      case Category.shopping:
        return l.category_shopping;
      case Category.salary:
        return l.category_salary;
      case Category.freelance:
        return l.category_freelance;
      case Category.investments:
        return l.category_investments;
      case Category.transfers:
        return l.category_transfers;
      case Category.cashback:
        return l.category_cashback;
      case Category.sales:
        return l.category_sales;
      case Category.other:
        return l.category_other;
    }
  }
}

/// Запись о доходе или расходе.
///
/// Хранится локально в ObjectBox (`localId` — первичный ключ базы) и
/// синхронизируется с бэкендом (`serverId` — ID записи на сервере, `null`
/// пока запись не отправлена — см. [LocalDbService.getUnsyncedTransactions]).
///
/// `dbCategory`/`dbType`/`dateMilliseconds` — представление, понятное
/// ObjectBox (энумы и DateTime он напрямую не хранит), а типобезопасные
/// [category]/[type]/[date] — то, чем пользуется остальной код.
@Entity()
class Transaction {
  @Id()
  int localId;

  @Unique()
  String? serverId;

  final double amount;
  final String description;
  final String dbCategory;
  final String dbType;
  final int dateMilliseconds;
  final int dateCreatedMilliseconds;
  bool isModified;

  Transaction({
    this.localId = 0,
    this.serverId,
    required this.amount,
    required this.description,
    required this.dbCategory,
    required this.dbType,
    required this.dateMilliseconds,
    required this.dateCreatedMilliseconds,
    this.isModified = false,
  });

  @Transient()
  Category get category => Category.fromString(dbCategory);

  @Transient()
  TransactionType get type => TransactionType.fromString(dbType);

  @Transient()
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMilliseconds);

  /// Разбирает ответ бэкенда (FastAPI) в локальную модель.
  ///
  /// Разбор намеренно устойчив к отсутствующим и неожиданным полям: этот
  /// factory — единственная точка входа для данных, приезжающих с сервера
  /// при полной выгрузке (см. `ApiService.syncBackendDataToLocal`), и падение
  /// на одной битой записи оставило бы локальную базу рассинхронизированной.
  /// В частности, `amount` безопасно парсится из чисел или строк Decimal(12, 2),
  /// а `date_created` бэкенд возвращает не во всех ответах, поэтому при его
  /// отсутствии берём дату самой операции.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    final date = parseServerDate(json['date']) ?? DateTime.now();

    return Transaction(
      serverId: json['id'] as String?,
      amount: parseAmount(json['amount']),
      description: json['description'] as String? ?? '',
      dbCategory: json['category'] as String? ?? Category.other.name,
      dbType: json['type'] as String? ?? TransactionType.expense.name,
      dateMilliseconds: date.millisecondsSinceEpoch,
      dateCreatedMilliseconds: (parseServerDate(json['created_at']) ??
              parseServerDate(json['date_created']) ??
              date)
          .millisecondsSinceEpoch,
      isModified: false,
    );
  }

  /// Формирует тело запроса к бэкенду в формате его API.
  Map<String, dynamic> toJson() {
    return {
      if (serverId != null) 'id': serverId,
      'amount': amount,
      'description': description,
      'category': category.name,
      'type': type.name,
      'date': date.toUtc().toIso8601String(),
    };
  }
}

/// Лимит расходов по категории на конкретный месяц/год.
///
/// `spent`/`remaining` — снимок состояния на момент сохранения лимита;
/// актуальные потраченные суммы для отображения в UI пересчитываются на
/// лету через [LocalDbService.getSpentForCategory], а не берутся из этих
/// полей напрямую.
@Entity()
class Budget {
  @Id()
  int localId;

  @Unique()
  String? serverId;

  final String dbCategory;
  final double limitAmount;
  final int month;
  final int year;
  final double spent;
  final double remaining;
  bool isModified;

  Budget({
    this.localId = 0,
    this.serverId,
    required this.dbCategory,
    required this.limitAmount,
    required this.month,
    required this.year,
    required this.spent,
    required this.remaining,
    this.isModified = false,
  });

  @Transient()
  Category get category => Category.fromString(dbCategory);

  /// Разбирает ответ бэкенда (FastAPI) в локальную модель.
  /// Устойчив к отсутствующим полям и поддерживает парсинг `limit_amount`,
  /// `spent`, `remaining` из Decimal/Numeric(12, 2) строк или чисел.
  ///
  /// `month`/`year` при отсутствии остаются нулевыми: такая запись не
  /// относится ни к одному периоду, и вызывающая сторона отбрасывает её
  /// через [isValidPeriod], а не пишет в базу мусор.
  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      serverId: json['id'] as String?,
      dbCategory: json['category'] as String? ?? Category.other.name,
      limitAmount: parseAmount(json['limit_amount']),
      month: parseInteger(json['month']),
      year: parseInteger(json['year']),
      spent: parseAmount(json['spent']),
      remaining: parseAmount(json['remaining']),
      isModified: false,
    );
  }

  /// Относится ли лимит к осмысленному месяцу/году.
  @Transient()
  bool get isValidPeriod => month >= 1 && month <= 12 && year > 0;

  /// Формирует тело запроса к бэкенду в формате его API.
  Map<String, dynamic> toJson({bool isDeleted = false}) {
    return {
      if (serverId != null) 'id': serverId,
      'category': category.name,
      'limit_amount': limitAmount,
      'month': month,
      'year': year,
      if (isDeleted) 'is_deleted': true,
    };
  }
}
