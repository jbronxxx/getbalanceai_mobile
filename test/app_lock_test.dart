import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/theme/theme.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/app_lock_gate.dart';
import 'package:getbalanceai_mobile/widgets/balance_card.dart';
import 'package:getbalanceai_mobile/widgets/profile/profile_settings_card.dart';
import 'support/fake_local_auth.dart';

/// SEC-08: вход по блокировке телефона, «глазок» на карточке баланса.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLocalAuth auth;
  late DateTime now;
  late AppLockService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageManager.initFallback();
    LanguageManager.setLanguage(AppLanguage.ru, save: false);
    auth = FakeLocalAuth();
    now = DateTime(2026, 11, 10, 12);
    service = AppLockService(auth: auth, clock: () => now);
  });

  Future<void> enable() async {
    SharedPreferences.setMockInitialValues({'privacy_app_lock_enabled': true});
    await service.init();
  }

  void background(Duration duration) {
    service.didChangeAppLifecycleState(AppLifecycleState.inactive);
    service.didChangeAppLifecycleState(AppLifecycleState.hidden);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(duration);
    service.didChangeAppLifecycleState(AppLifecycleState.hidden);
    service.didChangeAppLifecycleState(AppLifecycleState.inactive);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
  }

  group('AppLockService', () {
    test('по умолчанию выключена: запуск без блокировки', () async {
      await service.init();
      expect(service.enabled.value, isFalse);
      expect(service.locked.value, isFalse);
      background(const Duration(hours: 1));
      expect(service.locked.value, isFalse);
    });

    test('включена: приложение открывается запертым', () async {
      await enable();
      expect(service.locked.value, isTrue);
    });

    test('фон меньше минуты не запирает, минута и больше — запирает', () async {
      await enable();
      await service.unlock(title: 't', reason: 'r');
      expect(service.locked.value, isFalse);

      background(const Duration(seconds: 59));
      expect(service.locked.value, isFalse);

      background(AppLockService.relockAfter);
      expect(service.locked.value, isTrue);
    });

    test('окно PIN уводит приложение в фон — после входа оно не запирается',
        () async {
      await enable();
      auth.result = true;
      final unlocking = service.unlock(title: 't', reason: 'r');
      // Пока открыт системный экран PIN, приложение «в фоне»
      background(const Duration(minutes: 2));
      await unlocking;
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(service.locked.value, isFalse);
    });

    test('отмена оставляет приложение запертым', () async {
      await enable();
      auth.result =
          const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
      expect(
          await service.unlock(title: 't', reason: 'r'), AppLockResult.failed);
      expect(service.locked.value, isTrue);
    });

    test('много неудачных попыток — lockedOut, приложение заперто', () async {
      await enable();
      auth.result = const LocalAuthException(
          code: LocalAuthExceptionCode.temporaryLockout);
      expect(await service.unlock(title: 't', reason: 'r'),
          AppLockResult.lockedOut);
      expect(service.locked.value, isTrue);
    });

    test('блокировку экрана убрали с телефона — вход открыт, настройка выкл.',
        () async {
      await enable();
      auth.result = const LocalAuthException(
          code: LocalAuthExceptionCode.noCredentialsSet);
      expect(await service.unlock(title: 't', reason: 'r'),
          AppLockResult.unavailable);
      expect(service.locked.value, isFalse);
      expect(service.enabled.value, isFalse);
      expect(await PreferencesService.instance.isAppLockEnabled(), isFalse);
    });

    test('заголовок окна свой, английский подзаголовок не показывается',
        () async {
      await service.authenticate(title: 'Вход', reason: 'Подтвердите');
      expect(auth.lastReason, 'Подтвердите');
      final android = auth.lastMessages.whereType<AndroidAuthMessages>().single;
      expect(android.signInTitle, 'Вход');
      expect(android.signInHint, isEmpty);
      // После распознавания лица не нужно нажимать «Подтвердить»
      expect(auth.lastSensitiveTransaction, isFalse);
    });

    test('«Назад» на экране блокировки сворачивает приложение', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await service.init();
      expect(await service.didPopRoute(), isFalse);

      await enable();
      expect(await service.didPopRoute(), isTrue);
      expect(calls, contains('SystemNavigator.pop'));
    });
  });

  Widget app(Widget home, {AppLockService? lock}) => MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        builder: lock == null
            ? null
            : (context, child) => AppLockGate(service: lock, child: child!),
        home: Scaffold(body: SingleChildScrollView(child: home)),
      );

  group('Экран блокировки', () {
    testWidgets('закрывает приложение и сразу просит отпечаток/PIN',
        (tester) async {
      await enable();
      auth.result = false;
      await tester.pumpWidget(app(const Text('Баланс'), lock: service));
      await tester.pump();

      expect(find.byType(AppLockScreen), findsOneWidget);
      expect(find.text('Приложение заблокировано'), findsOneWidget);
      expect(auth.calls, 1);

      auth.result = true;
      await tester.tap(find.byKey(const ValueKey('app_unlock_button')));
      await tester.pump();
      expect(find.byType(AppLockScreen), findsNothing);
      expect(find.text('Баланс'), findsOneWidget);
    });

    testWidgets('после многих попыток объясняет, почему не открывается',
        (tester) async {
      await enable();
      auth.result = const LocalAuthException(
          code: LocalAuthExceptionCode.temporaryLockout);
      await tester.pumpWidget(app(const SizedBox(), lock: service));
      await tester.pump();
      expect(
          find.text('Слишком много попыток. Попробуйте позже'), findsOneWidget);
    });
  });

  group('Переключатель в «Профиле»', () {
    late AppLockService previous;

    setUp(() {
      previous = AppLockService.instance;
      AppLockService.instance = service;
    });
    tearDown(() => AppLockService.instance = previous);

    Future<void> tapSwitch(WidgetTester tester) async {
      await tester
          .pumpWidget(app(ProfileSettingsCard(onLanguageChanged: () {})));
      await tester.tap(find.byType(Switch));
      await tester.pump();
      // Дождаться таймера тоста
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('по умолчанию выключен', (tester) async {
      await service.init();
      await tester
          .pumpWidget(app(ProfileSettingsCard(onLanguageChanged: () {})));
      expect(find.text('Блокировка приложения'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('включение подтверждается отпечатком/PIN и запоминается',
        (tester) async {
      await service.init();
      await tapSwitch(tester);
      expect(auth.calls, 1);
      expect(service.enabled.value, isTrue);
      // Только что подтвердил — не запирать
      expect(service.locked.value, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(await PreferencesService.instance.isAppLockEnabled(), isTrue);
    });

    testWidgets('без блокировки экрана на телефоне не включается',
        (tester) async {
      await service.init();
      auth.supported = false;
      await tapSwitch(tester);
      expect(auth.calls, 0);
      expect(service.enabled.value, isFalse);
    });

    testWidgets('отмена проверки оставляет как было', (tester) async {
      await service.init();
      auth.result =
          const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
      await tapSwitch(tester);
      expect(service.enabled.value, isFalse);
    });

    testWidgets('выключение тоже подтверждается', (tester) async {
      await enable();
      await service.unlock(title: 't', reason: 'r');
      await tapSwitch(tester);
      expect(auth.calls, 2);
      expect(service.enabled.value, isFalse);
      expect(await PreferencesService.instance.isAppLockEnabled(), isFalse);
    });
  });

  group('«Глазок» на карточке баланса', () {
    setUp(() => PreferencesService.instance.hideBalanceNotifier.value = false);

    testWidgets('скрывает баланс, доход и расход и запоминает выбор',
        (tester) async {
      await tester.pumpWidget(
          app(const BalanceCard(balance: 1500, income: 2000, expense: 500)));
      expect(find.text(CurrencyFormatter.hiddenAmount), findsNothing);

      await tester.tap(find.byKey(const ValueKey('balance_hide_amounts')));
      await tester.pump();
      expect(find.text(CurrencyFormatter.hiddenAmount), findsNWidgets(3));
      expect(find.textContaining('2'), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('privacy_hide_balance'), isTrue);
      await PreferencesService.instance.loadHideBalance();
      expect(PreferencesService.instance.hideBalanceNotifier.value, isTrue);

      await tester.tap(find.byKey(const ValueKey('balance_hide_amounts')));
      await tester.pump();
      expect(find.text(CurrencyFormatter.hiddenAmount), findsNothing);
    });
  });
}
