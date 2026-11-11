import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';

/// Система уведомлений без платформы: запоминает запланированное.
class _FakeScheduler implements ReminderScheduler {
  final scheduled = <RecurringReminder>[];
  int cancels = 0;
  void Function(String payload)? onTap;
  String? launch;
  int permissionRequests = 0;

  @override
  Future<void> initialize(void Function(String payload) onTap) async =>
      this.onTap = onTap;

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(
          RecurringReminder reminder, AppLocalizations l10n) async =>
      scheduled.add(reminder);

  final shown = <RecurringReminder>[];

  @override
  Future<void> showNow(
          RecurringReminder reminder, AppLocalizations l10n) async =>
      shown.add(reminder);

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }
}

/// USAB-04, этап 3: напоминания в день регулярного платежа.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('reminders');
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
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await LocalDbService.instance.clearAllData();
    await CurrencyFormatter.setCurrency(Currency.eur);
  });

  LocalDbService db() => LocalDbService.instance;
  const nov = MonthPeriod(2026, 11);

  RecurringPayment payment({
    String uid = 'p-1',
    String type = 'expense',
    String category = 'housing',
    String description = 'ЖКХ',
    int day = 15,
    String start = '2026-11-15',
    List<String>? skipped,
  }) =>
      RecurringPayment(
        uid: uid,
        dbType: type,
        dbCategory: category,
        amount: 350000,
        currencyCode: 'EUR',
        description: description,
        dayOfMonth: day,
        startDate: start,
        skippedPeriods: skipped,
      );

  group('План напоминаний', () {
    List<RecurringReminder> plan(
            List<RecurringOccurrence> occurrences, DateTime now) =>
        RecurringReminderService.plan(occurrences,
            now: now, l10n: LanguageManager.l10n);

    test('в день платежа в 10:00, с названием и суммой', () {
      final reminders = plan(
          [RecurringOccurrence(payment: payment(), period: nov)],
          DateTime(2026, 11, 10));
      final r = reminders.single;
      expect(
          r.at, DateTime(2026, 11, 15, RecurringReminderService.reminderHour));
      expect(r.title, 'Сегодня платёж: ЖКХ');
      expect(r.body, '€350 000,00 — нажмите, чтобы отметить оплату');
      expect(r.payload, 'p-1|2026-11');
    });

    test('доход — своя формулировка; без названия — категория', () {
      final income = payment(
          type: 'income', category: 'salary', description: '', uid: 'sal');
      final r = plan([RecurringOccurrence(payment: income, period: nov)],
              DateTime(2026, 11, 10))
          .single;
      expect(r.title, 'Сегодня ожидается: Зарплата');
      expect(r.body, contains('отметить получение'));
    });

    test('оплаченный, пропущенный и прошедший — без напоминаний', () {
      final record = Transaction(
        amount: 1,
        description: '',
        dbCategory: 'housing',
        dbType: 'expense',
        dateMilliseconds: 0,
        dateCreatedMilliseconds: 0,
      );
      final reminders = plan([
        RecurringOccurrence(
            payment: payment(uid: 'paid'), period: nov, record: record),
        RecurringOccurrence(
            payment: payment(uid: 'skipped', skipped: ['2026-11']),
            period: nov),
        // 10:00 15-го уже прошло
        RecurringOccurrence(payment: payment(uid: 'late'), period: nov),
      ], DateTime(2026, 11, 15, 10, 1));
      expect(reminders, isEmpty);
    });

    test('номер уведомления одинаков для платежа и месяца, разный по месяцам',
        () {
      final now = DateTime(2026, 11, 1);
      final a =
          plan([RecurringOccurrence(payment: payment(), period: nov)], now)
              .single;
      final again =
          plan([RecurringOccurrence(payment: payment(), period: nov)], now)
              .single;
      final dec = plan([
        RecurringOccurrence(
            payment: payment(), period: const MonthPeriod(2026, 12))
      ], now)
          .single;
      expect(a.id, again.id);
      expect(a.id, isNot(dec.id));
      expect(a.id, greaterThanOrEqualTo(0));
    });
  });

  group('Сервис', () {
    late _FakeScheduler scheduler;
    late RecurringReminderService service;

    setUp(() {
      scheduler = _FakeScheduler();
      service = RecurringReminderService(scheduler: scheduler);
    });

    test('пересборка: отменяет старые, планирует на три месяца вперёд',
        () async {
      db().saveRecurringPayment(payment());
      await service.reschedule(DateTime(2026, 11, 10));
      expect(scheduler.cancels, 1);
      expect(scheduler.scheduled.map((r) => r.payload),
          ['p-1|2026-11', 'p-1|2026-12', 'p-1|2027-01']);
    });

    test('оплата снимает напоминание этого месяца', () async {
      db().saveRecurringPayment(payment());
      final occurrence =
          RecurringPaymentService.instance.occurrencesIn(nov).single;
      db().saveTransaction(RecurringPaymentService.instance.asPaidRecord(
        occurrence,
        Transaction(
          amount: 350000,
          description: 'ЖКХ',
          dbCategory: 'housing',
          dbType: 'expense',
          dateMilliseconds: DateTime(2026, 11, 10).millisecondsSinceEpoch,
          dateCreatedMilliseconds: 0,
        ),
      ));
      await service.reschedule(DateTime(2026, 11, 10));
      expect(scheduler.scheduled.map((r) => r.payload),
          isNot(contains('p-1|2026-11')));
    });

    test('остановленный платёж — без напоминаний', () async {
      db().saveRecurringPayment(payment());
      await service.reschedule(DateTime(2026, 11, 10));
      db().deleteRecurringPayment(db().getRecurringPayments().single.localId);
      await service.reschedule(DateTime(2026, 11, 10));
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets('тап и запуск из уведомления открывают платёж месяца',
        (tester) async {
      db().saveRecurringPayment(payment());
      scheduler.launch = 'p-1|2026-11';
      final opened = <RecurringOccurrence>[];
      await service.start(onOpen: opened.add);
      // Платёж открывается после первого кадра — когда готов навигатор
      await tester.pumpWidget(const SizedBox());
      expect(opened.single.payment.uid, 'p-1');
      expect(opened.single.period, nov);

      scheduler.onTap!('p-1|2026-12');
      expect(opened.last.period, const MonthPeriod(2026, 12));

      // Платёж удалён или payload испорчен — ничего не открывается
      scheduler.onTap!('gone|2026-11');
      scheduler.onTap!('garbage');
      expect(opened, hasLength(2));
      service.stop();
    });

    testWidgets(
        'меню отладки: напоминание о ближайшем ожидающем платеже '
        'через 10 секунд, расписание его не отменяет', (tester) async {
      expect(await service.debugRemindSoon(), isFalse);
      db().saveRecurringPayment(payment(
          uid: 'soon',
          start: formatDateOnly(DateTime.now().add(const Duration(days: 1)))));
      expect(await service.debugRemindSoon(), isTrue);
      await service.reschedule();
      expect(scheduler.shown, isEmpty);

      await tester.pump(const Duration(seconds: 10));
      expect(scheduler.shown.single.payload, startsWith('soon|'));
    });

    test('разрешение запрашивается по требованию', () async {
      await service.requestPermission();
      expect(scheduler.permissionRequests, 1);
    });
  });
}
