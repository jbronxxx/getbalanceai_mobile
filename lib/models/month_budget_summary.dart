import '../utils/utils.dart';
import 'local_db_models.dart';
import 'month_period.dart';

/// Положение месяца относительно текущего.
enum BudgetPeriodState { past, current, future }

/// Сводка лимитов за месяц: сколько заложено, потрачено по лимитированным
/// категориям, остаток и сколько можно тратить в день до конца месяца.
///
/// Все суммы — в базовой валюте: траты приходят уже в ней, лимиты в своих
/// валютах переводятся по текущему курсу ([Budget.limitInBaseCurrency]).
class MonthBudgetSummary {
  final double totalLimit;
  final double totalSpent;
  final BudgetPeriodState periodState;

  /// Дней до конца месяца, включая сегодняшний (только для текущего месяца).
  final int daysLeft;

  /// Ожидающие оплаты регулярные платежи в категориях с лимитом: эти деньги
  /// ещё уйдут, поэтому в «можно тратить в день» они уже отложены.
  final double reservedAmount;
  final int reservedCount;

  const MonthBudgetSummary({
    required this.totalLimit,
    required this.totalSpent,
    required this.periodState,
    required this.daysLeft,
    this.reservedAmount = 0,
    this.reservedCount = 0,
  });

  /// [spentByCategory] — расходы месяца по категориям (ключ —
  /// [Budget.dbCategory]); учитываются только категории, на которые задан
  /// лимит. [reservedByCategory] — ожидающие оплаты регулярные платежи
  /// текущего месяца по категориям (сумма в базовой валюте и их число);
  /// так же учитываются только категории с лимитом.
  factory MonthBudgetSummary.calculate({
    required List<Budget> budgets,
    required Map<String, double> spentByCategory,
    required MonthPeriod period,
    Map<String, ({double amount, int count})> reservedByCategory = const {},
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final current = MonthPeriod.current(today);
    final state = period == current
        ? BudgetPeriodState.current
        : period.isBefore(current)
            ? BudgetPeriodState.past
            : BudgetPeriodState.future;

    var totalLimit = 0.0;
    var totalSpent = 0.0;
    var reservedAmount = 0.0;
    var reservedCount = 0;
    for (final b in budgets) {
      totalLimit += b.limitInBaseCurrency;
      totalSpent += spentByCategory[b.dbCategory] ?? 0;
      if (state == BudgetPeriodState.current) {
        final reserved = reservedByCategory[b.dbCategory];
        reservedAmount += reserved?.amount ?? 0;
        reservedCount += reserved?.count ?? 0;
      }
    }

    final daysInMonth = DateTime(period.year, period.month + 1, 0).day;
    final daysLeft =
        state == BudgetPeriodState.current ? daysInMonth - today.day + 1 : 0;

    return MonthBudgetSummary(
      totalLimit: totalLimit,
      totalSpent: totalSpent,
      periodState: state,
      daysLeft: daysLeft,
      reservedAmount: reservedAmount,
      reservedCount: reservedCount,
    );
  }

  bool get hasLimits => totalLimit > 0;

  /// Остаток по лимитам; отрицательный — перерасход.
  double get remaining => totalLimit - totalSpent;

  /// Перерасход — по остатку, округлённому до знаков базовой валюты:
  /// погрешность сложения double не должна давать «Перерасход 0.00».
  bool get isExceeded => CurrencyFormatter.roundToCurrency(remaining) < 0;

  /// Доля потраченного (0..∞), для индикатора.
  double get spentRatio => totalLimit > 0 ? totalSpent / totalLimit : 0;

  /// Сколько можно тратить в день до конца текущего месяца, чтобы уложиться
  /// в лимиты, с учётом отложенного на регулярные платежи; 0 при перерасходе
  /// и для нетекущих месяцев.
  double get dailyAllowance {
    if (periodState != BudgetPeriodState.current || daysLeft <= 0) return 0;
    final free = remaining - reservedAmount;
    return free > 0 ? free / daysLeft : 0;
  }
}
