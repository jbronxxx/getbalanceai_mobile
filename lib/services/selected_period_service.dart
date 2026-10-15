import 'package:flutter/foundation.dart';
import '../models/month_period.dart';

/// Выбранный месяц, общий для вкладок «Баланс», «Финансы» и «Аналитика».
///
/// Вкладки подписываются на [periodNotifier]: смена месяца на одной вкладке
/// сразу отражается на остальных. Доступный диапазон — [yearRange] лет
/// назад и вперёд от текущего года. Между запусками не сохраняется:
/// приложение всегда открывается на текущем месяце.
class SelectedPeriodService {
  SelectedPeriodService._();

  static final SelectedPeriodService instance = SelectedPeriodService._();

  static const int yearRange = 5;

  final ValueNotifier<MonthPeriod> periodNotifier =
      ValueNotifier(MonthPeriod.current());

  MonthPeriod get period => periodNotifier.value;

  /// Самый ранний доступный месяц.
  MonthPeriod get earliest => MonthPeriod(DateTime.now().year - yearRange, 1);

  /// Самый поздний доступный месяц.
  MonthPeriod get latest => MonthPeriod(DateTime.now().year + yearRange, 12);

  bool get canGoBack => period.isAfter(earliest);

  bool get canGoForward => period.isBefore(latest);

  /// Выбирает месяц; значения вне доступного диапазона игнорируются.
  void select(MonthPeriod value) {
    if (value.isBefore(earliest) || value.isAfter(latest)) return;
    periodNotifier.value = value;
  }

  void previous() {
    if (canGoBack) select(period.previous);
  }

  void next() {
    if (canGoForward) select(period.next);
  }

  /// Возвращает текущий месяц (между тестами и при сбросе состояния).
  void reset() {
    periodNotifier.value = MonthPeriod.current();
  }
}
