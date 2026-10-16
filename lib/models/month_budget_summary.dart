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

  const MonthBudgetSummary({
    required this.totalLimit,
    required this.totalSpent,
    required this.periodState,
    required this.daysLeft,
  });

  /// [spentByCategory] — расходы месяца по категориям; учитываются только
  /// категории, на которые задан лимит.
  factory MonthBudgetSummary.calculate({
    required List<Budget> budgets,
    required Map<Category, double> spentByCategory,
    required MonthPeriod period,
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
    for (final b in budgets) {
      totalLimit += b.limitInBaseCurrency;
      totalSpent += spentByCategory[b.category] ?? 0;
    }

    final daysInMonth = DateTime(period.year, period.month + 1, 0).day;
    final daysLeft =
        state == BudgetPeriodState.current ? daysInMonth - today.day + 1 : 0;

    return MonthBudgetSummary(
      totalLimit: totalLimit,
      totalSpent: totalSpent,
      periodState: state,
      daysLeft: daysLeft,
    );
  }

  bool get hasLimits => totalLimit > 0;

  /// Остаток по лимитам; отрицательный — перерасход.
  double get remaining => totalLimit - totalSpent;

  bool get isExceeded => totalSpent > totalLimit;

  /// Доля потраченного (0..∞), для индикатора.
  double get spentRatio => totalLimit > 0 ? totalSpent / totalLimit : 0;

  /// Сколько можно тратить в день до конца текущего месяца, чтобы уложиться
  /// в лимиты; 0 при перерасходе и для нетекущих месяцев.
  double get dailyAllowance {
    if (periodState != BudgetPeriodState.current || daysLeft <= 0) return 0;
    return remaining > 0 ? remaining / daysLeft : 0;
  }
}
