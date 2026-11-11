import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:getbalanceai_mobile/utils/app_error_handler.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:getbalanceai_mobile/widgets/app_alerts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LanguageManager.initFallback();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async => ['wifi'],
    );
  });

  group('Rate Limiting (HTTP 429 & RATE_LIMIT_EXCEEDED) Tests', () {
    setUp(() {
      LanguageManager.setLanguage(AppLanguage.ru);
    });

    test('AppErrorHandler.getMessage formats HTTP 429 without custom body', () {
      final reqOptions = RequestOptions(path: '/api/v1/insights/');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 429,
          data: null,
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(msg, equals(LanguageManager.l10n.http_429));
      expect(msg, contains('Превышен лимит запросов'));
    });

    test('AppErrorHandler.getMessage formats RATE_LIMIT_EXCEEDED error payload',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/auth/login');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 429,
          data: {
            'status': 'error',
            'code': 'RATE_LIMIT_EXCEEDED',
            'message':
                'Превышен лимит запросов. Пожалуйста, повторите попытку позже.',
            'details': {'limit': '5 per 1 minute'},
          },
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(
          msg,
          equals(
              'Превышен лимит запросов. Пожалуйста, повторите попытку позже.'));
    });

    test(
        'AppErrorHandler.getMessage: ошибка поля с сервера не показывается, сообщение — из l10n',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/auth/register');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 422,
          data: {
            'status': 'error',
            'code': 'VALIDATION_ERROR',
            'message': 'Validation failed',
            'details': {
              'fields': {
                'password':
                    'Пароль должен содержать минимум 6 символов, 1 букву и 1 цифру',
              },
            },
          },
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(msg, equals(LanguageManager.l10n.http_400));
    });

    testWidgets(
        'AppErrorHandler.show displays RateLimitDialog on 429 with retry-after header',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.ru);
      final reqOptions = RequestOptions(path: '/api/v1/auth/login');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['15'],
          }),
          data: {
            'status': 'error',
            'code': 'RATE_LIMIT_EXCEEDED',
            'message': 'Слишком много попыток входа.',
          },
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AppErrorHandler.show(context, err),
                child: const Text('Trigger 429'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger 429'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      // Текст сервера не показывается — сообщение из l10n
      expect(find.text('Слишком много попыток входа.'), findsNothing);
      expect(find.text(LanguageManager.l10n.http_429), findsOneWidget);
      expect(find.textContaining('15'), findsOneWidget);
    });

    testWidgets(
        'AppAlerts.showRateLimitDialog countdown decrements and enables actions',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.ru);
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppAlerts.showRateLimitDialog(
                    context,
                    title: 'Лимит исчерпан',
                    message: 'Подождите немного',
                    retryAfterSeconds: 2,
                    onRetry: () => retried = true,
                  );
                },
                child: const Text('Open Rate Limit'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rate Limit'));
      await tester.pumpAndSettle();

      expect(find.text('Лимит исчерпан'), findsOneWidget);
      expect(find.text('Подождите немного'), findsOneWidget);
      expect(find.textContaining('2'), findsOneWidget);

      // Advance clock by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('1'), findsOneWidget);

      // Advance clock by another second
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(LanguageManager.l10n.rate_limit_ready), findsOneWidget);

      // Retry button is now visible
      expect(find.text(LanguageManager.l10n.service_unavailable_retry),
          findsOneWidget);
      await tester
          .tap(find.text(LanguageManager.l10n.service_unavailable_retry));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });
  });
}
