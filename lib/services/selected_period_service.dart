import 'dart:async';

import 'package:flutter/widgets.dart';
import '../models/month_period.dart';

/// Выбранный месяц, общий для вкладок «Баланс», «Финансы» и «Аналитика».
///
/// Вкладки подписываются на [periodNotifier]: смена месяца на одной вкладке
/// сразу отражается на остальных. Доступный диапазон — [yearRange] лет
/// назад и вперёд от текущего года; те же границы у календарей (дата
/// операции, свой период выгрузки), чтобы любая введённая операция была
/// видна в шапке. Между запусками не сохраняется: приложение всегда
/// открывается на текущем месяце.
class SelectedPeriodService {
  SelectedPeriodService._();

  static final SelectedPeriodService instance = SelectedPeriodService._();

  /// На сколько лет назад и вперёд от текущего можно выбрать месяц.
  static const int yearRange = 5;

  final ValueNotifier<MonthPeriod> periodNotifier =
      ValueNotifier(MonthPeriod.current());

  /// Месяц, который был текущим при последней сверке с часами.
  MonthPeriod _calendarMonth = MonthPeriod.current();

  AppLifecycleListener? _lifecycle;
  Timer? _monthTimer;

  MonthPeriod get period => periodNotifier.value;

  /// Самый ранний доступный месяц.
  MonthPeriod get earliest => MonthPeriod(DateTime.now().year - yearRange, 1);

  /// Самый поздний доступный месяц.
  MonthPeriod get latest => MonthPeriod(DateTime.now().year + yearRange, 12);

  /// Первый день доступного диапазона — для календарей.
  DateTime get firstDate => DateTime(earliest.year, earliest.month);

  /// Последний день доступного диапазона — для календарей.
  DateTime get lastDate => DateTime(latest.year, latest.month + 1, 0);

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

  /// Следит за сменой месяца, пока приложение открыто: в полночь первого
  /// числа и при возврате из фона. Повторный вызов ничего не делает.
  void start() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(onResume: syncWithCalendar);
    syncWithCalendar();
  }

  /// Если наступил новый месяц, а пользователь смотрел прошлый текущий,
  /// переключает на новый текущий. Выбранный вручную другой месяц не
  /// трогает. [now] — для тестов.
  void syncWithCalendar([DateTime? now]) {
    final clock = now ?? DateTime.now();
    final current = MonthPeriod.current(clock);
    if (current != _calendarMonth) {
      final wasOnCurrent = period == _calendarMonth;
      _calendarMonth = current;
      if (wasOnCurrent) periodNotifier.value = current;
    }
    if (_lifecycle != null) _scheduleMonthTimer(clock);
  }

  /// Будильник на начало следующего месяца, пока приложение на экране.
  void _scheduleMonthTimer(DateTime now) {
    _monthTimer?.cancel();
    final nextMonth = DateTime(now.year, now.month + 1);
    // Секунда запаса: таймер не должен сработать за мгновение до полуночи.
    final delay = nextMonth.difference(now) + const Duration(seconds: 1);
    _monthTimer = Timer(delay, syncWithCalendar);
  }

  /// Возвращает текущий месяц (между тестами и при сбросе состояния).
  void reset() {
    _calendarMonth = MonthPeriod.current();
    periodNotifier.value = _calendarMonth;
  }
}
