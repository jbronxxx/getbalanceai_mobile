import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/api_config.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

/// USAB-04: регулярные платежи — расписание, хранение, операции, синхронизация.
void main() {
  late _Adapter adapter;
  late SyncService sync;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('recurring');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});
    LanguageManager.initFallback();
    await LocalDbService.init();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await LocalDbService.instance.clearAllData();
    await PendingDeletionsStore.instance.clear();
    await CurrencyFormatter.setCurrency(Currency.eur);

    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'))
      ..httpClientAdapter = adapter;
    sync = SyncService(
      dio: dio,
      authOptions: ([String? token]) => Options(headers: {}),
      tokenProvider: () => 'token',
    );
  });

  LocalDbService db() => LocalDbService.instance;
  final service = RecurringPaymentService.instance;

  RecurringPayment payment({
    String uid = 'p-1',
    String type = 'expense',
    String category = 'housing',
    double amount = 350000,
    String currency = 'EUR',
    int day = 15,
    String start = '2026-11-15',
    String? end,
    List<String>? skipped,
  }) =>
      RecurringPayment(
        uid: uid,
        dbType: type,
        dbCategory: category,
        amount: amount,
        currencyCode: currency,
        description: 'ЖКХ',
        dayOfMonth: day,
        startDate: start,
        endDate: end,
        skippedPeriods: skipped,
      );

  Transaction record({double amount = 360000, DateTime? date}) => Transaction(
        amount: amount,
        description: 'ЖКХ',
        dbCategory: 'housing',
        dbType: 'expense',
        dateMilliseconds:
            (date ?? DateTime(2026, 11, 14)).millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime(2026, 11, 14).millisecondsSinceEpoch,
        currencyCode: 'EUR',
      );

  const nov = MonthPeriod(2026, 11);

  group('Расписание', () {
    test('31-е в коротком месяце — последний день месяца', () {
      final p = payment(day: 31, start: '2026-01-31');
      expect(p.dueDateIn(const MonthPeriod(2026, 2)), DateTime(2026, 2, 28));
      expect(p.dueDateIn(const MonthPeriod(2028, 2)), DateTime(2028, 2, 29));
      expect(p.dueDateIn(const MonthPeriod(2026, 4)), DateTime(2026, 4, 30));
      expect(p.dueDateIn(const MonthPeriod(2026, 5)), DateTime(2026, 5, 31));
    });

    test('платёж есть с первого месяца по последний', () {
      final p = payment(start: '2026-11-15', end: '2027-10-15');
      expect(p.isDueIn(const MonthPeriod(2026, 10)), isFalse);
      expect(p.isDueIn(nov), isTrue);
      expect(p.isDueIn(const MonthPeriod(2027, 10)), isTrue);
      expect(p.isDueIn(const MonthPeriod(2027, 11)), isFalse);
      expect(payment().isDueIn(const MonthPeriod(2030, 1)), isTrue);
    });

    test('кредит: номер платежа и всего платежей', () {
      final p = payment(start: '2026-11-15', end: '2027-10-15');
      expect(p.paymentNumberIn(nov), 1);
      expect(p.paymentNumberIn(const MonthPeriod(2027, 5)), 7);
      expect(p.totalPayments, 12);
      // Последний день раньше дня платежа — последний месяц не считается
      expect(payment(start: '2026-11-15', end: '2027-10-10').totalPayments, 11);
      expect(payment().totalPayments, isNull);
    });

    test('ID записи месяца одинаков на всех устройствах и разный по месяцам',
        () {
      final a = payment(uid: 'p-1');
      final again = payment(uid: 'p-1', amount: 1);
      expect(a.transactionIdIn(nov), again.transactionIdIn(nov));
      expect(a.transactionIdIn(nov),
          isNot(a.transactionIdIn(const MonthPeriod(2026, 12))));
      expect(a.transactionIdIn(nov),
          isNot(payment(uid: 'p-2').transactionIdIn(nov)));
      expect(a.transactionIdIn(nov),
          matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-')));
    });

    test('дата без времени: формат сервера и отказ от неверной', () {
      expect(formatDateOnly(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
      expect(parseDateOnly('2026-03-05'), DateTime(2026, 3, 5));
      expect(parseDateOnly('2026-02-31'), isNull);
      expect(parseDateOnly('05.03.2026'), isNull);
    });

    test('JSON: туда и обратно, неполный ответ сервера отбрасывается', () {
      final p = payment(end: '2027-10-15', skipped: ['2026-12', '2026-11']);
      final json = p.toJson();
      expect(json['skipped_periods'], ['2026-11', '2026-12']);
      final parsed = RecurringPayment.fromJson(json);
      expect(parsed.toJson(), json);
      expect(parsed.isOnServer, isTrue);
      expect(parsed.isModified, isFalse);
      expect(RecurringPayment.fromJson({'id': 'x'}).isValid, isFalse);
    });
  });

  group('Платежи месяца', () {
    test('оплаченный — по записи с ID месяца, пропущенный и ожидающий', () {
      db().saveRecurringPayment(payment(uid: 'housing'));
      db().saveRecurringPayment(payment(uid: 'phone', day: 20));
      db().saveRecurringPayment(payment(
          uid: 'internet', day: 5, start: '2026-11-05', skipped: ['2026-11']));
      db().saveRecurringPayment(payment(uid: 'later', start: '2027-01-01'));

      final housing = service
          .occurrencesIn(nov)
          .firstWhere((o) => o.payment.uid == 'housing');
      db().saveTransaction(service.asPaidRecord(housing, record()));

      final occurrences = service.occurrencesIn(nov);
      expect(occurrences.map((o) => o.payment.uid),
          ['internet', 'housing', 'phone']);
      final byUid = {for (final o in occurrences) o.payment.uid: o};
      expect(byUid['housing']!.isPaid, isTrue);
      expect(byUid['housing']!.record!.amount, 360000);
      expect(byUid['internet']!.isSkipped, isTrue);
      expect(byUid['phone']!.isPending, isTrue);
      expect(byUid['phone']!.isOverdue(DateTime(2026, 11, 20, 23)), isFalse);
      expect(byUid['phone']!.isOverdue(DateTime(2026, 11, 21)), isTrue);
    });

    test('повторная оплата того же месяца обновляет запись, а не дублирует',
        () {
      db().saveRecurringPayment(payment());
      final occurrence = service.occurrencesIn(nov).single;
      db().saveTransaction(service.asPaidRecord(occurrence, record()));
      db().saveTransaction(
          service.asPaidRecord(occurrence, record(amount: 370000)));

      expect(db().getTransactionsForPeriod(11, 2026), hasLength(1));
      expect(service.occurrencesIn(nov).single.record!.amount, 370000);
    });

    test('предстоящие расходы: без оплаченных, пропущенных и доходов', () {
      db().saveRecurringPayment(payment(uid: 'housing'));
      db().saveRecurringPayment(
          payment(uid: 'phone', amount: 50000, day: 5, start: '2026-11-05'));
      db().saveRecurringPayment(
          payment(uid: 'usd', amount: 10, currency: 'USD'));
      db().saveRecurringPayment(
          payment(uid: 'salary', type: 'income', category: 'salary'));
      db().saveRecurringPayment(
          payment(uid: 'skipped', day: 25, skipped: ['2026-11']));
      final housing = service
          .occurrencesIn(nov)
          .firstWhere((o) => o.payment.uid == 'housing');
      db().saveTransaction(service.asPaidRecord(housing, record()));

      final pending = service.pendingExpenses(DateTime(2026, 11, 10));
      // Просроченный (5-е) ещё предстоит оплатить
      expect(pending.map((o) => o.payment.uid), ['phone', 'usd']);
      expect(
          service.totalInBaseCurrency(pending),
          50000 +
              CurrencyExchangeService.instance
                  .convert(10, from: Currency.usd, to: Currency.eur));
    });

    test('пропуск месяца и отмена пропуска', () {
      db().saveRecurringPayment(payment());
      service.skip(service.occurrencesIn(nov).single);
      final skipped = service.occurrencesIn(nov).single;
      expect(skipped.isSkipped, isTrue);
      expect(skipped.payment.isModified, isTrue);

      service.unskip(skipped);
      expect(service.occurrencesIn(nov).single.isSkipped, isFalse);
    });

    test('остановка: записи прошлых месяцев остаются, сервер узнает', () async {
      final onServer = payment()..isOnServer = true;
      db().saveRecurringPayment(onServer);
      final occurrence = service.occurrencesIn(nov).single;
      db().saveTransaction(service.asPaidRecord(occurrence, record()));

      await service.deleteEverywhere(onServer);
      expect(db().getRecurringPayments(), isEmpty);
      expect(db().getTransactionsForPeriod(11, 2026), hasLength(1));
      expect(PendingDeletionsStore.instance.recurringPaymentIds, {'p-1'});
    });

    test('остановка неотправленного платежа серверу не нужна', () async {
      final local = payment();
      db().saveRecurringPayment(local);
      await service.deleteEverywhere(local);
      expect(PendingDeletionsStore.instance.recurringPaymentIds, isEmpty);
    });

    test(
        'уже отправленная запись становится оплатой первого месяца: новый ID, '
        'старая копия удаляется на сервере', () async {
      final existing = record(date: DateTime(2026, 11, 14))
        ..serverId = 'old-server-id';
      db().saveTransaction(existing);

      final payment = service.startFrom(existing,
          start: DateTime(2026, 11, 14), now: DateTime(2026, 11, 20));
      await Future<void>.delayed(Duration.zero);

      final rows = db().getTransactionsForPeriod(11, 2026);
      expect(rows, hasLength(1));
      expect(rows.single.serverId,
          payment.transactionIdIn(const MonthPeriod(2026, 11)));
      expect(rows.single.isModified, isTrue);
      expect(PendingDeletionsStore.instance.transactionIds, {'old-server-id'});
      expect(service.occurrencesIn(const MonthPeriod(2026, 11)).single.isPaid,
          isTrue);
    });

    test('регулярный с будущего дня: запись не трогается', () {
      final payment = service.startFrom(record(),
          start: DateTime(2026, 11, 25), now: DateTime(2026, 11, 20));
      expect(db().getRecurringPayments().single.uid, payment.uid);
      expect(db().getTransactionsForPeriod(11, 2026), isEmpty);
    });

    test('новый платёж из записи формы: день, валюта, срок', () {
      final created = service.fromRecord(record(),
          start: DateTime(2026, 11, 14), end: DateTime(2027, 10, 14));
      expect(created.dayOfMonth, 14);
      expect(created.startDate, '2026-11-14');
      expect(created.endDate, '2027-10-14');
      expect(created.amount, 360000);
      expect(created.isModified, isTrue);
      expect(created.uid, isNotEmpty);
    });
  });

  group('Синхронизация', () {
    test('выгрузка: платежи и удаления уходят, подтверждённый не повторяется',
        () async {
      db().saveRecurringPayment(payment());
      await PendingDeletionsStore.instance.addRecurringPayment('gone');

      await sync.syncLocalDataToBackend();
      final body = adapter.syncBodies.single;
      expect((body['recurring_payments'] as List).single['id'], 'p-1');
      expect(body['deleted_recurring_payment_ids'], ['gone']);

      final stored = db().getRecurringPayments().single;
      expect(stored.isModified, isFalse);
      expect(stored.isOnServer, isTrue);
      expect(PendingDeletionsStore.instance.recurringPaymentIds, isEmpty);
      expect(db().unsyncedCount, 0);

      await sync.syncLocalDataToBackend();
      expect(adapter.syncBodies, hasLength(1));
    });

    test('правка во время запроса остаётся в очереди', () async {
      db().saveRecurringPayment(payment());
      adapter.beforeSyncReply = () => db().saveRecurringPayment(
          db().getRecurringPayments().single.copyWith(amount: 1));

      await sync.syncLocalDataToBackend();
      final stored = db().getRecurringPayments().single;
      expect(stored.amount, 1);
      expect(stored.isModified, isTrue);
    });

    test('чужой ID — новый uid и повторная отправка', () async {
      db().saveRecurringPayment(payment());
      adapter.rejectRecurring = 'ID_CONFLICT';

      await sync.syncLocalDataToBackend();
      final stored = db().getRecurringPayments().single;
      expect(stored.uid, isNot('p-1'));
      expect(stored.isModified, isTrue);
    });

    test('старый сервер без регулярных платежей: очередь ждёт, синк не падает',
        () async {
      db().saveRecurringPayment(payment());
      await PendingDeletionsStore.instance.addRecurringPayment('gone');
      adapter.oldServer = true;

      await sync.syncAll();
      expect(db().getRecurringPayments().single.isModified, isTrue);
      expect(PendingDeletionsStore.instance.recurringPaymentIds, {'gone'});
    });

    test(
        'загрузка: новые с сервера, удалённые на другом устройстве, свои '
        'неотправленные остаются', () async {
      db().saveRecurringPayment(payment(uid: 'deleted-elsewhere')
        ..isOnServer = true
        ..isModified = false);
      db().saveRecurringPayment(
          payment(uid: 'edited', amount: 1)..isOnServer = true);
      db().saveRecurringPayment(payment(uid: 'new-local'));
      adapter.remoteRecurring = [
        payment(uid: 'from-server', day: 3).toJson(),
        payment(uid: 'edited', amount: 999).toJson(),
      ];

      await sync.syncBackendDataToLocal();
      final byUid = {for (final p in db().getRecurringPayments()) p.uid: p};
      expect(byUid.keys.toSet(), {'from-server', 'edited', 'new-local'});
      expect(byUid['from-server']!.isOnServer, isTrue);
      expect(byUid['edited']!.amount, 1);
    });

    test('304 — список не трогается, ETag уходит в If-None-Match', () async {
      adapter.remoteRecurring = [payment(uid: 'from-server').toJson()];
      await sync.syncBackendDataToLocal();
      adapter.recurringNotModified = true;

      await sync.syncBackendDataToLocal();
      expect(adapter.lastRecurringIfNoneMatch, '"r-etag"');
      expect(db().getRecurringPayments().single.uid, 'from-server');
    });
  });
}

/// Сервер для [SyncService]: принимает всё, отдаёт пустые изменения и
/// заданный список регулярных платежей.
class _Adapter implements HttpClientAdapter {
  final syncBodies = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> remoteRecurring = [];
  bool recurringNotModified = false;
  bool oldServer = false;
  String? rejectRecurring;
  String? lastRecurringIfNoneMatch;
  void Function()? beforeSyncReply;

  ResponseBody _json(Object body, [int status = 200, String? etag]) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (etag != null) 'etag': [etag],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;
    if (path == ApiConfig.sync) {
      final body = (options.data as Map).cast<String, dynamic>();
      syncBodies.add(body);
      beforeSyncReply?.call();
      final recurring = (body['recurring_payments'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      return _json({
        'status': 'success',
        'data': {
          'synced_transactions': body['transactions'],
          'synced_budgets': <Object>[],
          if (!oldServer)
            'synced_recurring_payments': [
              if (rejectRecurring == null) ...recurring,
            ],
          'rejected': [
            if (rejectRecurring != null)
              for (final p in recurring)
                {'id': p['id'], 'code': rejectRecurring, 'reason': 'x'},
          ],
        },
      });
    }
    if (path == ApiConfig.syncChanges) {
      return _json({
        'status': 'success',
        'data': {
          'transactions': <Object>[],
          'deleted_transaction_ids': <Object>[],
          'has_more': false,
          'next_cursor': null,
          'server_time': '2026-11-10T10:00:00.000Z',
        },
      });
    }
    if (path == ApiConfig.recurringPayments) {
      if (oldServer) return _json({'detail': 'Not Found'}, 404);
      lastRecurringIfNoneMatch = options.headers['If-None-Match'] as String?;
      if (recurringNotModified) return _json({}, 304, '"r-etag"');
      return _json(
          {'status': 'success', 'data': remoteRecurring}, 200, '"r-etag"');
    }
    if (path == ApiConfig.budgets) {
      return _json({'status': 'success', 'data': <Object>[]});
    }
    return _json({'detail': 'unexpected $path'}, 400);
  }

  @override
  void close({bool force = false}) {}
}
