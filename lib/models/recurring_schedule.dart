import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import 'local_db_models.dart';
import 'month_period.dart';

/// Правила расписания регулярного платежа: когда он в каком месяце, оплачен
/// ли месяц, какой это платёж по счёту.
extension RecurringSchedule on RecurringPayment {
  /// Ключ месяца в [RecurringPayment.skippedPeriods] и в ID записи: `2026-11`.
  static String periodKey(MonthPeriod period) =>
      '${period.year}-${period.month.toString().padLeft(2, '0')}';

  /// День платежа [count]-го по счёту месяца, начиная с [start]: срок кредита
  /// «12 платежей» — дата последнего из них.
  static DateTime lastPaymentDate(DateTime start, int count) {
    final month = DateTime(start.year, start.month + count - 1);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, math.min(start.day, lastDay));
  }

  /// Сколько платежей с [start] по [end] включительно (день платежа —
  /// день [start]).
  static int paymentsCount(DateTime start, DateTime end) {
    final months = (end.year - start.year) * 12 + end.month - start.month;
    final lastDay = DateTime(end.year, end.month + 1, 0).day;
    final dueInLastMonth = math.min(start.day, lastDay);
    return end.day >= dueInLastMonth ? months + 1 : months;
  }

  /// Месяц первого платежа.
  MonthPeriod get startPeriod => MonthPeriod.current(start);

  /// День платежа в [period]: 31-е в коротком месяце — его последний день.
  DateTime dueDateIn(MonthPeriod period) {
    final lastDay = DateTime(period.year, period.month + 1, 0).day;
    return DateTime(period.year, period.month, math.min(dayOfMonth, lastDay));
  }

  /// Есть ли платёж в [period]: не раньше первого и не позже последнего дня.
  bool isDueIn(MonthPeriod period) {
    final due = dueDateIn(period);
    final last = end;
    return !due.isBefore(start) && (last == null || !due.isAfter(last));
  }

  bool isSkippedIn(MonthPeriod period) =>
      skippedPeriods.contains(periodKey(period));

  /// ID записи «Оплачено» за [period] — одинаковый на всех устройствах:
  /// повторная оплата того же месяца обновит запись, а не создаст вторую.
  String transactionIdIn(MonthPeriod period) => const Uuid().v5(
        Namespace.url.value,
        'getbalance.ai/recurring/$uid/${periodKey(period)}',
      );

  /// Номер платежа в [period], считая с первого (1, 2, …).
  int paymentNumberIn(MonthPeriod period) =>
      (period.year - startPeriod.year) * 12 +
      period.month -
      startPeriod.month +
      1;

  /// Всего платежей (кредит на 12 месяцев) или `null` — без срока.
  int? get totalPayments {
    final last = end;
    return last == null ? null : paymentsCount(start, last);
  }
}

/// Платёж в конкретном месяце: когда, оплачен ли и какой записью.
class RecurringOccurrence {
  final RecurringPayment payment;
  final MonthPeriod period;

  /// Запись «Оплачено» за этот месяц; `null` — ещё не оплачен.
  final Transaction? record;

  const RecurringOccurrence({
    required this.payment,
    required this.period,
    this.record,
  });

  DateTime get dueDate => payment.dueDateIn(period);

  bool get isPaid => record != null;

  bool get isSkipped => payment.isSkippedIn(period);

  /// Ждёт оплаты: не оплачен и не пропущен.
  bool get isPending => !isPaid && !isSkipped;

  String get transactionId => payment.transactionIdIn(period);

  /// Срок прошёл, а платёж не оплачен и не пропущен.
  bool isOverdue(DateTime now) =>
      isPending && dueDate.isBefore(DateTime(now.year, now.month, now.day));
}
