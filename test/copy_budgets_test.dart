import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/budgets_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// USAB-02: копирование лимитов прошлого месяца в пустой месяц.

Budget _budget({
  required MonthPeriod period,
  Category category = Category.food,
  double limit = 100,
  String? currencyCode = 'USD',
  String? serverId,
}) =>
    Budget(
      serverId: serverId,
      dbCategory: category.name,
      limitAmount: limit,
      currencyCode: currencyCode,
      month: period.month,
      year: period.year,
      spent: 0,
      remaining: limit,
    );

Transaction _expense(DateTime date, double amount, Category category) =>
    Transaction(
      amount: amount,
      description: '',
      dbCategory: category.name,
      dbType: TransactionType.expense.name,
      dateMilliseconds: date.millisecondsSinceEpoch,
      dateCreatedMilliseconds: date.millisecondsSinceEpoch,
      currencyCode: 'USD',
      baseAmount: amount,
    );

Widget _buildTestApp(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalDbService db;

  setUpAll(() async {
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await CurrencyFormatter.setCurrency(Currency.usd);
    tempDir = await Directory.systemTemp.createTemp('copy_budgets_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? tempDir.path
          : null,
    );
    await LocalDbService.init();
    db = LocalDbService.instance;
  });

  tearDown(() {
    UndoableDeletions.budgets.undoWhere((_) => true);
    SelectedPeriodService.instance.reset();
  });

  group('LocalDbService.copyBudgets', () {
    test(
        'копирует категорию, сумму и валюту как новые лимиты, потраченное — '
        'по операциям нового месяца', () {
      const from = MonthPeriod(2034, 1);
      const to = MonthPeriod(2034, 2);
      db.saveBudget(_budget(period: from, limit: 300, serverId: 'srv-jan'));
      db.saveBudget(_budget(
        period: from,
        category: Category.transport,
        limit: 50,
        currencyCode: 'EUR',
      ));
      db.saveTransaction(_expense(DateTime(2034, 2, 3), 40, Category.food));

      db.copyBudgets(db.getBudgetsForPeriod(from.month, from.year), to);

      final copies = {
        for (final b in db.getBudgetsForPeriod(to.month, to.year))
          b.category: b,
      };
      expect(copies.keys, {Category.food, Category.transport});
      final food = copies[Category.food]!;
      expect(food.limitAmount, 300);
      expect(food.currency, Currency.usd);
      expect(food.spent, 40);
      expect(food.remaining, 260);
      expect(food.serverId, isNull, reason: 'копия — новая запись');
      expect(food.isModified, isFalse);
      expect(copies[Category.transport]!.currency, Currency.eur);

      // Исходный месяц не тронут
      final source = db.getBudgetsForPeriod(from.month, from.year);
      expect(source, hasLength(2));
      expect(
          source.firstWhere((b) => b.serverId == 'srv-jan').limitAmount, 300);
    });

    test('лимит без валюты копируется в текущей базовой валюте явно', () {
      const from = MonthPeriod(2034, 3);
      const to = MonthPeriod(2034, 4);
      db.saveBudget(_budget(period: from, currencyCode: null));

      db.copyBudgets(db.getBudgetsForPeriod(from.month, from.year), to);

      expect(db.getBudgetsForPeriod(to.month, to.year).single.currencyCode,
          Currency.usd.code);
    });

    test('лимит той же категории в новом месяце обновляется без дубля', () {
      const from = MonthPeriod(2034, 5);
      const to = MonthPeriod(2034, 6);
      db.saveBudget(_budget(period: from, limit: 500));
      db.saveBudget(_budget(period: to, limit: 10, serverId: 'srv-june'));

      db.copyBudgets(db.getBudgetsForPeriod(from.month, from.year), to);

      final june = db.getBudgetsForPeriod(to.month, to.year).single;
      expect(june.limitAmount, 500);
      expect(june.serverId, 'srv-june');
      expect(june.isModified, isTrue,
          reason: 'сервер должен получить новую сумму той же записи');
    });
  });

  group('MonthBudgetCard', () {
    final emptySummary = MonthBudgetSummary.calculate(
      budgets: const [],
      spentByCategory: const {},
      period: const MonthPeriod(2034, 11),
    );

    testWidgets('без источника кнопки копирования нет', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        MonthBudgetCard(summary: emptySummary, onAddLimit: () {}),
      ));

      expect(
          find.byKey(const ValueKey('month_budget_copy_limits')), findsNothing);
    });

    testWidgets('кнопка называет месяц-источник и вызывает копирование',
        (tester) async {
      var copied = false;
      await tester.pumpWidget(_buildTestApp(MonthBudgetCard(
        summary: emptySummary,
        onAddLimit: () {},
        copyLimitsFrom: const MonthPeriod(2034, 10),
        onCopyLimits: () => copied = true,
      )));

      expect(find.text('Скопировать из октября'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('month_budget_copy_limits')));
      expect(copied, isTrue);
    });

    testWidgets(
        'длинная подпись на узком экране с крупным шрифтом не выходит '
        'за кнопку', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (language, month) in [
        (AppLanguage.ru, 9),
        (AppLanguage.en, 9),
      ]) {
        LanguageManager.setLanguage(language, save: false);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(language.name),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MonthBudgetCard(
                  summary: emptySummary,
                  onAddLimit: () {},
                  copyLimitsFrom: MonthPeriod(2034, month),
                  onCopyLimits: () {},
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: language.name);
      }
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
    });

    test('подпись есть для каждого месяца на всех языках', () {
      for (final language in AppLanguage.values) {
        LanguageManager.setLanguage(language, save: false);
        final l10n = LanguageManager.l10n;
        final other = l10n.copy_limits_cta('m0');
        for (var m = 1; m <= 12; m++) {
          expect(l10n.copy_limits_cta('m$m'), isNot(other),
              reason: '${language.name}, месяц $m');
        }
      }
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
    });
  });

  group('BudgetsScreen', () {
    Future<void> pumpScreen(WidgetTester tester, MonthPeriod period) async {
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SelectedPeriodService.instance.select(period);
      await tester.pumpWidget(_buildTestApp(const BudgetsScreen()));
      await tester.pumpAndSettle();
    }

    final copyButton = find.byKey(const ValueKey('month_budget_copy_limits'));

    testWidgets('пустой месяц без лимитов в прошлом — кнопки нет',
        (tester) async {
      await pumpScreen(tester, const MonthPeriod(2030, 3));

      expect(
          find.byKey(const ValueKey('month_budget_add_limit')), findsOneWidget);
      expect(copyButton, findsNothing);
    });

    testWidgets('кнопка копирует лимиты прошлого месяца и пропадает',
        (tester) async {
      const from = MonthPeriod(2030, 4);
      const to = MonthPeriod(2030, 5);
      db.saveBudget(_budget(period: from, limit: 200));
      db.saveBudget(
          _budget(period: from, category: Category.transport, limit: 70));
      await pumpScreen(tester, to);

      expect(find.text('Скопировать из апреля'), findsOneWidget);
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(find.byType(BudgetItemCard), findsNWidgets(2));
      expect(copyButton, findsNothing);
      expect(db.getBudgetsForPeriod(to.month, to.year), hasLength(2));
    });

    testWidgets('лимит прошлого месяца в ожидании удаления не копируется',
        (tester) async {
      const from = MonthPeriod(2030, 6);
      const to = MonthPeriod(2030, 7);
      db.saveBudget(_budget(period: from));
      UndoableDeletions.budgets
          .schedule(db.getBudgetsForPeriod(from.month, from.year).single);
      await pumpScreen(tester, to);

      expect(copyButton, findsNothing);
    });

    testWidgets(
        'удалил лимиты месяца свайпом и сразу скопировал — копия не '
        'стирается отложенным удалением', (tester) async {
      const from = MonthPeriod(2030, 8);
      const to = MonthPeriod(2030, 9);
      db.saveBudget(_budget(period: from, limit: 400));
      db.saveBudget(_budget(period: to, limit: 90));
      UndoableDeletions.budgets
          .schedule(db.getBudgetsForPeriod(to.month, to.year).single);
      await pumpScreen(tester, to);

      await tester.tap(copyButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      final september = db.getBudgetsForPeriod(to.month, to.year);
      expect(september.single.limitAmount, 400);
      expect(find.byType(BudgetItemCard), findsOneWidget);
    });
  });
}
