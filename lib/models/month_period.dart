/// Календарный месяц — период отображения данных на вкладках приложения.
class MonthPeriod {
  final int year;
  final int month;

  const MonthPeriod(this.year, this.month) : assert(month >= 1 && month <= 12);

  /// Месяц, в который попадает [now] (по умолчанию — текущий момент).
  factory MonthPeriod.current([DateTime? now]) {
    final date = now ?? DateTime.now();
    return MonthPeriod(date.year, date.month);
  }

  MonthPeriod get previous =>
      month == 1 ? MonthPeriod(year - 1, 12) : MonthPeriod(year, month - 1);

  MonthPeriod get next =>
      month == 12 ? MonthPeriod(year + 1, 1) : MonthPeriod(year, month + 1);

  bool isBefore(MonthPeriod other) =>
      year < other.year || (year == other.year && month < other.month);

  bool isAfter(MonthPeriod other) => other.isBefore(this);

  @override
  bool operator ==(Object other) =>
      other is MonthPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => 'MonthPeriod($year-$month)';
}
