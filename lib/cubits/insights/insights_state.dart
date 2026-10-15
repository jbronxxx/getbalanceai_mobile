part of 'insights_cubit.dart';

@immutable
abstract class InsightsState {
  final int selectedMonth;
  final int selectedYear;

  const InsightsState({
    required this.selectedMonth,
    required this.selectedYear,
  });
}

class InsightsInitial extends InsightsState {
  const InsightsInitial({
    required super.selectedMonth,
    required super.selectedYear,
  });
}

/// Отчёта за период нет, генерация ждёт явного действия пользователя.
class InsightsAwaitingRequest extends InsightsState {
  const InsightsAwaitingRequest({
    required super.selectedMonth,
    required super.selectedYear,
  });
}

/// Почему анализ за период недоступен.
enum InsightsUnavailableReason {
  /// Месяц ещё не наступил.
  futureMonth,

  /// За месяц нет операций.
  noTransactions,
}

/// Анализировать нечего — запрос к AI не делается.
class InsightsUnavailable extends InsightsState {
  final InsightsUnavailableReason reason;

  const InsightsUnavailable(
    this.reason, {
    required super.selectedMonth,
    required super.selectedYear,
  });
}

class InsightsLoading extends InsightsState {
  const InsightsLoading({
    required super.selectedMonth,
    required super.selectedYear,
  });
}

class InsightsLoaded extends InsightsState {
  final List<String> insights;
  final DateTime? generatedAt;

  const InsightsLoaded({
    required this.insights,
    this.generatedAt,
    required super.selectedMonth,
    required super.selectedYear,
  });
}

class InsightsError extends InsightsState {
  final String message;

  const InsightsError(
    this.message, {
    required super.selectedMonth,
    required super.selectedYear,
  });
}

class InsightsNetworkError extends InsightsState {
  const InsightsNetworkError({
    required super.selectedMonth,
    required super.selectedYear,
  });
}

class InsightsUnauthenticated extends InsightsState {
  final String hint;

  const InsightsUnauthenticated(
    this.hint, {
    required super.selectedMonth,
    required super.selectedYear,
  });
}
