import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/config/secure_storage_config.dart';
import 'package:getbalanceai_mobile/screens/startup_error_screen.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/app_error_handler.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async => null,
    );
  });

  setUp(() => LanguageManager.setLanguage(AppLanguage.ru, save: false));

  group('Экран ошибки запуска', () {
    Finder retryButton() => find.bySubtype<ElevatedButton>();

    bool isEnabled(WidgetTester tester) =>
        tester.widget<ElevatedButton>(retryButton()).onPressed != null;

    testWidgets('показывает локализованный текст на языке приложения',
        (tester) async {
      LanguageManager.setLanguage(AppLanguage.en, save: false);
      await tester.pumpWidget(StartupErrorApp(onRetry: () async => false));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.startup_error_title), findsOneWidget);
      expect(find.text(l10n.startup_error_desc), findsOneWidget);
      expect(find.text(l10n.service_unavailable_retry), findsOneWidget);
    });

    testWidgets('во время повтора кнопка заблокирована, после неудачи — снова',
        (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(StartupErrorApp(onRetry: () {
        calls++;
        return pending.future;
      }));
      await tester.pumpAndSettle();

      await tester.tap(retryButton());
      await tester.pump();
      expect(calls, 1);
      expect(isEnabled(tester), isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(retryButton(), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1, reason: 'повторный тап во время инициализации');

      pending.complete(false);
      await tester.pump();
      expect(isEnabled(tester), isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('исключение в повторе не оставляет кнопку заблокированной',
        (tester) async {
      await tester.pumpWidget(StartupErrorApp(
        onRetry: () async => throw StateError('boom'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(retryButton());
      await tester.pump();
      expect(isEnabled(tester), isTrue);
    });

    testWidgets('после успешного повтора кнопка остаётся заблокированной',
        (tester) async {
      await tester.pumpWidget(StartupErrorApp(onRetry: () async => true));
      await tester.pumpAndSettle();

      await tester.tap(retryButton());
      await tester.pump();
      expect(isEnabled(tester), isFalse);
    });
  });

  group('AppErrorHandler.getMessage', () {
    test('неизвестное исключение — общий текст без деталей', () {
      final msg = AppErrorHandler.getMessage(
          StateError('Bad state: secret internal detail'));

      expect(msg, LanguageManager.l10n.err_unexpected);
      expect(msg, isNot(contains('secret internal detail')));
    });

    test('SyncException по-прежнему даёт свой текст', () {
      final msg = AppErrorHandler.getMessage(
          const SyncException(SyncErrorCode.unauthorized));

      expect(msg, LanguageManager.l10n.sync_login_required);
    });

    test('общий текст переведён на все языки', () {
      final texts = AppLanguage.values
          .map((l) => lookupAppLocalizations(Locale(l.code)).err_unexpected)
          .toSet();
      expect(texts, hasLength(AppLanguage.values.length));
    });
  });

  test('CrashReporter вне release ничего не отправляет и не падает', () async {
    await CrashReporter.init();

    expect(CrashReporter.isEnabled, isFalse);
    CrashReporter.recordError(StateError('boom'), null, fatal: true);
    CrashReporter.recordFlutterError(
        FlutterErrorDetails(exception: StateError('boom')));
  });

  group('CrashReporter: дедупликация', () {
    setUp(CrashReporter.resetForTesting);

    test('одинаковая ошибка считается один раз', () {
      final error = StateError('PROD_API_BASE_URL is not configured');

      expect(CrashReporter.isFirstOccurrence(error, reason: 'startup init'),
          isTrue);
      expect(
          CrashReporter.isFirstOccurrence(
              StateError('PROD_API_BASE_URL is not configured'),
              reason: 'startup init'),
          isFalse);
    });

    test('другой текст, тип или причина — новое событие', () {
      expect(CrashReporter.isFirstOccurrence(StateError('a')), isTrue);
      expect(CrashReporter.isFirstOccurrence(StateError('b')), isTrue);
      expect(CrashReporter.isFirstOccurrence(ArgumentError('a')), isTrue);
      expect(CrashReporter.isFirstOccurrence(StateError('a'), reason: 'x'),
          isTrue);
    });
  });

  test('защищённое хранилище сбрасывается при ошибке Keystore', () {
    final options = appSecureStorage.aOptions.toMap();
    expect(options['resetOnError'], 'true');
    expect(options['encryptedSharedPreferences'], 'true');
  });
}
