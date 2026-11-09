import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/insights/report_export_action.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

Transaction _tx({
  required double amount,
  required String category,
  TransactionType type = TransactionType.expense,
  DateTime? date,
  int localId = 0,
  String? serverId,
}) {
  final at = date ?? DateTime(2026, 11, 5, 12);
  return Transaction(
    localId: localId,
    serverId: serverId,
    amount: amount,
    description: 'op',
    dbCategory: category,
    dbType: type.name,
    dateMilliseconds: at.millisecondsSinceEpoch,
    dateCreatedMilliseconds: at.millisecondsSinceEpoch,
    currencyCode: 'USD',
    baseAmount: amount,
  );
}

Budget _budget(String category, double limit, {String? serverId}) => Budget(
      serverId: serverId,
      dbCategory: category,
      limitAmount: limit,
      currencyCode: 'USD',
      month: 11,
      year: 2026,
      spent: 0,
      remaining: limit,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
    registerFallbackValue(_tx(amount: 0, category: 'food'));
    registerFallbackValue(Currency.usd);
    registerFallbackValue(TransactionType.expense);
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await CurrencyFormatter.setCurrency(Currency.usd);
  });

  group('LOGIC-09.3: погрешность double не даёт «0.00» со знаком', () {
    test('roundToCurrency: до знаков валюты, −0 → 0', () {
      expect(CurrencyFormatter.roundToCurrency(100 - 99.99 - 0.01), 0);
      expect(
        CurrencyFormatter.roundToCurrency(-0.001).isNegative,
        isFalse,
      );
      expect(CurrencyFormatter.roundToCurrency(19.999), 20);
      expect(CurrencyFormatter.roundToCurrency(1234.6, Currency.uzs), 1235);
    });

    test('format со знаком: почти ноль — без «+» и «−»', () {
      expect(
        CurrencyFormatter.format(-0.001, showSign: true, locale: 'en'),
        r'$0.00',
      );
      expect(
        CurrencyFormatter.format(0.004, showSign: true, locale: 'en'),
        r'$0.00',
      );
      expect(
        CurrencyFormatter.format(-0.01, showSign: true, locale: 'en'),
        r'-$0.01',
      );
    });

    testWidgets('лимит, потраченный ровно (с погрешностью), — не превышен',
        (tester) async {
      // 0.1 + 0.2 = 0.30000000000000004 > 0.3
      await tester.pumpWidget(_app(BudgetItemCard(
        budget: _budget('food', 0.3),
        currentSpent: 0.1 + 0.2,
        isFirst: false,
        showSwipeHint: false,
        onTap: () {},
        onDelete: () {},
        onHintShown: () {},
      )));

      expect(find.textContaining(LanguageManager.l10n.budget_exceeded),
          findsNothing);
      expect(find.text(LanguageManager.l10n.budget_remaining), findsOneWidget);
    });

    test('сводка месяца: перерасход в доли копейки — не перерасход', () {
      final summary = MonthBudgetSummary.calculate(
        budgets: [_budget('food', 0.3)],
        spentByCategory: {'food': 0.1 + 0.2},
        period: const MonthPeriod(2026, 11),
        now: DateTime(2026, 11, 10),
      );
      expect(summary.isExceeded, isFalse);

      final over = MonthBudgetSummary.calculate(
        budgets: [_budget('food', 0.3)],
        spentByCategory: {'food': 0.31},
        period: const MonthPeriod(2026, 11),
        now: DateTime(2026, 11, 10),
      );
      expect(over.isExceeded, isTrue);
    });
  });

  group('LOGIC-10: «Прочее» по категориям', () {
    test('доход и расход «Прочее» — разные группы, а не 0', () {
      final summaries = CategoryMonthSummary.fromTransactions([
        _tx(amount: 50, category: 'other', type: TransactionType.income),
        _tx(amount: 50, category: 'other'),
        _tx(amount: 10, category: 'food'),
      ]);

      final other = summaries.where((s) => s.category == Category.other);
      expect(other, hasLength(2));
      expect(
        {for (final s in other) s.type: s.total},
        {TransactionType.income: 50, TransactionType.expense: -50},
      );
      // Ключи виджетов не совпадают
      expect(summaries.map((s) => s.id).toSet(), hasLength(3));
    });
  });

  group('LOGIC-11: диапазон периода и смена месяца', () {
    final service = SelectedPeriodService.instance;
    tearDown(service.reset);

    test('шапка доступна с того же года, что и календарь операции', () {
      final year = DateTime.now().year - SelectedPeriodService.yearRange;
      expect(service.earliest, MonthPeriod(year, 1));
      expect(service.firstDate, DateTime(year));
      service.select(MonthPeriod(year, 4));
      expect(service.period, MonthPeriod(year, 4));
      expect(
        service.lastDate,
        DateTime(DateTime.now().year + SelectedPeriodService.yearRange, 12, 31),
      );
    });

    test('после полуночи 1-го числа текущий месяц сменяется новым', () {
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1, 0, 0, 5);

      service.syncWithCalendar(nextMonth);

      expect(service.period, MonthPeriod.current(nextMonth));
    });

    test('выбранный вручную другой месяц не переключается', () {
      final now = DateTime.now();
      final chosen = MonthPeriod.current(now).previous.previous;
      service.select(chosen);

      service.syncWithCalendar(DateTime(now.year, now.month + 1, 1, 0, 0, 5));

      expect(service.period, chosen);
    });
  });

  group('LOGIC-04: «Свой период» при месяце на несколько лет вперёд', () {
    testWidgets('календарь открывается без ошибки диапазона', (tester) async {
      final year = DateTime.now().year + SelectedPeriodService.yearRange;
      await tester.pumpWidget(_app(
        ReportExportAction(selectedMonth: 12, selectedYear: year),
      ));
      await tester.tap(find.byIcon(Icons.file_download_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_today_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });
  });

  group('SYNC-07: неизвестная клиенту категория с сервера', () {
    test('отправляется на сервер как пришла, а не «other»', () {
      final t = Transaction.fromJson({
        'id': 'srv-1',
        'amount': 10,
        'category': 'pets',
        'type': 'expense',
        'date': '2026-11-05T10:00:00Z',
      });
      expect(t.category, Category.other);
      expect(t.toJson()['category'], 'pets');

      final b = Budget.fromJson({
        'id': 'b-1',
        'category': 'pets',
        'limit_amount': 100,
        'month': 11,
        'year': 2026,
      });
      expect(b.toJson()['category'], 'pets');
    });

    test('траты по лимитам считаются по своей категории, без задвоения', () {
      final transactions = [
        _tx(amount: 30, category: 'pets'),
        _tx(amount: 20, category: 'kids'),
        _tx(amount: 10, category: 'other'),
      ];
      final budgets = [
        _budget('pets', 100),
        _budget('kids', 100),
        _budget('other', 100),
      ];

      final summary = MonthBudgetSummary.calculate(
        budgets: budgets,
        spentByCategory: {'pets': 30, 'kids': 20, 'other': 10},
        period: const MonthPeriod(2026, 11),
        now: DateTime(2026, 11, 10),
      );
      // Раньше: по 60 «Прочего» на каждый из трёх лимитов = 180
      expect(summary.totalSpent, 60);

      final report = ReportDataService.assemble(
        period: ReportPeriod.month(11, 2026),
        currency: Currency.usd,
        transactions: transactions,
        budgets: budgets,
        exchange: CurrencyExchangeService.instance,
        now: DateTime(2026, 11, 30),
      );
      expect(report.budgetLines.map((l) => l.spent),
          unorderedEquals([30, 20, 10]));
    });

    group('правка в шторке', () {
      late _MockLocalDbService mockDb;

      setUp(() {
        mockDb = _MockLocalDbService();
        when(() => mockDb.getFrequentCategories(any())).thenReturn(const []);
        when(() => mockDb.saveTransaction(any())).thenReturn(null);
        LocalDbService.instance = mockDb;
      });

      tearDown(() => LocalDbService.instance = null);

      Future<Transaction> editAndSave(
        WidgetTester tester, {
        Category? pick,
      }) async {
        await tester.pumpWidget(_app(Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: AddTransactionSheet(
                    transactionToEdit: _tx(
                      amount: 15,
                      category: 'pets',
                      localId: 4,
                      serverId: 'srv-4',
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        )));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (pick != null) {
          final chip = find.byKey(ValueKey('category_chip_${pick.name}'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
        }
        final submit = find.byKey(const ValueKey('add_transaction_submit'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        return verify(() => mockDb.saveTransaction(captureAny()))
            .captured
            .single as Transaction;
      }

      testWidgets('без смены категории исходная строка сохраняется',
          (tester) async {
        final saved = await editAndSave(tester);
        expect(saved.dbCategory, 'pets');
        expect(saved.isModified, isTrue);
      });

      testWidgets('выбранная пользователем категория перезаписывает',
          (tester) async {
        final saved = await editAndSave(tester, pick: Category.food);
        expect(saved.dbCategory, 'food');
      });
    });
  });

  group('ARCH-01: очистка сессии из отладочного меню', () {
    test('resetSession сообщает о выходе в authStream', () async {
      final events = <bool>[];
      final sub = ApiService.instance.authStream.listen(events.add);
      addTearDown(sub.cancel);

      await ApiService.instance.resetSession();
      await Future<void>.delayed(Duration.zero);

      expect(events, [false]);
      expect(ApiService.instance.isAuthenticated, isFalse);
    });
  });

  group('L10N-02: склонения и единицы из ICU', () {
    test('операции: ru — по правилам plural, en — one/other', () async {
      final ru = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(ru.operations_count(1), '1 операция');
      expect(ru.operations_count(3), '3 операции');
      expect(ru.operations_count(11), '11 операций');
      expect(ru.operations_count(21), '21 операция');

      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.operations_count(1), '1 transaction');
      expect(en.operations_count(2), '2 transactions');
    });

    test('обратный отсчёт: единица секунд на языке интерфейса', () async {
      final uz = await AppLocalizations.delegate.load(const Locale('uz'));
      final kk = await AppLocalizations.delegate.load(const Locale('kk'));
      expect(uz.rate_limit_countdown(5), contains('5 soniya'));
      expect(kk.rate_limit_countdown(5), contains('5 сек.'));
    });
  });
}
