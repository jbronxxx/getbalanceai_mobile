import '../models/models.dart';
import '../utils/currency_formatter.dart';
import 'currency_exchange_service.dart';
import 'local_db_service.dart';
import 'undoable_deletions.dart';

/// Собирает данные отчёта из локальной базы (без обращения к бэкенду).
class ReportDataService {
  final LocalDbService? _db;
  final CurrencyExchangeService? _exchange;
  final bool Function(Transaction t)? _isPendingDeletion;

  /// [isPendingDeletion] — операция скрыта в ожидании удаления и в отчёт не
  /// попадает; по умолчанию — общая очередь [UndoableDeletions.transactions].
  ReportDataService({
    LocalDbService? db,
    CurrencyExchangeService? exchange,
    bool Function(Transaction t)? isPendingDeletion,
  })  : _db = db,
        _exchange = exchange,
        _isPendingDeletion = isPendingDeletion;

  /// Читает операции и лимиты за [period] и приводит суммы к базовой валюте.
  ReportData build(ReportPeriod period, {Currency? currency, DateTime? now}) {
    final db = _db ?? LocalDbService.instance;
    final isPendingDeletion =
        _isPendingDeletion ?? UndoableDeletions.transactions.isPending;
    final budgets = <Budget>[
      for (final m in period.fullMonths)
        ...db.getBudgetsForPeriod(m.month, m.year),
    ];
    return assemble(
      period: period,
      currency: currency ?? CurrencyFormatter.currentCurrency,
      transactions: db
          .getTransactionsInRange(period)
          .where((t) => !isPendingDeletion(t))
          .toList(),
      budgets: budgets,
      exchange: _exchange ?? CurrencyExchangeService.instance,
      now: now ?? DateTime.now(),
    );
  }

  /// Чистая сборка отчёта из уже прочитанных сущностей.
  ///
  /// Лимиты попадают в отчёт только за месяцы, целиком входящие в период:
  /// сравнивать месячный лимит с неполными тратами было бы некорректно.
  static ReportData assemble({
    required ReportPeriod period,
    required Currency currency,
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required CurrencyExchangeService exchange,
    required DateTime now,
  }) {
    double toBase(Transaction t) => t.currency == currency
        ? t.amount
        : exchange.convert(t.amount, from: t.currency, to: currency);

    final rows = [
      for (final t in transactions)
        ReportTransaction(
          date: t.date,
          type: t.type,
          category: t.category,
          description: t.description,
          amount: t.amount,
          currency: t.currency,
          baseAmount: toBase(t),
        ),
    ];

    // Лимит — в своей валюте (без валюты — в базовой, т. е. валюте отчёта);
    // в отчёте все суммы в валюте отчёта
    double limitInReportCurrency(Budget b) {
      if (b.currencyCode == null || b.currency == currency) {
        return b.limitAmount;
      }
      return exchange.convert(b.limitAmount, from: b.currency, to: currency);
    }

    final lines = <ReportBudgetLine>[];
    for (final b in budgets) {
      // По хранимой категории: неизвестные клиенту категории не сливаются
      // в «Прочее» и не попадают в траты чужих лимитов.
      final spent = transactions
          .where((t) =>
              t.type == TransactionType.expense &&
              t.dbCategory == b.dbCategory &&
              t.date.month == b.month &&
              t.date.year == b.year)
          .fold(0.0, (acc, t) => acc + toBase(t));
      lines.add(ReportBudgetLine(
        category: b.category,
        month: b.month,
        year: b.year,
        limit: limitInReportCurrency(b),
        spent: spent,
      ));
    }
    lines.sort((a, b) {
      final byDate = (a.year * 12 + a.month).compareTo(b.year * 12 + b.month);
      return byDate != 0
          ? byDate
          : a.category.index.compareTo(b.category.index);
    });

    return ReportData(
      period: period,
      currency: currency,
      generatedAt: now,
      transactions: rows,
      budgetLines: lines,
    );
  }
}
