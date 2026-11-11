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
    await ApiService.instance.auth.setTokens(null, null);
    // Тексты в проверках — русские; язык по умолчанию — английский
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
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
          service.getRate(from: Currency.usd, to: Currency.usd), equals(1.0));
      expect(
        service.convert(1500, from: Currency.usd, to: Currency.usd),
        equals(1500.0),
      );
    });

    test('Корректный расчет кросс-курса EUR к USD и USD к EUR', () {
      final service = CurrencyExchangeService.instance;
      final eurToUsd = service.getRate(from: Currency.eur, to: Currency.usd);
      final usdToEur = service.getRate(from: Currency.usd, to: Currency.eur);

      expect(eurToUsd, greaterThan(0.0));
      expect(usdToEur, greaterThan(0.0));
      // Произведение кросс-курсов должно быть близко к 1.0
      expect((eurToUsd * usdToEur - 1.0).abs(), lessThan(0.001));

      // 1 000 € в долларах — разумная сумма
      final convertedUsd =
          service.convert(1000, from: Currency.eur, to: Currency.usd);
      expect(convertedUsd, greaterThan(900));
      expect(convertedUsd, lessThan(1300));
    });

    test('Форматирование текстового описания курса', () {
      final service = CurrencyExchangeService.instance;
      final desc =
          service.formatRateDescription(from: Currency.eur, to: Currency.usd);
      expect(desc, contains('€'));
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
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.90));

      final cached = await PreferencesService.instance.getExchangeRates();
      expect(cached, isNotNull);
      expect(cached, contains('0.9'));
    });

    test('LOGIC-08: новые курсы сразу уведомляют экраны, сбой — нет', () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();
      var notified = 0;
      void listener() => notified++;
      CurrencyFormatter.currencyNotifier.addListener(listener);
      addTearDown(
          () => CurrencyFormatter.currencyNotifier.removeListener(listener));

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        throw DioException(requestOptions: options, error: 'offline');
      });
      expect(await service.fetchLatestRates(force: true), isFalse);
      expect(notified, 0);

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'data': {
              'rates': {'USD': 1.0, 'EUR': 0.9},
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      expect(await service.fetchLatestRates(force: true), isTrue);
      expect(notified, 1);
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
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.93));
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
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));
    });

    test(
        'E2/A4: Невалидные котировки (0, -1, "abc") игнорируются, сохраняются предыдущие значения',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();
      expect(
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));

      service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {
              'base': 'USD',
              'rates': {
                'USD': 1.0,
                'EUR': 'invalid_string',
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
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));

      for (final bad in [0.0, -1.0]) {
        service.dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({
              'status': 'success',
              'data': {
                'base': 'USD',
                'rates': {'USD': 1.0, 'EUR': bad},
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
        expect(await service.fetchLatestRates(force: true), isTrue);
        expect(
            service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92),
            reason: '$bad');
      }
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
                'EUR': 0.3,
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

      // Скачок EUR отброшен, USD (в пределах нормы) принят
      expect(
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));
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
          service.getRate(from: Currency.usd, to: Currency.eur), equals(0.92));
      expect(service.lastUpdated, isNull);
    });

    test(
        'B2: Запрос к открытому шлюзу open.er-api.com не отправляет заголовок Authorization при активной сессии',
        () async {
      final service = CurrencyExchangeService.instance;
      service.resetForTesting();

      await ApiService.instance.auth
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

      await ApiService.instance.auth.setTokens('valid_token', 'valid_refresh');
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

  group('Transaction Multi-Currency Serialization', () {
    test('Transaction корректно парсит данные с полями валюты', () {
      final json = {
        'id': 'tx-123',
        'amount': 92.0,
        'currency': 'EUR',
        'exchange_rate': 1 / 0.92,
        'base_amount': 100.0,
        'description': 'Кафе в Париже',
        'category': 'food',
        'type': 'expense',
        'date': '2026-10-11T12:00:00Z',
      };

      final tx = Transaction.fromJson(json);
      expect(tx.amount, equals(92.0));
      expect(tx.currencyCode, equals('EUR'));
      expect(tx.currency, equals(Currency.eur));
      expect(tx.exchangeRate, equals(1 / 0.92));
      expect(tx.baseAmount, equals(100.0));
      expect(tx.effectiveBaseAmount, closeTo(100.0, 0.000001));

      final serialized = tx.toJson();
      expect(serialized['currency'], equals('EUR'));
      expect(serialized['exchange_rate'], equals(1 / 0.92));
      expect(serialized['base_amount'], equals(100.0));
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
  });

  group('CurrencyFormatter Multi-Currency Tests', () {
    test('Форматирование суммы с указанием конкретной валюты', () {
      final formattedEur =
          CurrencyFormatter.format(150000, currency: Currency.eur);
      expect(formattedEur, contains('150 000'));
      expect(formattedEur, contains('€'));

      final formattedUsd =
          CurrencyFormatter.format(25.5, currency: Currency.usd);
      expect(formattedUsd, contains(r'$'));
      expect(formattedUsd, contains('25,50'));
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
      expect(find.text('Выберите язык'), findsOneWidget);
      expect(find.text('Для комфортной работы с приложением'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('O\'zbekcha'), findsNothing);
      expect(find.text('Қазақша'), findsNothing);

      // Нажимаем продолжить для перехода на шаг 2
      await tester.tap(find.text('Продолжить'));
      await tester.pumpAndSettle();

      // Шаг 2: отображается выбор валюты словами
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Основная валюта'), findsOneWidget);
      expect(
        find.text('В этой валюте рассчитывается общий баланс и бюджеты'),
        findsOneWidget,
      );
      expect(find.text('Доллар США'), findsOneWidget);
      expect(find.text('Евро'), findsOneWidget);

      // Проверяем возврат на шаг 1 по кнопке назад
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Русский'), findsOneWidget);
    });

    testWidgets(
        'При завершении онбординга авторизованный пользователь отправляет валюту на бэкенд',
        (WidgetTester tester) async {
      await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
      expect(ApiService.instance.isAuthenticated, isTrue);

      final originalAdapter = ApiService.instance.dio.httpClientAdapter;
      addTearDown(() async {
        await ApiService.instance.auth.setTokens(null, null);
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

  group('operations_count: склонение числа операций', () {
    test('Русская грамматика для количества операций', () {
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      expect(LanguageManager.l10n.operations_count(1), equals('1 операция'));
      expect(LanguageManager.l10n.operations_count(2), equals('2 операции'));
      expect(LanguageManager.l10n.operations_count(4), equals('4 операции'));
      expect(LanguageManager.l10n.operations_count(5), equals('5 операций'));
      expect(LanguageManager.l10n.operations_count(11), equals('11 операций'));
      expect(LanguageManager.l10n.operations_count(14), equals('14 операций'));
      expect(LanguageManager.l10n.operations_count(21), equals('21 операция'));
      expect(LanguageManager.l10n.operations_count(22), equals('22 операции'));
      expect(LanguageManager.l10n.operations_count(25), equals('25 операций'));
    });

    test('Английский язык для количества операций', () {
      LanguageManager.setLanguage(AppLanguage.en, save: false);
      expect(LanguageManager.l10n.operations_count(1), equals('1 transaction'));
      expect(
          LanguageManager.l10n.operations_count(5), equals('5 transactions'));
    });
  });

  group('DayGroupWidget: лента операций дня', () {
    /// Как сумма выглядит на экране: formatText ставит типографский минус.
    String onScreen(String formatted) =>
        formatted.replaceAll('-', CurrencyFormatter.typographicMinus);

    Transaction tx({
      required int id,
      required double amount,
      required String type,
      String description = '',
      Category category = Category.food,
      String currencyCode = 'USD',
      double exchangeRate = 1.0,
      double? baseAmount,
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return Transaction(
        localId: id,
        amount: amount,
        description: description,
        dbCategory: category.name,
        dbType: type,
        dateMilliseconds: now,
        dateCreatedMilliseconds: now,
        currencyCode: currencyCode,
        exchangeRate: exchangeRate,
        baseAmount: baseAmount ?? amount,
      );
    }

    Future<void> pumpDay(WidgetTester tester, List<Transaction> items) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayGroupWidget(
                date: DateTime.now(),
                transactions: items,
                onTransactionTap: (_) {},
                onTransactionDelete: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() {
      LanguageManager.setLanguage(AppLanguage.ru, save: false);
      CurrencyFormatter.setCurrency(Currency.usd);
    });

    testWidgets(
        'Операция в иностранной валюте: описание, категория, сумма чека и пересчёт',
        (tester) async {
      final foreignTx = tx(
        id: 1,
        amount: 1000,
        type: TransactionType.expense.name,
        description: 'Кинотеатр',
        category: Category.entertainment,
        currencyCode: 'EUR',
        exchangeRate: 1 / 0.92,
        baseAmount: 1086.96,
      );

      await pumpDay(tester, [foreignTx]);

      expect(find.text('Кинотеатр'), findsOneWidget);
      expect(find.text('Развлечения'), findsOneWidget);
      expect(find.text(onScreen('-€1 000,00')), findsOneWidget);
      final baseText = onScreen(CurrencyFormatter.format(
        -foreignTx.effectiveBaseAmount,
        showSign: true,
      ));
      expect(
          find.text(
              '≈ ${onScreen(CurrencyFormatter.format(-foreignTx.effectiveBaseAmount))}'),
          findsOneWidget);
      // Итог дня — в базовой валюте
      expect(find.text(baseText), findsOneWidget);
      // Групп по категориям больше нет
      expect(find.text('1 операция'), findsNothing);
    });

    testWidgets('Итог дня: доходы минус расходы в базовой валюте',
        (tester) async {
      await pumpDay(tester, [
        tx(id: 1, amount: 100, type: TransactionType.income.name),
        tx(id: 2, amount: 30, type: TransactionType.expense.name),
      ]);

      expect(find.text(CurrencyFormatter.format(70, showSign: true)),
          findsOneWidget);
      expect(find.byType(TransactionItemTile), findsNWidgets(2));
    });

    testWidgets(
        'Без описания заголовком строки служит название категории, подписи нет',
        (tester) async {
      await pumpDay(tester, [
        tx(id: 1, amount: 50, type: TransactionType.expense.name),
      ]);

      expect(find.text('Питание'), findsOneWidget);
      expect(find.text(LanguageManager.l10n.no_description), findsNothing);
      expect(find.text(onScreen(r'-$50,00')), findsNWidgets(2));
      expect(find.textContaining('-'), findsNothing);
    });
  });

  group('CurrencyPickerSheet Isolation Tests', () {
    testWidgets(
        'CurrencyPickerSheet с updateGlobalCurrency: false не меняет глобальную валюту аккаунта',
        (WidgetTester tester) async {
      CurrencyFormatter.setCurrency(Currency.usd);
      expect(CurrencyFormatter.currentCurrency, equals(Currency.usd));

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
                    selectedCurrency: Currency.usd,
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

      // Выбираем евро
      await tester.tap(find.text('Евро'));
      await tester.pumpAndSettle();

      // Проверяем, что результат возвращен
      expect(selected, equals(Currency.eur));
      // Глобальная валюта осталась USD!
      expect(CurrencyFormatter.currentCurrency, equals(Currency.usd));
    });

    testWidgets(
        'CurrencyPickerSheet по умолчанию (для профиля) обновляет глобальную валюту аккаунта',
        (WidgetTester tester) async {
      CurrencyFormatter.setCurrency(Currency.usd);
      expect(CurrencyFormatter.currentCurrency, equals(Currency.usd));

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

      // Выбираем евро
      await tester.tap(find.text('Евро'));
      await tester.pumpAndSettle();

      // Глобальная валюта переключилась на EUR
      expect(CurrencyFormatter.currentCurrency, equals(Currency.eur));
      await CurrencyFormatter.setCurrency(Currency.usd);
    });
  });

  group('Recalculation on Base Currency Change Tests', () {
    test(
        'При смене базовой валюты с USD на EUR транзакция в EUR пересчитывается корректно',
        () async {
      await LocalDbService.instance.clearAllData();
      await CurrencyFormatter.setCurrency(Currency.usd);

      // Транзакция на 1 000 € при базовой валюте USD
      const eurAmount = 1000.0;
      final rateEurToUsd = CurrencyExchangeService.instance
          .getRate(from: Currency.eur, to: Currency.usd);
      final baseInUsd = CurrencyExchangeService.instance
          .convert(eurAmount, from: Currency.eur, to: Currency.usd);

      final tx = Transaction(
        amount: eurAmount,
        currencyCode: 'EUR',
        exchangeRate: rateEurToUsd,
        baseAmount: baseInUsd,
        description: 'Покупка в Берлине',
        dbCategory: Category.shopping.name,
        dbType: TransactionType.expense.name,
        dateMilliseconds: DateTime.now().millisecondsSinceEpoch,
        dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      );

      LocalDbService.instance.saveTransaction(tx);

      final totalsBefore = LocalDbService.instance
          .getMonthTotals(DateTime.now().month, DateTime.now().year);
      expect(totalsBefore['expense']!, closeTo(baseInUsd, 0.01));

      // Сменяем базовую валюту аккаунта на EUR
      await CurrencyFormatter.setCurrency(Currency.eur);

      // Итоги месяца пересчитываются в EUR, а не остаются в USD
      final totalsAfter = LocalDbService.instance
          .getMonthTotals(DateTime.now().month, DateTime.now().year);
      expect(totalsAfter['expense']!, closeTo(eurAmount, 0.01));

      final savedTxs = LocalDbService.instance.getAllTransactions();
      expect(savedTxs.first.currencyCode, equals('EUR'));
      expect(savedTxs.first.amount, equals(1000.0));
      // В базе историческая запись НЕ мутируется (isModified остается false, sync не засоряется),
      // а effectiveBaseAmount динамически возвращает сумму в текущей валюте EUR:
      expect(savedTxs.first.effectiveBaseAmount, closeTo(eurAmount, 0.01));
      expect(savedTxs.first.isModified, isFalse);
      await CurrencyFormatter.setCurrency(Currency.usd);
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
                'base_currency': 'EUR',
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

      await authService.updateUserProfile(baseCurrency: 'EUR');

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
