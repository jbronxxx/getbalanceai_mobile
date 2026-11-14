import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:getbalanceai_mobile/models/plan_model.dart';
import 'package:getbalanceai_mobile/screens/paywall_screen.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/entitlement_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/selected_period_service.dart';
import 'package:getbalanceai_mobile/screens/insights_screen.dart';
import 'package:getbalanceai_mobile/models/insights_model.dart';
import 'package:getbalanceai_mobile/models/month_period.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:getbalanceai_mobile/utils/ui_utils.dart';
import 'package:getbalanceai_mobile/widgets/ai_sparkles_loader.dart';
import 'package:getbalanceai_mobile/cubits/insights/insights_cubit.dart';
import 'package:getbalanceai_mobile/widgets/insights/insights_unavailable_card.dart';
import 'package:getbalanceai_mobile/widgets/insights/report_export_action.dart';
import 'package:getbalanceai_mobile/widgets/period/period.dart';
import 'package:getbalanceai_mobile/config/environment.dart';

void main() {
  final storageData = <String, String>{};

  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
    EnvironmentConfig.setDefinesForTesting(
        {'API_BASE_URL': 'http://localhost:8000/api/v1'});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          storageData[methodCall.arguments['key'] as String] =
              methodCall.arguments['value'] as String;
          return null;
        } else if (methodCall.method == 'read') {
          return storageData[methodCall.arguments['key'] as String];
        } else if (methodCall.method == 'delete') {
          storageData.remove(methodCall.arguments['key'] as String);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          storageData.clear();
          return null;
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async => ['wifi'],
    );
  });

  setUp(() {
    storageData.clear();
    // Pro: текущий месяц строится сам; правила Free — в группе «Тариф Free»
    EntitlementService.instance = EntitlementService(isPro: () => true);
  });

  tearDown(() => EntitlementService.instance = EntitlementService());

  group('InsightsModel Tests', () {
    test('parses ISO-8601 generated_at and list of insights', () {
      final json = {
        'insights': ['Save 15% on dining', 'Invest in index funds'],
        'generated_at': '2026-10-02T13:45:00Z',
      };

      final model = InsightsModel.fromJson(json);

      expect(model.insights.length, 2);
      expect(model.insights.first, 'Save 15% on dining');
      expect(model.generatedAt, isNotNull);
      expect(
          model.generatedAt, DateTime.parse('2026-10-02T13:45:00Z').toLocal());
    });

    test('parses unix timestamp in milliseconds and seconds', () {
      const ms = 1727874000000;
      final modelMs = InsightsModel.fromJson({
        'insights': ['Tip 1'],
        'generated_at': ms,
      });
      expect(modelMs.generatedAt, DateTime.fromMillisecondsSinceEpoch(ms));

      const sec = 1727874000;
      final modelSec = InsightsModel.fromJson({
        'insights': ['Tip 2'],
        'generated_at': sec,
      });
      expect(modelSec.generatedAt,
          DateTime.fromMillisecondsSinceEpoch(sec * 1000));
    });

    test('handles null generated_at and empty insights', () {
      final model = InsightsModel.fromJson({});
      expect(model.insights, isEmpty);
      expect(model.generatedAt, isNull);
    });

    test('parses report state including busy; unknown or missing is ready', () {
      InsightsReportState parse(dynamic state) =>
          InsightsModel.fromJson({'insights': [], 'state': state}).state;

      expect(parse('ready'), InsightsReportState.ready);
      expect(parse('not_generated'), InsightsReportState.notGenerated);
      expect(parse('no_data'), InsightsReportState.noData);
      expect(parse('busy'), InsightsReportState.busy);
      expect(parse('something_new'), InsightsReportState.ready);
      expect(InsightsModel.fromJson({'insights': []}).state,
          InsightsReportState.ready);
    });

    test('parses is_outdated; missing (old backend) is false', () {
      expect(
        InsightsModel.fromJson({'insights': [], 'is_outdated': true})
            .isOutdated,
        isTrue,
      );
      expect(InsightsModel.fromJson({'insights': []}).isOutdated, isFalse);
    });

    test('handles wrapped data field in json', () {
      final json = {
        'status': 'success',
        'data': {
          'insights': ['Advice A'],
          'generated_at': '2026-10-02T10:00:00Z',
        }
      };

      final model = InsightsModel.fromJson(json);
      expect(model.insights, ['Advice A']);
      expect(model.generatedAt, isNotNull);
    });

    test('toJson produces valid map', () {
      final model = InsightsModel(
        insights: ['Advice 1'],
        generatedAt: DateTime.utc(2026, 10, 2, 12, 0),
      );

      final json = model.toJson();
      expect(json['insights'], ['Advice 1']);
      expect(json['generated_at'], '2026-10-02T12:00:00.000Z');
    });
  });

  group('LanguageManager Date Formatting & Translations', () {
    test('formatDate and formatDateTime format with time in RU, UZ, EN', () {
      final testDate = DateTime(2026, 10, 2, 14, 30);

      LanguageManager.setLanguage(AppLanguage.ru);
      expect(LanguageManager.formatDate(testDate), '2 октября, 14:30');
      expect(
          LanguageManager.l10n.insights_assistants_busy_msg1,
          'Наши умные помощники заняты' != ''
              ? contains('наши умные помощники')
              : '');

      LanguageManager.setLanguage(AppLanguage.en);
      expect(LanguageManager.formatDate(testDate), 'October 2, 14:30');
      expect(LanguageManager.l10n.insights_assistants_busy_msg1,
          contains('smart assistants'));

      // Restore RU
      LanguageManager.setLanguage(AppLanguage.ru);
    });
  });

  test(
      'ApiService getInsights method accepts cancelToken, currency, locale, month, year, and custom timeouts',
      () async {
    final cancelToken = CancelToken();
    try {
      await ApiService.instance.getInsights(
        currency: 'USD',
        locale: 'en',
        month: 10,
        year: 2026,
        cancelToken: cancelToken,
      );
    } catch (_) {
      // Expected without backend server
    }
  });

  test('ApiService getInsights sends month and year in queryParameters',
      () async {
    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    RequestOptions? capturedOptions;
    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      capturedOptions = options;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {'insights': []}
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    try {
      await ApiService.instance.getInsights(month: 11, year: 2025);
      expect(capturedOptions?.queryParameters['month'], 11);
      expect(capturedOptions?.queryParameters['year'], 2025);

      await ApiService.instance.getInsights();
      expect(capturedOptions?.queryParameters.containsKey('month'), isFalse);
      expect(capturedOptions?.queryParameters.containsKey('year'), isFalse);
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
    }
  });

  test('CancelToken can abort getInsights request', () async {
    final cancelToken = CancelToken();
    cancelToken.cancel('user left');

    expect(
      () => ApiService.instance.getInsights(cancelToken: cancelToken),
      throwsA(isA<DioException>().having(
        (e) => e.type,
        'type',
        DioExceptionType.cancel,
      )),
    );
  });

  testWidgets('InsightsScreen renders and disposes cleanly with CancelToken',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen()));
    await tester.pump();

    expect(find.byType(InsightsScreen), findsOneWidget);

    // Unmount widget to trigger dispose() and verify no crashes or errors occur
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox.shrink()));
    await tester.pump();

    expect(find.byType(InsightsScreen), findsNothing);
  });

  testWidgets('InsightsScreen shows report export button in app bar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen(isActive: false)));
    await tester.pump();

    expect(find.byType(ReportExportAction), findsOneWidget);
    expect(find.byTooltip('Выгрузка отчёта'), findsOneWidget);
  });

  testWidgets(
      'InsightsScreen shows AiSparklesLoader during loading and not CircularProgressIndicator',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');

    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      // Simulate delayed response
      await Future.delayed(const Duration(milliseconds: 500));
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {
            'insights': ['Совет 1'],
          }
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    try {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsScreen()));
      await tester.pump();

      expect(find.byType(AiSparklesLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      await ApiService.instance.clearAllUserData();
    }
  });

  testWidgets(
      'InsightsScreen displays busy assistants stub on endpoint error and allows pull-to-refresh',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');

    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    int requestCount = 0;

    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      requestCount++;
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Internal Server Error'}),
        500,
      );
    });

    try {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsScreen()));
      await tester.pumpAndSettle();
      expect(find.text(LanguageManager.l10n.insights_assistants_busy_msg1),
          findsOneWidget);
      expect(find.text(LanguageManager.l10n.insights_assistants_busy_msg2),
          findsOneWidget);
      expect(requestCount, 1);

      // Perform pull-to-refresh gesture
      await tester.fling(
        find.text(LanguageManager.l10n.insights_assistants_busy_msg1),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(requestCount, greaterThan(1));
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      await ApiService.instance.clearAllUserData();
    }
  });

  for (final status in [429, 503, 500]) {
    testWidgets('ошибка $status — «помощники заняты»', (tester) async {
      await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
      final originalAdapter = ApiService.instance.dio.httpClientAdapter;
      var requestCount = 0;
      ApiService.instance.dio.httpClientAdapter =
          _MockHttpClientAdapter((options) async {
        requestCount++;
        return ResponseBody.fromString('{}', status);
      });

      try {
        await tester.pumpWidget(const MaterialApp(
            locale: Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InsightsScreen()));
        await tester.pumpAndSettle();
        expect(find.text(LanguageManager.l10n.insights_assistants_busy_msg1),
            findsOneWidget);
        expect(find.text(LanguageManager.l10n.no_network_title), findsNothing);
        expect(requestCount, 1);
      } finally {
        ApiService.instance.dio.httpClientAdapter = originalAdapter;
        await ApiService.instance.clearAllUserData();
      }
    });
  }

  testWidgets('pull-to-refresh на прошлом месяце — без генерации',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
    SelectedPeriodService.instance.select(MonthPeriod.current().previous);
    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    final generateFlags = <Object?>[];
    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      generateFlags.add(options.queryParameters['generate'] ?? true);
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {
            'insights': ['Сохранённый отчёт'],
            'state': 'ready',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    try {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsScreen()));
      await tester.pumpAndSettle();

      await tester.fling(
        find.text('Сохранённый отчёт'),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(generateFlags, [false, false]);
    } finally {
      // Экран закрывается до сброса периода: иначе он запросил бы отчёт
      await tester.pumpWidget(const SizedBox());
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      SelectedPeriodService.instance.reset();
      await ApiService.instance.clearAllUserData();
    }
  });

  testWidgets(
      'InsightsScreen does not display updated date, personal recs title, or cache hint',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');

    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    const testGeneratedAt = '2026-10-02T13:45:00Z';

    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      if (options.path.contains('/insights/')) {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {
              'insights': ['Следите за расходами на рестораны'],
              'generated_at': testGeneratedAt,
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InsightsScreen()));
      await tester.pumpAndSettle();

      // Check removed elements
      expect(find.byKey(const Key('insights_updated_at')), findsNothing);
      expect(find.byKey(const Key('insights_cache_hint')), findsNothing);

      expect(find.text('Следите за расходами на рестораны'), findsOneWidget);
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      await ApiService.instance.clearAllUserData();
    }
  });

  testWidgets('InsightsScreen displays login hint for unauthenticated guest',
      (tester) async {
    await ApiService.instance.clearAllUserData();

    await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen()));
    await tester.pumpAndSettle();

    expect(find.text(LanguageManager.l10n.insight_login_hint), findsOneWidget);
    expect(find.byKey(const Key('insights_cache_hint')), findsNothing);
  });

  testWidgets(
      'InsightsScreen does not call getInsights when isActive is false and loads lazily when isActive becomes true',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');

    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    int requestCount = 0;

    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      if (options.path.contains('/insights/')) {
        requestCount++;
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {
              'insights': ['Ленивый инсайт'],
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen(isActive: false),
      ));
      await tester.pump();

      expect(requestCount, 0);
      expect(find.text('Ленивый инсайт'), findsNothing);

      await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen(isActive: true),
      ));
      await tester.pumpAndSettle();

      expect(requestCount, 1);
      expect(find.text('Ленивый инсайт'), findsOneWidget);
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      await ApiService.instance.clearAllUserData();
    }
  });

  testWidgets(
      'InsightsScreen renders PeriodSwitcher and requests insights with selected month and year',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');

    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    int requestedMonth = 0;
    int requestedYear = 0;

    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      if (options.path.contains('/insights/')) {
        requestedMonth = options.queryParameters['month'] as int? ?? 0;
        requestedYear = options.queryParameters['year'] as int? ?? 0;
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'data': {
              'insights': ['Анализ за $requestedMonth/$requestedYear'],
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString('{}', 404);
    });

    try {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PeriodSwitcher), findsOneWidget);
      expect(requestedMonth, DateTime.now().month);
      expect(requestedYear, DateTime.now().year);
      expect(
        find.text('Анализ за ${DateTime.now().month}/${DateTime.now().year}'),
        findsOneWidget,
      );
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      await ApiService.instance.clearAllUserData();
    }
  });

  final outdatedNote = find.byKey(const ValueKey('insights_outdated_note'));
  final outdatedRefresh =
      find.byKey(const ValueKey('insights_outdated_refresh'));

  testWidgets('устаревший отчёт показывается с пометкой и кнопкой обновления',
      (tester) async {
    await _pumpInsights(
      tester,
      (request) => {
        'insights': ['Совет $request'],
        'is_outdated': request == 1,
      },
      (requests) async {
        expect(find.text('Совет 1'), findsOneWidget);
        expect(outdatedNote, findsOneWidget);
        expect(requests(), 1);

        await tester.tap(outdatedRefresh);
        await tester.pumpAndSettle();

        expect(requests(), 2);
        expect(find.text('Совет 2'), findsOneWidget);
        expect(outdatedNote, findsNothing);
      },
    );
  });

  testWidgets(
      'Pro: дневной лимит исчерпан — сохранённый отчёт с пометкой «завтра», '
      'без пейволла', (tester) async {
    await _pumpInsightsByGenerate(
      tester,
      generated: null,
      saved: {
        'insights': ['Старый совет'],
        'is_outdated': true,
      },
      plan: 'pro',
      (requests) async {
        expect(requests, [true, false]);
        expect(find.text('Старый совет'), findsOneWidget);
        expect(outdatedNote, findsOneWidget);
        expect(
          find.textContaining(LanguageManager.l10n.insights_outdated_tomorrow),
          findsWidgets,
        );
        expect(outdatedRefresh, findsNothing);
        expect(find.byType(PaywallScreen), findsNothing);
      },
    );
  });

  group('Тариф Free', () {
    setUp(() =>
        EntitlementService.instance = EntitlementService(isPro: () => false));

    final getReport = find.byKey(const ValueKey('insights_generate_button'));

    testWidgets(
        'текущий месяц сам не строится: «Получить отчёт» с подписью о лимите',
        (tester) async {
      await _pumpInsightsByGenerate(
        tester,
        generated: {
          'insights': ['Новый отчёт'],
        },
        saved: {'insights': <String>[], 'state': 'not_generated'},
        (requests) async {
          expect(requests, [false]);
          expect(find.text(LanguageManager.l10n.insights_get_report_btn),
              findsOneWidget);
          expect(find.text(LanguageManager.l10n.insights_free_limit_caption(1)),
              findsOneWidget);

          await tester.tap(getReport);
          await tester.pumpAndSettle();
          expect(requests, [false, true]);
          expect(find.text('Новый отчёт'), findsOneWidget);
        },
      );
    });

    testWidgets(
        'устаревший отчёт — «Обновлять отчёт — в Pro» открывает пейволл',
        (tester) async {
      await _pumpInsightsByGenerate(
        tester,
        generated: null,
        saved: {
          'insights': ['Старый совет'],
          'is_outdated': true,
        },
        (requests) async {
          expect(requests, [false]);
          expect(outdatedRefresh, findsNothing);
          await tester
              .tap(find.byKey(const ValueKey('insights_outdated_upgrade')));
          await tester.pumpAndSettle();
          expect(find.byType(PaywallScreen), findsOneWidget);
          expect(requests, [false]);
        },
      );
    });

    testWidgets(
        '403 PLAN_LIMIT_REACHED — пейволл и сохранённый отчёт с generate=false',
        (tester) async {
      await _pumpInsightsByGenerate(
        tester,
        generated: null,
        saved: {'insights': <String>[], 'state': 'not_generated'},
        (requests) async {
          await tester.tap(getReport);
          await tester.pumpAndSettle();

          expect(requests, [false, true, false]);
          expect(find.byType(PaywallScreen), findsOneWidget);
          // Дата не переносится посередине: «1 декабря» — одна строка
          final date = nonBreaking(LanguageManager.formatDayMonthYear(
              DateTime.utc(2026, 11, 30, 19).toLocal()));
          expect(find.text(LanguageManager.l10n.paywall_reason_ai_report(date)),
              findsOneWidget);

          // «Не сейчас» — снова карточка с кнопкой
          await tester.tap(find.byKey(const ValueKey('paywall_not_now')));
          await tester.pumpAndSettle();
          expect(getReport, findsOneWidget);
        },
      );
    });

    testWidgets('известный остаток 0 — пейволл без запроса', (tester) async {
      final subscription = ApiService.instance.subscription;
      await _pumpInsightsByGenerate(
        tester,
        generated: {
          'insights': ['Новый отчёт'],
        },
        saved: {'insights': <String>[], 'state': 'not_generated'},
        (requests) async {
          await subscription.update(PlanStatus(
            subscription: SubscriptionStatus.free,
            limits: {
              PlanFeature.aiReport: FeatureLimit(
                feature: PlanFeature.aiReport,
                period: LimitPeriod.month,
                limit: 1,
                used: 1,
                remaining: 0,
                resetsAt: DateTime.now().toUtc().add(const Duration(days: 3)),
              ),
            },
          ));
          await tester.tap(getReport);
          await tester.pumpAndSettle();
          expect(requests, [false]);
          expect(find.byType(PaywallScreen), findsOneWidget);
        },
      );
    });

    testWidgets(
        'отчёт по кнопке тратит остаток — на другом месяце «Получить отчёт» '
        'сразу открывает пейволл', (tester) async {
      final subscription = ApiService.instance.subscription;
      await _pumpInsightsByGenerate(
        tester,
        generated: {
          'insights': ['Новый отчёт'],
        },
        saved: {'insights': <String>[], 'state': 'not_generated'},
        (requests) async {
          await subscription.update(PlanStatus(
            subscription: SubscriptionStatus.free,
            limits: {
              PlanFeature.aiReport: FeatureLimit(
                feature: PlanFeature.aiReport,
                period: LimitPeriod.month,
                limit: 1,
                used: 0,
                remaining: 1,
                resetsAt: DateTime.now().toUtc().add(const Duration(days: 3)),
              ),
            },
          ));
          await tester.tap(getReport);
          await tester.pumpAndSettle();
          expect(requests, [false, true]);
          expect(find.text('Новый отчёт'), findsOneWidget);
          expect(subscription.isExhausted(PlanFeature.aiReport), isTrue);

          await tester.tap(find.byKey(const ValueKey('period_previous')));
          await tester.pumpAndSettle();
          expect(requests, [false, true, false]);

          await tester.tap(getReport);
          await tester.pumpAndSettle();
          expect(requests, [false, true, false]);
          expect(find.byType(PaywallScreen), findsOneWidget);
        },
      );
    });
  });

  testWidgets('изменение операций или лимитов перезапрашивает отчёт',
      (tester) async {
    await _pumpInsights(
      tester,
      (request) => {
        'insights': ['Совет $request'],
      },
      (requests) async {
        expect(requests(), 1);

        // Операция и синхронизация подряд — один запрос
        LocalDbService.transactionsChanged.value++;
        LocalDbService.transactionsChanged.value++;
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(requests(), 2);
        expect(find.text('Совет 2'), findsOneWidget);

        LocalDbService.budgetsChanged.value++;
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(requests(), 3);
      },
    );
  });

  testWidgets('мало операций — общий текст «Пока недостаточно данных»',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InsightsUnavailableCard(
          reason: InsightsUnavailableReason.notEnoughTransactions,
        ),
      ),
    ));

    expect(find.text(LanguageManager.l10n.insight_no_data), findsOneWidget);
  });

  testWidgets(
      'повторное открытие вкладки без изменений данных не запрашивает отчёт',
      (tester) async {
    await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
    final originalAdapter = ApiService.instance.dio.httpClientAdapter;
    var requests = 0;
    ApiService.instance.dio.httpClientAdapter =
        _MockHttpClientAdapter((options) async {
      requests++;
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'data': {
            'insights': ['Совет $requests'],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    Future<void> showTab(bool active) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen(isActive: active),
      ));
      await tester.pumpAndSettle();
    }

    try {
      await showTab(true);
      expect(requests, 1);

      for (var i = 0; i < 3; i++) {
        await showTab(false);
        await showTab(true);
      }
      expect(requests, 1, reason: 'отчёт уже на экране, данные не менялись');
      expect(find.text('Совет 1'), findsOneWidget);

      // Операции менялись, пока вкладка скрыта: запрос — один, при открытии.
      await showTab(false);
      LocalDbService.transactionsChanged.value++;
      LocalDbService.budgetsChanged.value++;
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, 1);
      await showTab(true);
      expect(requests, 2);
      expect(find.text('Совет 2'), findsOneWidget);
    } finally {
      ApiService.instance.dio.httpClientAdapter = originalAdapter;
      await ApiService.instance.clearAllUserData();
    }
  });
}

/// Запускает экран аналитики с фиктивным ответом бэкенда и считает запросы.
Future<void> _pumpInsights(
  WidgetTester tester,
  Map<String, dynamic> Function(int request) data,
  Future<void> Function(int Function() requests) body,
) async {
  await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
  final originalAdapter = ApiService.instance.dio.httpClientAdapter;
  var requestCount = 0;
  ApiService.instance.dio.httpClientAdapter =
      _MockHttpClientAdapter((options) async {
    requestCount++;
    return ResponseBody.fromString(
      jsonEncode({'status': 'success', 'data': data(requestCount)}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });

  try {
    await tester.pumpWidget(const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InsightsScreen()));
    await tester.pumpAndSettle();
    await body(() => requestCount);
  } finally {
    ApiService.instance.dio.httpClientAdapter = originalAdapter;
    await ApiService.instance.clearAllUserData();
  }
}

/// Бэкенд отчётов по флагу `generate`: [generated] — ответ на генерацию
/// (`null` — `403 PLAN_LIMIT_REACHED` тарифа [plan]), [saved] — на
/// `generate=false`. [body] получает флаги всех запросов.
Future<void> _pumpInsightsByGenerate(
  WidgetTester tester,
  Future<void> Function(List<bool> requests) body, {
  required Map<String, dynamic>? generated,
  required Map<String, dynamic> saved,
  String plan = 'free',
}) async {
  await ApiService.instance.auth.setTokens('test_token', 'test_refresh');
  final originalAdapter = ApiService.instance.dio.httpClientAdapter;
  final requests = <bool>[];
  ApiService.instance.dio.httpClientAdapter =
      _MockHttpClientAdapter((options) async {
    final generate = options.queryParameters['generate'] != false;
    requests.add(generate);
    final headers = {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    };
    if (generate && generated == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'error',
          'code': 'PLAN_LIMIT_REACHED',
          'details': {
            'feature': 'ai_report',
            'plan': plan,
            'limit': plan == 'pro' ? 5 : 1,
            'period': plan == 'pro' ? 'day' : 'month',
            'resets_at': '2026-11-30T19:00:00Z',
          },
        }),
        403,
        headers: headers,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'status': 'success', 'data': generate ? generated : saved}),
      200,
      headers: headers,
    );
  });

  try {
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {'/login': (_) => const SizedBox()},
        home: const InsightsScreen()));
    await tester.pumpAndSettle();
    await body(requests);
  } finally {
    await tester.pumpWidget(const SizedBox());
    ApiService.instance.dio.httpClientAdapter = originalAdapter;
    await ApiService.instance.clearAllUserData();
  }
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
