import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/screens/dashboard_screen.dart';
import 'package:getbalanceai_mobile/screens/transaction_search_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// USAB-01: поиск операций по описанию и категории с фильтрами типа и
/// валюты.

Transaction _tx({
  int id = 0,
  double amount = 10,
  TransactionType type = TransactionType.expense,
  Category category = Category.food,
  required DateTime date,
  String description = '',
  String currency = 'USD',
}) =>
    Transaction(
      localId: id,
      amount: amount,
      description: description,
      dbCategory: category.name,
      dbType: type.name,
      dateMilliseconds: date.millisecondsSinceEpoch,
      dateCreatedMilliseconds: date.millisecondsSinceEpoch,
      currencyCode: currency,
      baseAmount: currency == 'USD' ? amount : 0,
    );

Widget _buildTestApp(Widget child) => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      home: child,
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
    tempDir = await Directory.systemTemp.createTemp('transaction_search_test');
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

  group('TransactionSearch.apply', () {
    final l10n = LanguageManager.l10n;
    final day = DateTime(2026, 10, 15);
    final coffee = _tx(id: 1, date: day, description: 'Кофе с собой');
    final taxi = _tx(
        id: 2, date: day, description: 'Такси', category: Category.transport);
    final salary = _tx(
      id: 3,
      date: day,
      type: TransactionType.income,
      category: Category.salary,
      amount: 1000,
    );
    final lunchEur =
        _tx(id: 4, date: day, description: 'Обед', currency: 'EUR');
    final all = [coffee, taxi, salary, lunchEur];

    test('пустой запрос без фильтров — все операции в исходном порядке', () {
      expect(const TransactionSearch().apply(all, l10n), all);
      expect(const TransactionSearch(query: '   ').apply(all, l10n), all);
    });

    test('ищет в описании без учёта регистра и пробелов по краям', () {
      expect(
          const TransactionSearch(query: ' КОФЕ ').apply(all, l10n), [coffee]);
    });

    test('ищет по названию категории на языке приложения', () {
      final food = Category.food.localizedIn(l10n);
      final part = food.substring(0, 3).toLowerCase();
      expect(
          TransactionSearch(query: part).apply(all, l10n), [coffee, lunchEur]);
    });

    test('фильтр типа', () {
      expect(
          const TransactionSearch(type: TransactionType.income)
              .apply(all, l10n),
          [salary]);
      expect(
          const TransactionSearch(type: TransactionType.expense)
              .apply(all, l10n),
          [coffee, taxi, lunchEur]);
    });

    test('фильтр валюты и сочетание условий', () {
      expect(const TransactionSearch(currency: Currency.eur).apply(all, l10n),
          [lunchEur]);
      expect(
          const TransactionSearch(
            query: 'такси',
            type: TransactionType.income,
          ).apply(all, l10n),
          isEmpty);
    });

    test('copyWith сбрасывает фильтр в null', () {
      const search = TransactionSearch(
        query: 'a',
        type: TransactionType.expense,
        currency: Currency.eur,
      );
      final cleared = search.copyWith(type: () => null, currency: () => null);
      expect(cleared.query, 'a');
      expect(cleared.type, isNull);
      expect(cleared.currency, isNull);
    });

    test('currenciesOf — только встречающиеся валюты в порядке приложения', () {
      expect(TransactionSearch.currenciesOf(all), [
        for (final c in Currency.values)
          if (c == Currency.usd || c == Currency.eur) c
      ]);
      expect(TransactionSearch.currenciesOf(const []), isEmpty);
    });
  });

  group('TransactionSearchScreen', () {
    setUp(() async {
      await db.clearAllData();
    });

    tearDown(() {
      UndoableDeletions.transactions.undoWhere((_) => true);
    });

    Future<void> pumpSearch(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildTestApp(const TransactionSearchScreen()));
      await tester.pumpAndSettle();
    }

    final field = find.byKey(const ValueKey('transaction_search_field'));
    Finder tile(String description) => find.descendant(
          of: find.byType(TransactionItemTile),
          matching: find.text(description),
        );

    testWidgets(
        'ищет по всей истории, заголовок дня с годом, если он не текущий, '
        'и итог найденного', (tester) async {
      final lastYear = DateTime.now().year - 1;
      db.saveTransaction(
          _tx(date: DateTime(lastYear, 3, 5), description: 'Кофе', amount: 4));
      db.saveTransaction(
          _tx(date: DateTime.now(), description: 'Кофе зерно', amount: 6));
      db.saveTransaction(_tx(
          date: DateTime.now(),
          description: 'Такси',
          category: Category.transport));
      await pumpSearch(tester);

      // Пустой запрос — вся история
      expect(find.byType(TransactionItemTile), findsNWidgets(3));

      await tester.enterText(field, 'кофе');
      await tester.pumpAndSettle();

      expect(tile('Кофе'), findsOneWidget);
      expect(tile('Кофе зерно'), findsOneWidget);
      expect(tile('Такси'), findsNothing);
      expect(
        find.text(LanguageManager.formatDayMonthYear(DateTime(lastYear, 3, 5))),
        findsOneWidget,
      );
      final summary = find.byKey(const ValueKey('transaction_search_summary'));
      expect(
        find.descendant(
            of: summary,
            matching: find.text(LanguageManager.l10n.operations_count(2))),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: summary,
            matching: find.textContaining(CurrencyFormatter.format(10))),
        findsOneWidget,
      );
    });

    testWidgets('фильтр типа и «Ничего не найдено»', (tester) async {
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Кофе'));
      db.saveTransaction(_tx(
        date: DateTime.now(),
        description: 'Аванс',
        type: TransactionType.income,
        category: Category.salary,
      ));
      await pumpSearch(tester);

      await tester.tap(find.byKey(const ValueKey('search_type_income')));
      await tester.pumpAndSettle();
      expect(tile('Аванс'), findsOneWidget);
      expect(tile('Кофе'), findsNothing);

      await tester.enterText(field, 'кофе');
      await tester.pumpAndSettle();
      expect(
          find.text(LanguageManager.l10n.search_nothing_found), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search_type_all')));
      await tester.pumpAndSettle();
      expect(tile('Кофе'), findsOneWidget);
    });

    testWidgets('кнопка очистки сбрасывает запрос', (tester) async {
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Кофе'));
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Чай'));
      await pumpSearch(tester);

      final clear = find.byKey(const ValueKey('transaction_search_clear'));
      expect(clear, findsNothing);
      await tester.enterText(field, 'чай');
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemTile), findsOneWidget);

      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemTile), findsNWidgets(2));
      expect(clear, findsNothing);
    });

    testWidgets(
        'чипы валют — только при нескольких валютах; повторный тап снимает '
        'фильтр', (tester) async {
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Кофе'));
      await pumpSearch(tester);
      expect(find.byKey(const ValueKey('search_currency_USD')), findsNothing);

      db.saveTransaction(
          _tx(date: DateTime.now(), description: 'Обед', currency: 'EUR'));
      await tester.pumpAndSettle();
      final eur = find.byKey(const ValueKey('search_currency_EUR'));
      expect(eur, findsOneWidget);

      await tester.tap(eur);
      await tester.pumpAndSettle();
      expect(tile('Обед'), findsOneWidget);
      expect(tile('Кофе'), findsNothing);

      await tester.tap(eur);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemTile), findsNWidgets(2));
    });

    testWidgets(
        'выбранная валюта, операций в которой не осталось, перестаёт '
        'фильтровать', (tester) async {
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Кофе'));
      db.saveTransaction(
          _tx(date: DateTime.now(), description: 'Обед', currency: 'EUR'));
      await pumpSearch(tester);
      await tester.tap(find.byKey(const ValueKey('search_currency_EUR')));
      await tester.pumpAndSettle();

      final lunch =
          db.getAllTransactions().firstWhere((t) => t.description == 'Обед');
      db.deleteTransaction(lunch.localId);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('search_currency_EUR')), findsNothing);
      expect(tile('Кофе'), findsOneWidget);
    });

    testWidgets('свайп скрывает операцию, «Отменить» возвращает',
        (tester) async {
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Кофе'));
      db.saveTransaction(_tx(date: DateTime.now(), description: 'Чай'));
      await pumpSearch(tester);

      await tester.drag(
          find.byType(TransactionItemTile).last, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemTile), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('toast_action')));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemTile), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 6));
      expect(db.getAllTransactions(), hasLength(2));
    });

    group('после ухода с поиска тост остаётся над «Балансом»', () {
      Future<void> swipeInSearchAndGoBack(WidgetTester tester) async {
        tester.view
          ..physicalSize = const Size(800, 1600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        db.saveTransaction(_tx(date: DateTime.now(), description: 'Кофе'));
        await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
        await tester.pumpAndSettle();
        expect(tile('Кофе'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('dashboard_search')));
        await tester.pumpAndSettle();
        await tester.drag(tile('Кофе'), const Offset(-700, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.byType(TransactionSearchScreen), findsNothing);
        expect(tile('Кофе'), findsNothing,
            reason: '«Баланс» прячет операцию в ожидании удаления');
        expect(find.byKey(const ValueKey('toast_action')), findsOneWidget);
      }

      testWidgets('«Отменить» возвращает операцию', (tester) async {
        await swipeInSearchAndGoBack(tester);

        await tester.tap(find.byKey(const ValueKey('toast_action')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        expect(tile('Кофе'), findsOneWidget);
        expect(db.getAllTransactions(), hasLength(1));
      });

      testWidgets('без отмены операция удаляется по таймеру', (tester) async {
        await swipeInSearchAndGoBack(tester);

        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        expect(db.getAllTransactions(), isEmpty);
        expect(tile('Кофе'), findsNothing);
      });
    });
  });

  testWidgets('лупа в шапке «Баланса» открывает поиск', (tester) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_buildTestApp(const DashboardScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard_search')));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionSearchScreen), findsOneWidget);
    expect(find.text(LanguageManager.l10n.transaction_search_title),
        findsOneWidget);
  });
}
