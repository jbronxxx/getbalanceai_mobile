import 'local_db_models.dart';
import '../utils/currency_formatter.dart';

/// Формат файла выгрузки отчёта.
enum ReportFormat {
  csv('csv', 'text/csv'),
  pdf('pdf', 'application/pdf');

  final String extension;
  final String mimeType;

  const ReportFormat(this.extension, this.mimeType);
}

/// Как доставить готовый файл: отправить через меню «Поделиться» или
/// сохранить в память устройства.
enum ReportDeliveryMode { share, save }

/// Результат выгрузки.
enum ReportExportOutcome {
  /// За период нет операций, файл не создавался.
  empty,

  /// Файл передан в меню «Поделиться» или сохранён.
  completed,

  /// Пользователь закрыл диалог выбора места сохранения.
  cancelled,
}

/// Период отчёта: обе границы включительно, время отбрасывается.
class ReportPeriod {
  final DateTime start;
  final DateTime end;

  ReportPeriod(DateTime start, DateTime end)
      : start = DateTime(start.year, start.month, start.day),
        end = DateTime(end.year, end.month, end.day);

  /// Календарный месяц.
  factory ReportPeriod.month(int month, int year) =>
      ReportPeriod(DateTime(year, month, 1), DateTime(year, month + 1, 0));

  /// Календарный год.
  factory ReportPeriod.year(int year) =>
      ReportPeriod(DateTime(year, 1, 1), DateTime(year, 12, 31));

  /// Начало периода в миллисекундах (включительно).
  int get startMilliseconds => start.millisecondsSinceEpoch;

  /// Начало следующего за периодом дня в миллисекундах (исключительно).
  int get endExclusiveMilliseconds =>
      DateTime(end.year, end.month, end.day + 1).millisecondsSinceEpoch;

  /// Месяцы, которые период покрывает целиком, как пары (месяц, год).
  List<({int month, int year})> get fullMonths {
    final result = <({int month, int year})>[];
    var cursor = DateTime(start.year, start.month, 1);
    while (!cursor.isAfter(end)) {
      final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
      if (!cursor.isBefore(start) && !monthEnd.isAfter(end)) {
        result.add((month: cursor.month, year: cursor.year));
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }
}

/// Операция в отчёте: исходная сумма и сумма в базовой валюте отчёта.
class ReportTransaction {
  final DateTime date;
  final TransactionType type;
  final Category category;
  final String description;
  final double amount;
  final Currency currency;
  final double baseAmount;

  const ReportTransaction({
    required this.date,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.currency,
    required this.baseAmount,
  });
}

/// Выполнение лимита по категории за месяц, полностью входящий в период.
class ReportBudgetLine {
  final Category category;
  final int month;
  final int year;
  final double limit;
  final double spent;

  const ReportBudgetLine({
    required this.category,
    required this.month,
    required this.year,
    required this.limit,
    required this.spent,
  });

  bool get isExceeded => spent > limit;
}

/// Данные отчёта за период, собранные из локальной базы.
class ReportData {
  final ReportPeriod period;
  final Currency currency;
  final DateTime generatedAt;
  final List<ReportTransaction> transactions;
  final List<ReportBudgetLine> budgetLines;

  const ReportData({
    required this.period,
    required this.currency,
    required this.generatedAt,
    required this.transactions,
    required this.budgetLines,
  });

  double get totalIncome => _sum(TransactionType.income);

  double get totalExpense => _sum(TransactionType.expense);

  double get balance => totalIncome - totalExpense;

  /// Расходы по категориям в базовой валюте, от больших к меньшим.
  List<MapEntry<Category, double>> get categoryExpenses {
    final totals = <Category, double>{};
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        totals[t.category] = (totals[t.category] ?? 0) + t.baseAmount;
      }
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  double _sum(TransactionType type) => transactions
      .where((t) => t.type == type)
      .fold(0.0, (acc, t) => acc + t.baseAmount);
}
