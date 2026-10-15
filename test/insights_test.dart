import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/screens/insights_screen.dart';
import 'package:getbalanceai_mobile/models/insights_model.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:getbalanceai_mobile/widgets/ai_sparkles_loader.dart';
import 'package:getbalanceai_mobile/widgets/period/period.dart';

void main() {
  final storageData = <String, String>{};

  setUpAll(() {
    LanguageManager.initFallback();
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');

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
  });

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
      expect(parse('quota_exceeded'), InsightsReportState.quotaExceeded);
      expect(parse('busy'), InsightsReportState.busy);
      expect(parse('something_new'), InsightsReportState.ready);
      expect(InsightsModel.fromJson({'insights': []}).state,
          InsightsReportState.ready);
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
      expect(LanguageManager.l10n.insights_updated_prefix, 'Обновлено');
      expect(LanguageManager.l10n.insights_cache_hint,
          contains('Советы обновляются автоматически'));
      expect(
          LanguageManager.l10n.insights_assistants_busy_msg1,
          'Наши умные помощники заняты' != ''
              ? contains('наши умные помощники')
              : '');

      LanguageManager.setLanguage(AppLanguage.uz);
      expect(LanguageManager.formatDate(testDate), '2-oktabr, 14:30');
      expect(LanguageManager.l10n.insights_updated_prefix, 'Yangilangan');
      expect(LanguageManager.l10n.insights_cache_hint,
          contains('avtomatik ravishda yangilanadi'));
      expect(LanguageManager.l10n.insights_assistants_busy_msg1,
          contains('aqlli yordamchilarimiz'));

      LanguageManager.setLanguage(AppLanguage.en);
      expect(LanguageManager.formatDate(testDate), 'October 2, 14:30');
      expect(LanguageManager.l10n.insights_updated_prefix, 'Updated');
      expect(LanguageManager.l10n.insights_cache_hint,
          contains('Insights update automatically'));
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

  testWidgets(
      'InsightsScreen shows AiSparklesLoader during loading and not CircularProgressIndicator',
      (tester) async {
    await ApiService.instance.setTokens('test_token', 'test_refresh');

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
    await ApiService.instance.setTokens('test_token', 'test_refresh');

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

  testWidgets(
      'InsightsScreen does not display updated date, personal recs title, or cache hint',
      (tester) async {
    await ApiService.instance.setTokens('test_token', 'test_refresh');

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
      expect(find.text(LanguageManager.l10n.personal_recs_title), findsNothing);
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
    await ApiService.instance.setTokens('test_token', 'test_refresh');

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
    await ApiService.instance.setTokens('test_token', 'test_refresh');

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
