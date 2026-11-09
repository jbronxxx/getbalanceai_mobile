import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/cubits/profile/profile_cubit.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/add_transaction_sheet.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/app_alerts.dart';
import 'package:getbalanceai_mobile/widgets/budgets/budgets.dart';
import 'package:getbalanceai_mobile/widgets/transaction/transaction.dart';

class _MockLocalDbService extends Mock implements LocalDbService {}

class _MockApiService extends Mock implements ApiService {}

class _MockConnectivity extends Mock implements Connectivity {}

Widget _app(Widget child, {EdgeInsets padding = EdgeInsets.zero}) =>
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: app!,
      ),
      home: Scaffold(body: child),
    );

Budget _budget(double limit) => Budget(
      dbCategory: Category.food.name,
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
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(Currency.usd);
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    await CurrencyFormatter.setCurrency(Currency.usd);
  });

  group('UX-01: клавиатура убирается', () {
    testWidgets('тап вне поля суммы снимает фокус', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(_app(Column(
        children: [
          TransactionAmountField(
            controller: TextEditingController(),
            currency: Currency.usd,
            onCurrencyTap: () {},
            focusNode: focus,
          ),
          const SizedBox(height: 200, child: Text('outside')),
        ],
      )));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.tap(find.text('outside'));
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    });

    testWidgets('смена «Расход/Доход» не закрывает клавиатуру', (tester) async {
      final db = _MockLocalDbService();
      when(() => db.getFrequentCategories(any())).thenReturn(const []);
      LocalDbService.instance = db;
      addTearDown(() => LocalDbService.instance = null);

      await tester.pumpWidget(_app(const AddTransactionSheet()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      final amount = tester.widget<TextField>(find.byType(TextField).first);
      expect(amount.focusNode!.hasFocus, isTrue);

      await tester.tap(find.text(LanguageManager.l10n.income_title));
      await tester.pump();
      expect(amount.focusNode!.hasFocus, isTrue);

      // А тап по свободному месту — закрывает
      await tester.tap(find.text(LanguageManager.l10n.new_transaction));
      await tester.pump();
      expect(amount.focusNode!.hasFocus, isFalse);
    });

    testWidgets('шторки операции и лимита прячут клавиатуру при прокрутке',
        (tester) async {
      final db = _MockLocalDbService();
      when(() => db.getFrequentCategories(any())).thenReturn(const []);
      LocalDbService.instance = db;
      addTearDown(() => LocalDbService.instance = null);

      for (final sheet in [
        const AddTransactionSheet(),
        AddBudgetSheet(selectedMonth: 11, selectedYear: 2026, onSaved: () {}),
      ]) {
        await tester.pumpWidget(_app(sheet));
        final scroll = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first,
        );
        expect(
          scroll.keyboardDismissBehavior,
          ScrollViewKeyboardDismissBehavior.onDrag,
        );
      }
    });
  });

  group('UX-02: повторный синк без сети', () {
    test('каждая попытка — новое событие для экрана', () async {
      final connectivity = _MockConnectivity();
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      final cubit = ProfileCubit(
        api: _MockApiService(),
        connectivity: connectivity,
      );
      addTearDown(cubit.close);

      await cubit.startSync();
      final first = cubit.state;
      await cubit.startSync();
      final second = cubit.state;

      expect(first.syncStatus, SyncStatus.noInternet);
      expect(second.syncStatus, SyncStatus.noInternet);
      // Статус тот же, но номер попытки другой — слушатель экрана сработает
      expect(second.syncAttempt, first.syncAttempt + 1);
    });
  });

  group('UX-04: тост из шторки виден поверх неё', () {
    testWidgets('показывается в оверлее над шторкой и сам скрывается',
        (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (sheetContext) => SizedBox(
              height: 300,
              child: TextButton(
                onPressed: () =>
                    AppAlerts.info(sheetContext, 'нет операций за период'),
                child: const Text('export'),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('export'));
      await tester.pump(const Duration(milliseconds: 250));

      // Не SnackBar главного экрана под затемнением, а тост поверх шторки
      expect(find.byType(SnackBar), findsNothing);
      final toast = find.text('нет операций за период');
      expect(toast, findsOneWidget);
      expect(tester.getRect(toast).top,
          lessThan(tester.getRect(find.text('export')).top));
      // Крестик тоста нажимается — он над затемнением, а не под ним
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(toast, findsNothing);

      // Без нажатия тост скрывается сам
      await tester.tap(find.text('export'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(toast, findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(toast, findsNothing);
    });
  });

  group('UX-05: дата новой операции в открытом месяце', () {
    final now = DateTime(2026, 11, 9, 14, 30, 5);

    test('прошлый месяц — его последний день, время текущее', () {
      expect(
        AddTransactionSheet.defaultDateFor(const MonthPeriod(2026, 9), now),
        DateTime(2026, 9, 30, 14, 30, 5),
      );
      expect(
        AddTransactionSheet.defaultDateFor(const MonthPeriod(2024, 2), now),
        DateTime(2024, 2, 29, 14, 30, 5),
      );
    });

    test('текущий и будущий месяц — сейчас', () {
      expect(
        AddTransactionSheet.defaultDateFor(const MonthPeriod(2026, 11), now),
        now,
      );
      expect(
        AddTransactionSheet.defaultDateFor(const MonthPeriod(2027, 1), now),
        now,
      );
    });

    testWidgets('на чипе даты — год, если он не текущий', (tester) async {
      await tester.pumpWidget(_app(TransactionDateSelector(
        date: DateTime(2025, 3, 5),
        now: now,
        onChanged: (_) {},
      )));
      expect(find.text('5 марта 2025'), findsOneWidget);

      await tester.pumpWidget(_app(TransactionDateSelector(
        date: DateTime(2026, 3, 5),
        now: now,
        onChanged: (_) {},
      )));
      expect(find.text('5 марта'), findsOneWidget);
    });
  });

  group('UX-06: сводка бюджета не повторяет сумму', () {
    Future<void> pump(WidgetTester tester, MonthPeriod period, double spent) {
      final summary = MonthBudgetSummary.calculate(
        budgets: [_budget(1000)],
        spentByCategory: {Category.food.name: spent},
        period: period,
        now: DateTime(2026, 11, 9),
      );
      return tester.pumpWidget(
        _app(MonthBudgetCard(summary: summary, onAddLimit: () {})),
      );
    }

    testWidgets('прошлый месяц: итог только в заголовке', (tester) async {
      await pump(tester, const MonthPeriod(2026, 10), 400);
      expect(find.text(CurrencyFormatter.format(600)), findsOneWidget);
      expect(find.text(LanguageManager.l10n.budget_remaining), findsNothing);
    });

    testWidgets('будущий месяц: только «Запланировано»', (tester) async {
      await pump(tester, const MonthPeriod(2026, 12), 0);
      expect(find.text(LanguageManager.l10n.budget_planned), findsOneWidget);
      expect(find.text(CurrencyFormatter.format(1000)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('month_budget_progress')),
        findsNothing,
      );
    });

    testWidgets(
        'текущий месяц: сумма в день и шкала, без плашек «Лимиты / Траты / '
        'Осталось»', (tester) async {
      await pump(tester, const MonthPeriod(2026, 11), 400);
      expect(find.text(LanguageManager.l10n.daily_allowance), findsOneWidget);
      expect(
          find.byKey(const ValueKey('month_budget_progress')), findsOneWidget);
      expect(find.text(LanguageManager.l10n.budget_remaining), findsNothing);
      expect(find.text(CurrencyFormatter.format(1000)), findsNothing);
      expect(find.text(CurrencyFormatter.format(400)), findsNothing);
    });
  });

  group('UX-07.2: отступ под кнопкой шторки лимита', () {
    testWidgets('системная полоска учитывается один раз', (tester) async {
      final db = _MockLocalDbService();
      when(() => db.getFrequentCategories(any())).thenReturn(const []);
      LocalDbService.instance = db;
      addTearDown(() => LocalDbService.instance = null);
      const systemBar = 34.0;

      await tester.pumpWidget(_app(
        Align(
          alignment: Alignment.bottomCenter,
          child: AddBudgetSheet(
            selectedMonth: 11,
            selectedYear: 2026,
            onSaved: () {},
          ),
        ),
        padding: const EdgeInsets.only(bottom: systemBar),
      ));

      final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
      final saveBottom =
          tester.getRect(find.text(LanguageManager.l10n.save_btn)).bottom;
      // 24 — отступ шторки, 34 — системная полоска; раньше было 24 + 34 × 2
      expect(screenBottom - saveBottom,
          lessThan(24 + systemBar + 30)); // + внутренний отступ кнопки
    });
  });

  group('L10N-01: язык при первом запуске', () {
    test('первый поддерживаемый язык системы', () {
      expect(
        LanguageManager.languageForLocales(
            const [Locale('de'), Locale('uz', 'UZ'), Locale('ru')]),
        AppLanguage.uz,
      );
      expect(
        LanguageManager.languageForLocales(const [Locale('de')]),
        isNull,
      );
    });

    test('без сохранённого языка берётся язык системы', () async {
      await LanguageManager.loadSavedLanguage(
        systemLocales: const [Locale('kk', 'KZ')],
      );
      expect(LanguageManager.currentLanguage, AppLanguage.kk);
    });

    test('сохранённый язык важнее системного', () async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.instance.saveLanguage('en');
      await LanguageManager.loadSavedLanguage(
        systemLocales: const [Locale('kk')],
      );
      expect(LanguageManager.currentLanguage, AppLanguage.en);
    });
  });
}
