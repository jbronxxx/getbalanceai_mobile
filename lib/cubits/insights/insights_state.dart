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
  /// Free: сколько отчётов в месяц на бесплатном тарифе (подпись у кнопки);
  /// `null` — Pro.
  final int? freeReportsPerMonth;

  const InsightsAwaitingRequest({
    this.freeReportsPerMonth,
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

  /// Операций меньше [InsightsCubit.minTransactions].
  notEnoughTransactions,
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

/// Что можно сделать с устаревшим отчётом.
enum InsightsRefresh {
  /// Перегенерировать сейчас.
  available,

  /// Free: обновление отчёта — в Pro.
  proOnly,

  /// Pro: дневной лимит исчерпан, новый отчёт — завтра.
  tomorrow,
}

class InsightsLoaded extends InsightsState {
  final List<String> insights;
  final DateTime? generatedAt;

  /// Отчёт сохранённый, а операции или лимиты месяца изменились после его
  /// генерации: суммы в тексте могут не совпадать с экраном «Бюджет».
  final bool isOutdated;

  /// Можно ли перегенерировать устаревший отчёт.
  final InsightsRefresh refresh;

  const InsightsLoaded({
    required this.insights,
    this.generatedAt,
    this.isOutdated = false,
    this.refresh = InsightsRefresh.available,
    required super.selectedMonth,
    required super.selectedYear,
  });
}

/// Отчёт не загрузился (сбой ИИ или сервера) — «помощники заняты»; обрыв
/// связи — [InsightsNetworkError]. Повтор — pull-to-refresh.
class InsightsError extends InsightsState {
  const InsightsError({
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
