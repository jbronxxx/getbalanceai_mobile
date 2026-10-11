import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/models/models.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/screens/welcome_setup_screen.dart';
import 'package:getbalanceai_mobile/widgets/welcome_language_sheet.dart';
import 'package:getbalanceai_mobile/widgets/dashboard/dashboard.dart';
import 'package:getbalanceai_mobile/widgets/profile/currency_picker_sheet.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tempDir = await Directory.systemTemp.createTemp('multi_curr_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    await LocalDbService.init();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    await CurrencyFormatter.loadSavedCurrency();
    await CurrencyExchangeService.instance.init();
  });

  group('CurrencyExchangeService Tests', () {
    test('Конвертация одинаковой валюты возвращает исходную сумму и курс 1.0',
        () {
      final service = CurrencyExchangeService.instance;
      expect(
          service.getRate(from: Currency.rub, to: Currency.rub), equals(1.0));
      expect(
        service.convert(1500, from: Currency.rub, to: Currency.rub),
        equals(1500.0),
      );
    });

    test('Корректный расчет кросс-курса UZS к RUB и RUB к UZS', () {
      final service = CurrencyExchangeService.instance;
      final uzsToRub = service.getRate(from: Currency.uzs, to: Currency.rub);
      final rubToUzs = service.getRate(from: Currency.rub, to: Currency.uzs);

      expect(uzsToRub, greaterThan(0.0));
      expect(rubToUzs, greaterThan(0.0));
      // Произведение кросс-курсов должно быть близко к 1.0
      expect((uzsToRub * rubToUzs - 1.0).abs(), lessThan(0.001));

      // 1 000 000 сум в рублях должно быть разумной суммой (~7000-8000 руб)
      final convertedRub =
          service.convert(1000000, from: Currency.uzs, to: Currency.rub);
      expect(convertedRub, greaterThan(5000));
      expect(convertedRub, lessThan(12000));
    });

    test('Форматирование текстового описания курса', () {
      final service = CurrencyExchangeService.instance;
      final desc =
          service.formatRateDescription(from: Currency.uzs, to: Currency.rub);
      expect(desc, contains('сум'));
      expect(desc, contains('≈'));
    });
  });

  group('Transaction & TransactionModel Multi-Currency Serialization', () {
    test('Transaction корректно парсит данные с полями валюты', () {
      final json = {
        'id': 'tx-123',
        'amount': 120000.0,
        'currency': 'UZS',
        'exchange_rate': 0.0075,
        'base_amount': 900.0,
        'description': 'Кафе в Ташкенте',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-11T12:00:00Z',
      };

      final tx = Transaction.fromJson(json);
      expect(tx.amount, equals(120000.0));
      expect(tx.currencyCode, equals('UZS'));
      expect(tx.currency, equals(Currency.uzs));
      expect(tx.exchangeRate, equals(0.0075));
      expect(tx.baseAmount, equals(900.0));
      expect(tx.effectiveBaseAmount, equals(900.0));

      final serialized = tx.toJson();
      expect(serialized['currency'], equals('UZS'));
      expect(serialized['exchange_rate'], equals(0.0075));
      expect(serialized['base_amount'], equals(900.0));
    });

    test(
        'Обратная совместимость: Transaction корректно работает со старыми записями без валюты',
        () {
      final legacyJson = {
        'id': 'legacy-1',
        'amount': '2500.50',
        'description': 'Обед',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-11T12:00:00Z',
      };

      final tx = Transaction.fromJson(legacyJson);
      expect(tx.amount, equals(2500.50));
      expect(tx.exchangeRate, equals(1.0));
      expect(tx.baseAmount, equals(2500.50));
      expect(tx.effectiveBaseAmount, equals(2500.50));
    });

    test(
        'TransactionModel DTO сериализация и десериализация мультивалютных полей',
        () {
      final json = {
        'id': 'tx-dto',
        'amount': 50.0,
        'currency': 'USD',
        'exchange_rate': 96.0,
        'base_amount': 4800.0,
        'description': 'Книга',
        'category': 'shopping',
        'type': 'expense',
        'date': '2026-10-11T10:00:00Z',
      };

      final model = TransactionModel.fromJson(json);
      expect(model.currency, equals('USD'));
      expect(model.exchangeRate, equals(96.0));
      expect(model.baseAmount, equals(4800.0));

      final serialized = model.toJson();
      expect(serialized['currency'], equals('USD'));
      expect(serialized['base_amount'], equals(4800.0));
    });
  });

  group('CurrencyFormatter Multi-Currency Tests', () {
    test('Форматирование суммы с указанием конкретной валюты', () {
      final formattedUzs =
          CurrencyFormatter.format(150000, currency: Currency.uzs);
      expect(formattedUzs, contains('150 000'));

      final formattedUsd =
          CurrencyFormatter.format(25.5, currency: Currency.usd);
      expect(formattedUsd, contains(r'$'));
      expect(formattedUsd, contains('25,50'));
    });
  });

  group('WelcomeLanguageSheet UI Tests', () {
    testWidgets(
        'Отображение секций языка и базовой валюты в WelcomeLanguageSheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ru'),
          home: Scaffold(
            body: WelcomeLanguageSheet(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Проверяем наличие секций
      expect(find.textContaining('Русский'), findsOneWidget);
      expect(find.textContaining('O\'zbekcha'), findsOneWidget);
      expect(find.textContaining('English'), findsOneWidget);

      // Проверяем наличие чипов валют
      expect(find.text('RUB'), findsOneWidget);
      expect(find.text('UZS'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);

      // Проверяем наличие кнопки продолжения
      expect(find.text('Продолжить'), findsOneWidget);
    });
  });

  group('WelcomeSetupScreen Step Flow Tests', () {
    testWidgets('Пошаговый переход: шаг 1 (язык) -> шаг 2 (валюта)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ru'),
          home: WelcomeSetupScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Шаг 1: отображается выбор языка без флагов и без иконки настроек
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('O\'zbekcha'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // Нажимаем продолжить для перехода на шаг 2
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      // Шаг 2: отображается выбор валюты словами
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Российский рубль'), findsOneWidget);
      expect(find.text('Узбекский сум'), findsOneWidget);
      expect(find.text('Казахстанский тенге'), findsOneWidget);

      // Проверяем возврат на шаг 1 по кнопке назад
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Русский'), findsOneWidget);
    });
  });

  group('LanguageManager.formatOperationsCount Tests', () {
    test('Русская грамматика для количества операций', () {
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      expect(LanguageManager.formatOperationsCount(1), equals('1 операция'));
      expect(LanguageManager.formatOperationsCount(2), equals('2 операции'));
      expect(LanguageManager.formatOperationsCount(4), equals('4 операции'));
      expect(LanguageManager.formatOperationsCount(5), equals('5 операций'));
      expect(LanguageManager.formatOperationsCount(11), equals('11 операций'));
      expect(LanguageManager.formatOperationsCount(14), equals('14 операций'));
      expect(LanguageManager.formatOperationsCount(21), equals('21 операция'));
      expect(LanguageManager.formatOperationsCount(22), equals('22 операции'));
      expect(LanguageManager.formatOperationsCount(25), equals('25 операций'));
    });

    test('Узбекский язык для количества операций', () {
      LanguageManager.setLanguage(AppLanguage.uz, save: false);
      expect(
          LanguageManager.formatOperationsCount(1), equals('1 ta operatsiya'));
      expect(
          LanguageManager.formatOperationsCount(5), equals('5 ta operatsiya'));
    });

    test('Английский язык для количества операций', () {
      LanguageManager.setLanguage(AppLanguage.en, save: false);
      expect(LanguageManager.formatOperationsCount(1), equals('1 transaction'));
      expect(
          LanguageManager.formatOperationsCount(5), equals('5 transactions'));
    });
  });

  group('CategoryGroupWidget Multi-Currency & Expansion Tests', () {
    testWidgets(
        'Отображает сумму в базовой валюте со знаком валюты, оригинальную валюту чека, количество операций и шеврон',
        (WidgetTester tester) async {
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      CurrencyFormatter.setCurrency(Currency.rub);

      final foreignTx = Transaction(
        localId: 1,
        amount: 1000000,
        description: 'Кинотеатр',
        dbCategory: Category.entertainment.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
        currencyCode: 'UZS',
        exchangeRate: 0.00716155,
        baseAmount: 7161.55,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: CategoryGroupWidget(
              category: Category.entertainment,
              transactions: [foreignTx],
              onTransactionTap: (_) {},
              onTransactionDelete: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Проверяем заголовок категории и счетчик операций
      expect(find.text('Развлечения'), findsOneWidget);
      expect(find.text('1 операция'), findsOneWidget);

      // В шапке сумма приведена к базовой валюте со знаком валюты
      expect(
        find.text(
          CurrencyFormatter.format(-foreignTx.effectiveBaseAmount,
              showSign: true),
        ),
        findsOneWidget,
      );

      // Под суммой отображается оригинальная сумма в валюте чека
      expect(find.text('-1 000 000 сум'), findsOneWidget);

      // Проверяем наличие шеврона
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Раскрываем карточку тапом
      await tester.tap(find.text('Развлечения'));
      await tester.pumpAndSettle();

      // Внутри отображается дочерняя транзакция с описанием
      expect(find.text('Кинотеатр'), findsOneWidget);
    });

    testWidgets(
        'Для операций только в базовой валюте не показывает подстроку иностранной валюты',
        (WidgetTester tester) async {
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      CurrencyFormatter.setCurrency(Currency.rub);

      final rubTx = Transaction(
        localId: 2,
        amount: 500,
        description: 'Кофе',
        dbCategory: Category.food.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
        currencyCode: 'RUB',
        exchangeRate: 1.0,
        baseAmount: 500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: CategoryGroupWidget(
              category: Category.food,
              transactions: [rubTx],
              onTransactionTap: (_) {},
              onTransactionDelete: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Питание'), findsOneWidget);
      expect(find.text('1 операция'), findsOneWidget);
      expect(find.text('-500,00 ₽'), findsOneWidget);
      // Нет подстроки иностранной валюты
      expect(find.text('-500 сум'), findsNothing);
    });
  });

  group('CurrencyPickerSheet Isolation Tests', () {
    testWidgets(
        'CurrencyPickerSheet с updateGlobalCurrency: false не меняет глобальную валюту аккаунта',
        (WidgetTester tester) async {
      CurrencyFormatter.setCurrency(Currency.rub);
      expect(CurrencyFormatter.currentCurrency, equals(Currency.rub));

      Currency? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await CurrencyPickerSheet.show(
                    context,
                    selectedCurrency: Currency.rub,
                    updateGlobalCurrency: false,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Выбираем Узбекский сум
      await tester.tap(find.text('Узбекский сум'));
      await tester.pumpAndSettle();

      // Проверяем, что результат возвращен
      expect(selected, equals(Currency.uzs));
      // Глобальная валюта осталась RUB!
      expect(CurrencyFormatter.currentCurrency, equals(Currency.rub));
    });

    testWidgets(
        'CurrencyPickerSheet по умолчанию (для профиля) обновляет глобальную валюту аккаунта',
        (WidgetTester tester) async {
      CurrencyFormatter.setCurrency(Currency.rub);
      expect(CurrencyFormatter.currentCurrency, equals(Currency.rub));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CurrencyPickerSheet.show(context),
                child: const Text('Open Profile Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Profile Picker'));
      await tester.pumpAndSettle();

      // Выбираем Казахстанский тенге
      await tester.tap(find.text('Казахстанский тенге'));
      await tester.pumpAndSettle();

      // Глобальная валюта переключилась на KZT
      expect(CurrencyFormatter.currentCurrency, equals(Currency.kzt));
    });
  });

  group('Recalculation on Base Currency Change Tests', () {
    test(
        'При смене базовой валюты с RUB на UZS транзакция в KZT пересчитывается корректно',
        () async {
      await LocalDbService.instance.clearAllData();
      await CurrencyFormatter.setCurrency(Currency.rub);

      // Добавляем транзакцию в 1 000 000 тенге (KZT) при базовой валюте RUB
      const kztAmount = 1000000.0;
      final rateKztToRub = CurrencyExchangeService.instance
          .getRate(from: Currency.kzt, to: Currency.rub);
      final baseInRub = CurrencyExchangeService.instance
          .convert(kztAmount, from: Currency.kzt, to: Currency.rub);

      final tx = Transaction(
        amount: kztAmount,
        currencyCode: 'KZT',
        exchangeRate: rateKztToRub,
        baseAmount: baseInRub,
        description: 'Покупка в Алматы',
        dbCategory: Category.shopping.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      );

      LocalDbService.instance.saveTransaction(tx);

      // В базе сумма в RUB (~180-210 тыс. руб)
      final totalsBefore = LocalDbService.instance
          .getMonthTotals(DateTime.now().month, DateTime.now().year);
      expect(totalsBefore['expense']!, closeTo(baseInRub, 0.01));

      // Сменяем базовую валюту аккаунта на UZS (сум)
      await CurrencyFormatter.setCurrency(Currency.uzs);

      // Итоги месяца динамически пересчитываются в UZS (~25-27 млн сум, а НЕ остаются 189 тыс!)
      final expectedBaseInUzs = CurrencyExchangeService.instance
          .convert(kztAmount, from: Currency.kzt, to: Currency.uzs);
      final totalsAfter = LocalDbService.instance
          .getMonthTotals(DateTime.now().month, DateTime.now().year);

      expect(totalsAfter['expense']!, greaterThan(20000000.0));
      expect(totalsAfter['expense']!, closeTo(expectedBaseInUzs, 0.01));

      final savedTxs = LocalDbService.instance.getAllTransactions();
      expect(savedTxs.first.currencyCode, equals('KZT'));
      expect(savedTxs.first.amount, equals(1000000.0));
      // В базе историческая запись НЕ мутируется (isModified остается false, sync не засоряется),
      // а effectiveBaseAmount динамически возвращает сумму в текущей валюте UZS:
      expect(
          savedTxs.first.effectiveBaseAmount, closeTo(expectedBaseInUzs, 0.01));
      expect(savedTxs.first.isModified, isFalse);
    });
  });
}
