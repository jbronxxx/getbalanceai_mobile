import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
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
    await ApiService.instance.setTokens(null, null);
    LanguageManager.initFallback();
    await CurrencyFormatter.loadSavedCurrency();
    await CurrencyExchangeService.instance.init();
  });

  group('CurrencyExchangeService Tests', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiService.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
    });

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

    test(
        'Приоритетная загрузка актуальных курсов с собственного бэкенда /currencies/rates',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path.contains('/currencies/rates')) {
          return ResponseBody.fromString(
            jsonEncode({
              'status': 'success',
              'data': {
                'base': 'USD',
                'rates': {
                  'USD': 1.0,
                  'EUR': 0.90,
                  'RUB': 100.0,
                  'UZS': 13000.0,
                  'KZT': 500.0,
                },
                'updated_at': '2026-10-11T19:00:00Z',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw DioException(
          requestOptions: options,
          error: 'External gateway should not be called when backend succeeds',
        );
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isTrue);
      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(100.0));
      expect(service.getRate(from: Currency.usd, to: Currency.uzs),
          equals(13000.0));

      final cached = await PreferencesService.instance.getExchangeRates();
      expect(cached, isNotNull);
      expect(cached, contains('100'));
    });

    test(
        'Graceful Fallback на открытый шлюз open.er-api.com при ошибке бэкенда',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path.contains('/currencies/rates')) {
          return ResponseBody.fromString('Service Unavailable', 503);
        }
        if (options.path.contains('open.er-api.com')) {
          return ResponseBody.fromString(
            jsonEncode({
              'result': 'success',
              'rates': {
                'USD': 1.0,
                'EUR': 0.93,
                'RUB': 98.5,
                'UZS': 12950.0,
                'KZT': 498.0,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw DioException(requestOptions: options);
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isTrue);
      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(98.5));
    });

    test(
        'При полной недоступности сети fetchLatestRates возвращает false и сохраняет оффлайн-курсы',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'No Internet',
        );
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isFalse);
      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(96.0));
    });

    test(
        'E2/A4: Невалидные котировки (0, -1, "abc") игнорируются, сохраняются предыдущие значения',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();
      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(96.0));

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {
              'base': 'USD',
              'rates': {
                'RUB': 0,
                'UZS': -100.0,
                'EUR': 'invalid_string',
                'KZT': 500.0,
              },
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isTrue);

      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(96.0));
      expect(service.getRate(from: Currency.usd, to: Currency.uzs),
          equals(12800.0));
      expect(
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));
      expect(
          service.getRate(from: Currency.usd, to: Currency.kzt), equals(500.0));
      expect(service.getRate(from: Currency.uzs, to: Currency.usd),
          closeTo(1 / 12800.0, 0.0001));
    });

    test(
        'A8: isOutdated возвращает true если lastUpdated null или старше 24 часов',
        () {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();
      expect(service.lastUpdated, isNull);
      expect(service.isOutdated, isTrue);
      expect(service.isApproximate, isTrue);
    });

    test(
        'B1: Аномальный скачок курса (>2x от baseline) с открытого шлюза игнорируется',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path.contains('/currencies/rates')) {
          return ResponseBody.fromString('Not Found', 404);
        }
        if (options.path.contains('open.er-api.com')) {
          return ResponseBody.fromString(
            jsonEncode({
              'result': 'success',
              'rates': {
                'USD': 1.0,
                'EUR': 0.93,
                'RUB': 250.0,
                'UZS': 1000.0,
                'KZT': 498.0,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw DioException(requestOptions: options);
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isTrue);

      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(96.0));
      expect(service.getRate(from: Currency.usd, to: Currency.uzs),
          equals(12800.0));
      expect(
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.93));
      expect(
          service.getRate(from: Currency.usd, to: Currency.kzt), equals(498.0));
    });

    test('B1: Аномальный скачок курсов всех валют отклоняет всё обновление',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path.contains('/currencies/rates')) {
          return ResponseBody.fromString('Server Error', 500);
        }
        if (options.path.contains('open.er-api.com')) {
          return ResponseBody.fromString(
            jsonEncode({
              'result': 'success',
              'rates': {
                'USD': 10.0,
                'EUR': 5.0,
                'RUB': 300.0,
                'UZS': 100.0,
                'KZT': 2000.0,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw DioException(requestOptions: options);
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isFalse);

      expect(
          service.getRate(from: Currency.usd, to: Currency.rub), equals(96.0));
      expect(service.getRate(from: Currency.usd, to: Currency.uzs),
          equals(12800.0));
      expect(
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));
      expect(service.lastUpdated, isNull);
    });

    test(
        'B2: Запрос к открытому шлюзу open.er-api.com не отправляет заголовок Authorization при активной сессии',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      await ApiService.instance
          .setTokens('secret_jwt_access_token', 'refresh_token');
      expect(ApiService.instance.isAuthenticated, isTrue);

      Map<String, dynamic>? externalGatewayHeaders;

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path.contains('/currencies/rates')) {
          return ResponseBody.fromString('Backend Offline', 503);
        }
        if (options.path.contains('open.er-api.com')) {
          externalGatewayHeaders = options.headers;
          return ResponseBody.fromString(
            jsonEncode({
              'result': 'success',
              'rates': {
                'USD': 1.0,
                'EUR': 0.92,
                'RUB': 96.0,
                'UZS': 12800.0,
                'KZT': 495.0,
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw DioException(requestOptions: options);
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isTrue);
      expect(externalGatewayHeaders, isNotNull);

      expect(externalGatewayHeaders!.containsKey('Authorization'), isFalse);
      expect(externalGatewayHeaders!.containsKey('X-Request-ID'), isTrue);
    });

    test(
        'B2: Ошибка 401 на внешнем шлюзе не вызывает обновление токенов бэкенда',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      await ApiService.instance.setTokens('valid_token', 'valid_refresh');
      var refreshAttempted = false;

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.path.contains('/currencies/rates')) {
          return ResponseBody.fromString('Backend 503', 503);
        }
        if (options.path.contains('/auth/refresh')) {
          refreshAttempted = true;
          return ResponseBody.fromString(
            jsonEncode({
              'status': 'success',
              'data': {
                'access_token': 'new_token',
                'refresh_token': 'new_refresh',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        if (options.path.contains('open.er-api.com')) {
          return ResponseBody.fromString('Unauthorized external', 401);
        }
        throw DioException(requestOptions: options);
      });

      final success = await service.fetchLatestRates(force: true);
      expect(success, isFalse);
      expect(refreshAttempted, isFalse);
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

    testWidgets(
        'При завершении онбординга авторизованный пользователь отправляет валюту на бэкенд',
        (WidgetTester tester) async {
      await ApiService.instance.setTokens('test_token', 'test_refresh');
      expect(ApiService.instance.isAuthenticated, isTrue);

      final originalAdapter = ApiService.instance.dio.httpClientAdapter;
      addTearDown(() async {
        await ApiService.instance.setTokens(null, null);
        ApiService.instance.dio.httpClientAdapter = originalAdapter;
      });

      bool profilePatched = false;
      ApiService.instance.dio.httpClientAdapter =
          _MockHttpClientAdapter((options) async {
        if (options.method == 'PATCH' && options.path.contains('/auth/me')) {
          profilePatched = true;
          return ResponseBody.fromString(
            jsonEncode({'status': 'success', 'data': {}}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      });

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('ru'),
          home: WelcomeSetupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Шаг 1 -> продолжить
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      // Шаг 2 -> нажимаем продолжить (завершить онбординг)
      final finishBtn = find.text('Продолжить');
      expect(finishBtn, findsOneWidget);
      await tester.tap(finishBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(profilePatched, isTrue);
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

  group('AuthApiService Base Currency Update & ETag Invalidation Tests', () {
    late FlutterSecureStorage storage;
    late Dio testDio;
    late AuthApiService authService;

    setUp(() async {
      storage = const FlutterSecureStorage();
      await storage.deleteAll();
      testDio = Dio(BaseOptions(baseUrl: 'http://localhost:8000/api/v1'));
      authService = AuthApiService(dio: testDio, storage: storage);
      await authService.setTokens('fake_access_token', 'fake_refresh_token');
    });

    test(
        'Сброс ETag transactions_etag и budgets_etag при updateUserProfile(baseCurrency: ...)',
        () async {
      await storage.write(key: 'transactions_etag', value: 'etag-tx-initial');
      await storage.write(key: 'budgets_etag', value: 'etag-b-initial');

      expect(await storage.read(key: 'transactions_etag'),
          equals('etag-tx-initial'));
      expect(await storage.read(key: 'budgets_etag'), equals('etag-b-initial'));

      bool patchCalled = false;
      testDio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        if (options.method == 'PATCH' && options.path.contains('/auth/me')) {
          patchCalled = true;
          return ResponseBody.fromString(
            jsonEncode({
              'status': 'success',
              'data': {
                'id': 'user-1',
                'name': 'Test User',
                'email': 'test@example.com',
                'base_currency': 'UZS',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('{}', 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      });

      await authService.updateUserProfile(baseCurrency: 'UZS');

      expect(patchCalled, isTrue);
      expect(await storage.read(key: 'transactions_etag'), isNull);
      expect(await storage.read(key: 'budgets_etag'), isNull);
    });

    test('При updateUserProfile без baseCurrency ETag не сбрасываются',
        () async {
      await storage.write(key: 'transactions_etag', value: 'etag-tx-keep');
      await storage.write(key: 'budgets_etag', value: 'etag-b-keep');

      testDio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {'name': 'New Name'},
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      await authService.updateUserProfile(name: 'New Name');

      expect(
          await storage.read(key: 'transactions_etag'), equals('etag-tx-keep'));
      expect(await storage.read(key: 'budgets_etag'), equals('etag-b-keep'));
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) _handler;
  _MockHttpClientAdapter(this._handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);

  @override
  void close({bool force = false}) {}
}
