import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/config/environment.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/month_budget_card.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';

/// USAB-04: регулярные платежи в интерфейсе — форма записи, лента дня,
/// карточка платежа, «можно тратить в день».
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final tempDir = await Directory.systemTemp.createTemp('recurring_ui');
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
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await LocalDbService.instance.clearAllData();
    await CurrencyFormatter.setCurrency(Currency.eur);
    SelectedPeriodService.instance.select(MonthPeriod.current());
  });

  LocalDbService db() => LocalDbService.instance;
  final today = DateUtils.dateOnly(DateTime.now());

  RecurringPayment payment({
    String uid = 'p-1',
    String type = 'expense',
    String category = 'housing',
    int? day,
    DateTime? start,
    DateTime? end,
  }) {
    final first = start ?? today;
    return RecurringPayment(
      uid: uid,
      dbType: type,
      dbCategory: category,
      amount: 350000,
      currencyCode: 'EUR',
      description: 'ЖКХ',
      dayOfMonth: day ?? first.day,
      startDate: formatDateOnly(first),
      endDate: end == null ? null : formatDateOnly(end),
    );
  }

  Widget app(Widget home) => MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: home,
      );

  /// Открывает форму как шторку поверх экрана: `Navigator.pop` после
  /// сохранения закрывает её.
  Future<void> openSheet(
    WidgetTester tester, {
    RecurringOccurrence? occurrence,
    RecurringPayment? recurringToEdit,
  }) async {
    await tester.pumpWidget(app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => AddTransactionSheet.show(
              context,
              occurrence: occurrence,
              recurringToEdit: recurringToEdit,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String amount) async {
    await tester.enterText(find.byType(TextField).first, amount);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('add_transaction_submit')));
    await tester.pumpAndSettle();
  }

  group('Форма записи', () {
    testWidgets('«Каждый месяц»: регулярный платёж и оплата первого месяца',
        (tester) async {
      await openSheet(tester);
      await enterAmount(tester, '150000');
      expect(find.text('Каждый месяц'), findsOneWidget);
      expect(find.byKey(const ValueKey('recurrence_end')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('recurrence_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Каждое ${today.day}-е'), findsOneWidget);
      expect(find.text('Без срока'), findsOneWidget);
      expect(find.text('Добавить регулярный'), findsOneWidget);

      // Срок: 12 платежей
      await tester.tap(find.byKey(const ValueKey('recurrence_end')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 платежей'));
      await tester.pumpAndSettle();
      expect(find.text('12 платежей'), findsOneWidget);

      await submit(tester);
      final saved = db().getRecurringPayments().single;
      expect(saved.amount, 150000);
      expect(saved.dayOfMonth, today.day);
      expect(saved.totalPayments, 12);
      expect(saved.isModified, isTrue);
      // Сегодняшний платёж уже сделан — записан как оплата первого месяца
      final occurrence = RecurringPaymentService.instance
          .occurrencesIn(MonthPeriod.current(today))
          .single;
      expect(occurrence.isPaid, isTrue);
      expect(occurrence.record!.amount, 150000);
    });

    testWidgets('выключенный повтор — обычная запись', (tester) async {
      await openSheet(tester);
      await enterAmount(tester, '1000');
      await tester.tap(find.byKey(const ValueKey('recurrence_toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recurrence_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Добавить запись'), findsOneWidget);

      await submit(tester);
      expect(db().getRecurringPayments(), isEmpty);
      expect(
          db().getTransactionsForPeriod(today.month, today.year), hasLength(1));
    });

    testWidgets('«Оплачено»: форма заполнена платежом, сумму можно исправить',
        (tester) async {
      db().saveRecurringPayment(payment());
      final occurrence = RecurringPaymentService.instance
          .occurrencesIn(MonthPeriod.current(today))
          .single;
      await openSheet(tester, occurrence: occurrence);

      expect(find.text('Отметить оплату'), findsOneWidget);
      expect(find.text('350 000,00'), findsOneWidget);
      expect(find.byType(TransactionTypeToggle), findsNothing);
      expect(find.byKey(const ValueKey('recurrence_toggle')), findsNothing);
      expect(find.text('Оплачено'), findsOneWidget);

      await enterAmount(tester, '362000');
      await submit(tester);
      final paid = RecurringPaymentService.instance
          .occurrencesIn(MonthPeriod.current(today))
          .single;
      expect(paid.isPaid, isTrue);
      expect(paid.record!.amount, 362000);
      expect(paid.record!.serverId, occurrence.transactionId);
    });

    testWidgets('правка записи: её можно сделать регулярной', (tester) async {
      final existing = Transaction(
        amount: 120000,
        description: 'Интернет',
        dbCategory: 'communication',
        dbType: 'expense',
        dateMilliseconds: today.millisecondsSinceEpoch,
        dateCreatedMilliseconds: 0,
        currencyCode: 'EUR',
      );
      db().saveTransaction(existing);
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                AddTransactionSheet.show(context, transactionToEdit: existing),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Каждый месяц'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recurrence_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить'), findsOneWidget);
      await submit(tester);

      final payment = db().getRecurringPayments().single;
      expect(payment.dayOfMonth, today.day);
      expect(payment.description, 'Интернет');
      final rows = db().getTransactionsForPeriod(today.month, today.year);
      expect(rows, hasLength(1));
      expect(rows.single.serverId,
          payment.transactionIdIn(MonthPeriod.current(today)));
    });

    testWidgets('правка оплаты регулярного платежа — без чипа повтора',
        (tester) async {
      db().saveRecurringPayment(payment());
      final occurrence = RecurringPaymentService.instance
          .occurrencesIn(MonthPeriod.current(today))
          .single;
      final paid = RecurringPaymentService.instance.asPaidRecord(
        occurrence,
        Transaction(
          amount: 1,
          description: '',
          dbCategory: 'housing',
          dbType: 'expense',
          dateMilliseconds: today.millisecondsSinceEpoch,
          dateCreatedMilliseconds: 0,
        ),
      );
      db().saveTransaction(paid);
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                AddTransactionSheet.show(context, transactionToEdit: paid),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recurrence_toggle')), findsNothing);
      expect(find.text('Сохранить изменения'), findsOneWidget);
    });

    testWidgets('правка регулярного платежа меняет расписание, а не запись',
        (tester) async {
      db().saveRecurringPayment(payment());
      await openSheet(tester,
          recurringToEdit: db().getRecurringPayments().single);
      expect(find.text('Регулярный платёж'), findsOneWidget);
      expect(find.text('Сохранить'), findsOneWidget);

      await enterAmount(tester, '400000');
      await submit(tester);
      final edited = db().getRecurringPayments().single;
      expect(edited.uid, 'p-1');
      expect(edited.amount, 400000);
      expect(edited.isModified, isTrue);
      expect(db().getTransactionsForPeriod(today.month, today.year), isEmpty);
    });
  });

  group('Лента дня и карточка платежа', () {
    RecurringOccurrence occurrenceOf(RecurringPayment p, MonthPeriod period) =>
        RecurringOccurrence(payment: p, period: period);

    testWidgets('ожидаемый платёж — отдельной строкой, в итог дня не входит',
        (tester) async {
      final tomorrow = today.add(const Duration(days: 1));
      final o =
          occurrenceOf(payment(start: tomorrow), MonthPeriod.current(tomorrow));
      RecurringOccurrence? tapped;
      await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
          child: DayGroupWidget(
            date: tomorrow,
            transactions: const [],
            occurrences: [o],
            onOccurrenceTap: (value) => tapped = value,
            onTransactionTap: (_) {},
            onTransactionDelete: (_) {},
          ),
        ),
      )));

      expect(find.byType(RecurringOccurrenceTile), findsOneWidget);
      expect(find.textContaining('Ожидается'), findsOneWidget);
      // Итога дня без записей нет
      expect(find.textContaining('350'), findsOneWidget);

      await tester.tap(find.byType(RecurringOccurrenceTile));
      expect(tapped, o);
    });

    testWidgets('просроченный платёж помечен «Не оплачено»', (tester) async {
      final o = occurrenceOf(
          payment(start: DateTime(2026, 11, 5)), const MonthPeriod(2026, 11));
      await tester.pumpWidget(app(Scaffold(
        body: RecurringOccurrenceTile(
          occurrence: o,
          onTap: () {},
          now: DateTime(2026, 11, 10),
        ),
      )));
      expect(find.textContaining('Не оплачено'), findsOneWidget);
    });

    testWidgets(
        'карточка: ожидающий — «Оплачено» и «Пропустить», кредит 1 из 12',
        (tester) async {
      final start = DateTime(2026, 11, 15);
      final p = payment(
          start: start, end: RecurringSchedule.lastPaymentDate(start, 12));
      await tester.pumpWidget(app(Scaffold(
        body: RecurringOccurrenceSheet(
          occurrence: occurrenceOf(p, const MonthPeriod(2026, 11)),
          now: DateTime(2026, 11, 10),
        ),
      )));
      expect(find.text('Регулярный платёж'), findsOneWidget);
      expect(find.text('Платёж 1 из 12'), findsOneWidget);
      for (final key in [
        'recurring_pay',
        'recurring_skip',
        'recurring_edit',
        'recurring_stop'
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
    });

    testWidgets('карточка оплаченного: только правка и остановка',
        (tester) async {
      final p = payment();
      final period = MonthPeriod.current(today);
      final record = Transaction(
        serverId: p.transactionIdIn(period),
        amount: 1,
        description: '',
        dbCategory: 'housing',
        dbType: 'expense',
        dateMilliseconds: today.millisecondsSinceEpoch,
        dateCreatedMilliseconds: 0,
      );
      await tester.pumpWidget(app(Scaffold(
        body: RecurringOccurrenceSheet(
          occurrence:
              RecurringOccurrence(payment: p, period: period, record: record),
        ),
      )));
      expect(find.byKey(const ValueKey('recurring_pay')), findsNothing);
      expect(find.byKey(const ValueKey('recurring_skip')), findsNothing);
      // Как в карточке операции: «Остановить» с контуром, «Редактировать» —
      // основная кнопка; на кнопках нет иконок
      expect(tester.widget(find.byKey(const ValueKey('recurring_edit'))),
          isA<SheetPrimaryButton>());
      expect(tester.widget(find.byKey(const ValueKey('recurring_stop'))),
          isA<SheetOutlinedButton>());
      expect(
          find.descendant(
              of: find.byType(ButtonStyleButton), matching: find.byType(Icon)),
          findsNothing);
    });

    testWidgets('оплата регулярного платежа в ленте — со значком ⟳',
        (tester) async {
      final record = Transaction(
        serverId: 'paid-id',
        amount: 1,
        description: '',
        dbCategory: 'housing',
        dbType: 'expense',
        dateMilliseconds: today.millisecondsSinceEpoch,
        dateCreatedMilliseconds: 0,
      );
      await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
          child: DayGroupWidget(
            date: today,
            transactions: [record],
            recurringRecordIds: const {'paid-id'},
            onTransactionTap: (_) {},
            onTransactionDelete: (_) {},
          ),
        ),
      )));
      expect(find.byKey(const ValueKey('transaction_recurring_mark')),
          findsOneWidget);
    });
  });

  group('«Можно тратить в день»', () {
    Budget budget(String category, double limit) => Budget(
          dbCategory: category,
          limitAmount: limit,
          currencyCode: 'EUR',
          month: 11,
          year: 2026,
          spent: 0,
          remaining: limit,
        );

    test('ожидаемые платежи в категориях с лимитом откладываются', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: [budget('housing', 1000000), budget('food', 900000)],
        spentByCategory: {'food': 300000},
        period: const MonthPeriod(2026, 11),
        reservedByCategory: {
          'housing': (amount: 350000, count: 1),
          // Категория без лимита — в лимиты не входит
          'communication': (amount: 50000, count: 1),
        },
        now: DateTime(2026, 11, 21),
      );
      // Осталось 10 дней: (1 900 000 − 300 000 − 350 000) / 10
      expect(summary.dailyAllowance, 125000);
      expect(summary.reservedCount, 1);
      expect(summary.reservedAmount, 350000);
    });

    test('в прошлом месяце ничего не откладывается', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: [budget('housing', 1000000)],
        spentByCategory: const {},
        period: const MonthPeriod(2026, 10),
        reservedByCategory: {'housing': (amount: 350000, count: 1)},
        now: DateTime(2026, 11, 21),
      );
      expect(summary.reservedCount, 0);
    });

    testWidgets('карточка «Бюджета» показывает отложенное', (tester) async {
      final summary = MonthBudgetSummary.calculate(
        budgets: [budget('housing', 1000000)],
        spentByCategory: const {},
        period: const MonthPeriod(2026, 11),
        reservedByCategory: {'housing': (amount: 350000, count: 2)},
        now: DateTime(2026, 11, 21),
      );
      await tester.pumpWidget(app(Scaffold(
        body: MonthBudgetCard(summary: summary, onAddLimit: () {}),
      )));
      expect(
          find.byKey(const ValueKey('month_budget_reserved')), findsOneWidget);
      expect(find.textContaining('С учётом 2 платежей'), findsOneWidget);
    });

    testWidgets('при перерасходе отложенное не показывается', (tester) async {
      final summary = MonthBudgetSummary.calculate(
        budgets: [budget('housing', 1000)],
        spentByCategory: const {'housing': 5000},
        period: const MonthPeriod(2026, 11),
        reservedByCategory: {'housing': (amount: 350, count: 1)},
        now: DateTime(2026, 11, 21),
      );
      await tester.pumpWidget(app(Scaffold(
        body: MonthBudgetCard(summary: summary, onAddLimit: () {}),
      )));
      expect(find.text('Перерасход'), findsOneWidget);
      expect(find.byKey(const ValueKey('month_budget_reserved')), findsNothing);
    });
  });

  group('Шторка вариантов', () {
    testWidgets('возвращает выбранное значение', (tester) async {
      int? picked;
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked = await AppOptionsSheet.show<int>(
              context,
              title: 'Сколько повторять',
              options: const [
                AppSheetOption(value: 1, label: 'Один', selected: true),
                AppSheetOption(value: 2, label: 'Два'),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.text('Два'));
      await tester.pumpAndSettle();
      expect(picked, 2);
    });
  });
}
