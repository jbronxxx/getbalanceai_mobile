import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/screens/service_unavailable_screen.dart';
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
  });

  group('Service Unavailable (HTTP 503) & Error Handler Tests', () {
    setUp(() {
      LanguageManager.setLanguage(AppLanguage.ru);
    });

    test(
        'AppErrorHandler.getMessage formats HTTP 503 error without custom body',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/health');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 503,
          data: null,
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(msg, contains('Сервис временно недоступен'));
    });

    test(
        'AppErrorHandler.getMessage: текст сервера не показывается, сообщение — из l10n',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/health');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 503,
          data: {
            'status': 'error',
            'code': 'SERVICE_UNAVAILABLE',
            'message': 'Плановое обновление базы данных до 03:00 UTC',
          },
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(msg, equals(LanguageManager.l10n.http_503));
    });

    test(
        'AppErrorHandler.getMessage formats SERVICE_UNAVAILABLE code without custom message',
        () {
      final reqOptions = RequestOptions(path: '/api/v1/sync/');
      final err = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 503,
          data: {
            'status': 'error',
            'code': 'SERVICE_UNAVAILABLE',
          },
        ),
      );

      final msg = AppErrorHandler.getMessage(err);
      expect(msg,
          equals('Сервис временно недоступен. Ведутся технические работы'));
    });

    test(
        'LanguageManager returns translations for service unavailable across all languages',
        () {
      LanguageManager.setLanguage(AppLanguage.ru);
      expect(LanguageManager.l10n.service_unavailable_title,
          equals('Сервис временно недоступен'));

      LanguageManager.setLanguage(AppLanguage.en);
      expect(LanguageManager.l10n.service_unavailable_title,
          equals('Service Unavailable'));
    });

    testWidgets(
        'ServiceUnavailableScreen renders correctly and triggers onRetry callback',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.ru);
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServiceUnavailableScreen(
            onRetry: () {
              retried = true;
            },
          ),
        ),
      );

      expect(find.byIcon(Icons.engineering_rounded), findsOneWidget);
      expect(find.text('Сервис временно недоступен'), findsOneWidget);
      expect(
          find.text(
              'Ведутся технические работы. Пожалуйста, повторите попытку позже.'),
          findsOneWidget);
      expect(find.text('Повторить попытку'), findsOneWidget);

      await tester.tap(find.text('Повторить попытку'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('ServiceUnavailableScreen displays customMessage when provided',
        (tester) async {
      const customMessage =
          'Сервер обновляется. Ожидаемое время завершения: 15 минут.';

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServiceUnavailableScreen(
            customMessage: customMessage,
          ),
        ),
      );

      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('AppAlerts.showServiceUnavailableDialog renders and dismisses',
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
                  AppAlerts.showServiceUnavailableDialog(
                    context,
                    onRetry: () => retried = true,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Сервис временно недоступен'), findsOneWidget);

      await tester.tap(find.text('Повторить попытку'));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
