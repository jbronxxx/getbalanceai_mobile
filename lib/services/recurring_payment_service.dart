import 'dart:async';

import 'package:flutter/material.dart' show DateUtils;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../utils/currency_formatter.dart';
import 'api_service.dart';
import 'currency_exchange_service.dart';
import 'local_db_service.dart';
import 'pending_deletions_store.dart';

/// Регулярные платежи и доходы: платежи месяца, предстоящие расходы,
/// создание, пропуск месяца и остановка.
///
/// Хранение — [LocalDbService], правила дат — [RecurringSchedule]. Каждое
/// изменение уходит на сервер в фоне (`/sync/`), как правки операций.
class RecurringPaymentService {
  RecurringPaymentService._();

  static final RecurringPaymentService instance = RecurringPaymentService._();

  static const _uuid = Uuid();

  LocalDbService get _db => LocalDbService.instance;

  /// Платежи [period] по дню месяца с записями «Оплачено», если они есть.
  List<RecurringOccurrence> occurrencesIn(MonthPeriod period) {
    final due = [
      for (final payment in _db.getRecurringPayments())
        if (payment.isDueIn(period)) payment,
    ];
    if (due.isEmpty) return const [];
    final records = _db.getTransactionsByServerIds(
        due.map((payment) => payment.transactionIdIn(period)));
    final occurrences = [
      for (final payment in due)
        RecurringOccurrence(
          payment: payment,
          period: period,
          record: records[payment.transactionIdIn(period)],
        ),
    ];
    occurrences.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return occurrences;
  }

  /// Оплаченные платежи [period] и соседних месяцев по `serverId` записи:
  /// оплата заранее или задним числом может лежать в соседнем месяце.
  Map<String, RecurringOccurrence> paidAround(MonthPeriod period) => {
        for (final p in [period.previous, period, period.next])
          for (final o in occurrencesIn(p))
            if (o.record?.serverId case final id?) id: o,
      };

  /// Платёж, оплатой которого стала запись [record], или `null`.
  RecurringOccurrence? occurrenceForRecord(Transaction record) {
    final id = record.serverId;
    if (id == null) return null;
    return paidAround(MonthPeriod.current(record.date))[id];
  }

  /// Расходы месяца [now], которые ещё предстоит оплатить: не оплачены и не
  /// пропущены, в том числе просроченные — эти деньги ещё уйдут.
  List<RecurringOccurrence> pendingExpenses([DateTime? now]) => [
        for (final o in occurrencesIn(MonthPeriod.current(now)))
          if (o.isPending && o.payment.type == TransactionType.expense) o,
      ];

  /// Ожидающие оплаты расходы месяца [now] по категориям: сумма в базовой
  /// валюте и число платежей — для «можно тратить в день» на «Бюджете».
  /// [exclude] — платежи, которые не учитывать (остановленные, ожидающие
  /// отмены).
  Map<String, ({double amount, int count})> pendingByCategory({
    DateTime? now,
    bool Function(RecurringPayment payment)? exclude,
  }) {
    final grouped = <String, List<RecurringOccurrence>>{};
    for (final o in pendingExpenses(now)) {
      if (exclude?.call(o.payment) ?? false) continue;
      grouped.putIfAbsent(o.payment.dbCategory, () => []).add(o);
    }
    return {
      for (final MapEntry(:key, :value) in grouped.entries)
        key: (amount: totalInBaseCurrency(value), count: value.length),
    };
  }

  /// Сумма платежей в базовой валюте по текущему курсу.
  double totalInBaseCurrency(Iterable<RecurringOccurrence> occurrences) {
    final base = CurrencyFormatter.currentCurrency;
    var total = 0.0;
    for (final o in occurrences) {
      final payment = o.payment;
      total += payment.currency == base
          ? payment.amount
          : CurrencyExchangeService.instance
              .convert(payment.amount, from: payment.currency, to: base);
    }
    return total;
  }

  /// Новый платёж по образцу записи из формы: каждый месяц в день [start].
  RecurringPayment fromRecord(
    Transaction record, {
    required DateTime start,
    DateTime? end,
  }) {
    return RecurringPayment(
      uid: _uuid.v4(),
      dbType: record.dbType,
      dbCategory: record.dbCategory,
      amount: record.amount,
      currencyCode: record.currencyCode,
      description: record.description,
      dayOfMonth: start.day,
      startDate: formatDateOnly(start),
      endDate: end == null ? null : formatDateOnly(end),
    );
  }

  /// Делает запись регулярной: новый платёж каждый месяц в день [start].
  /// Если этот день уже наступил, запись становится оплатой первого месяца
  /// (пользователь вносит платёж, который только что сделал): она получает
  /// ID этого месяца, а прежняя копия с другим ID удаляется на сервере.
  RecurringPayment startFrom(
    Transaction record, {
    required DateTime start,
    DateTime? end,
    DateTime? now,
  }) {
    final payment = fromRecord(record, start: start, end: end);
    save(payment);
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    if (start.isAfter(today)) return payment;

    final previousId = _db.getTransaction(record.localId)?.serverId;
    final first = RecurringOccurrence(
      payment: payment,
      period: MonthPeriod.current(start),
    );
    _db.saveTransaction(asPaidRecord(first, record));
    if (previousId != null && previousId != record.serverId) {
      unawaited(PendingDeletionsStore.instance.addTransaction(previousId));
    }
    return payment;
  }

  /// Сохраняет новый или изменённый платёж.
  void save(RecurringPayment payment) {
    payment.isModified = true;
    _db.saveRecurringPayment(payment);
    ApiService.instance.pushLocalChangesInBackground();
  }

  /// Запись «Оплачено» за месяц [occurrence]: ID детерминирован — повторная
  /// оплата того же месяца (в том числе с другого устройства) обновит её.
  Transaction asPaidRecord(RecurringOccurrence occurrence, Transaction record) {
    record.serverId = occurrence.transactionId;
    record.isModified = true;
    return record;
  }

  /// Пропустить месяц: о нём не напоминать и не учитывать в предстоящих.
  void skip(RecurringOccurrence occurrence) =>
      _setSkipped(occurrence, skipped: true);

  /// Вернуть пропущенный месяц (отмена пропуска).
  void unskip(RecurringOccurrence occurrence) =>
      _setSkipped(occurrence, skipped: false);

  void _setSkipped(RecurringOccurrence occurrence, {required bool skipped}) {
    final payment = _db.getRecurringPayment(occurrence.payment.localId) ??
        occurrence.payment;
    final key = RecurringSchedule.periodKey(occurrence.period);
    final periods = {...payment.skippedPeriods};
    final changed = skipped ? periods.add(key) : periods.remove(key);
    if (!changed) return;
    save(payment.copyWith(skippedPeriods: periods.toList()..sort()));
  }

  /// Удаляет платёж на устройстве и на сервере; записи прошлых месяцев
  /// остаются. Вызывается из [UndoableDeletions.recurringPayments] после
  /// того, как истекло время на «Отменить».
  Future<void> deleteEverywhere(RecurringPayment payment) async {
    final stored = _db.getRecurringPayment(payment.localId) ?? payment;
    _db.deleteRecurringPayment(payment.localId);
    // Платёж, которого сервер ещё не видел, удалять там нечего
    if (!stored.isOnServer) return;
    await PendingDeletionsStore.instance.addRecurringPayment(stored.uid);
    ApiService.instance.pushLocalChangesInBackground();
  }
}
