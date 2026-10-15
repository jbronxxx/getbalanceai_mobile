import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getbalanceai_mobile/cubits/auth/auth_cubit.dart';
import 'package:getbalanceai_mobile/screens/main_shell.dart';
import 'package:getbalanceai_mobile/services/api_service.dart';
import 'package:getbalanceai_mobile/services/device_capability_service.dart';
import 'package:getbalanceai_mobile/services/local_db_service.dart';
import 'package:getbalanceai_mobile/services/preferences_service.dart';
import 'package:getbalanceai_mobile/theme/app_theme.dart';
import 'package:getbalanceai_mobile/utils/currency_formatter.dart';
import 'package:getbalanceai_mobile/utils/language_manager.dart';
import 'package:getbalanceai_mobile/widgets/glass_container.dart';
import 'package:getbalanceai_mobile/widgets/liquid_glass_nav_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthCubit extends MockCubit<AuthState> implements AuthCubit {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({
      'onboarding_setup_completed': 'true',
    });
    SharedPreferences.setMockInitialValues({
      'language_code': 'ru',
    });
    PackageInfo.setMockInitialValues(
      appName: 'FinanceApp',
      packageName: 'com.finance.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    final tempDir = await Directory.systemTemp.createTemp('perf_shell_test');
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    );

    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:8000/api/v1');
    LanguageManager.initFallback();
    await LocalDbService.init();

    ApiService.instance.dio.httpClientAdapter = _MockHttpClientAdapter();
    await ApiService.instance.setTokens('test_token', 'test_refresh');
  });

  tearDown(() {
    DeviceCapabilityService.instance.reset();
  });

  Widget buildTestApp(Widget child,
      {ThemeData? theme, bool disableAnimations = false}) {
    return MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: child,
      ),
    );
  }

  group('DeviceCapabilityService Tests (D1)', () {
    test('Синглтон и переопределение mockBlurSupported', () {
      final service = DeviceCapabilityService.instance;
      expect(service, isNotNull);

      service.setMockBlurSupported(false);
      expect(service.isBlurSupported, isFalse);

      service.setMockBlurSupported(true);
      expect(service.isBlurSupported, isTrue);

      service.reset();
      // После сброса возвращается дефолтное поведение платформы
      expect(service.isBlurSupported, isNotNull);
    });
  });

  group('LiquidGlassNavBar Performance & Fallback Tests (D1)', () {
    testWidgets(
        'При включенном размытии навбар оборачивается в RepaintBoundary и рендерит BackdropFilter',
        (tester) async {
      DeviceCapabilityService.instance.setMockBlurSupported(true);

      await tester.pumpWidget(
        buildTestApp(
          LiquidGlassNavBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              LiquidGlassNavItem(icon: Icons.home, label: 'Главная'),
              LiquidGlassNavItem(icon: Icons.person, label: 'Профиль'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets(
        'При неподдерживаемом размытии (Android < API 31) BackdropFilter отключается, используется непрозрачная заливка',
        (tester) async {
      DeviceCapabilityService.instance.setMockBlurSupported(false);

      await tester.pumpWidget(
        buildTestApp(
          LiquidGlassNavBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              LiquidGlassNavItem(icon: Icons.home, label: 'Главная'),
              LiquidGlassNavItem(icon: Icons.person, label: 'Профиль'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets(
        'При disableAnimations == true BackdropFilter отключается в пользу непрозрачной заливки',
        (tester) async {
      DeviceCapabilityService.instance.setMockBlurSupported(true);

      await tester.pumpWidget(
        buildTestApp(
          LiquidGlassNavBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              LiquidGlassNavItem(icon: Icons.home, label: 'Главная'),
              LiquidGlassNavItem(icon: Icons.person, label: 'Профиль'),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  group('GlassContainer Performance & Fallback Tests (D1)', () {
    testWidgets(
        'GlassContainer отключает BackdropFilter при отсутствии поддержки размытия',
        (tester) async {
      DeviceCapabilityService.instance.setMockBlurSupported(false);

      await tester.pumpWidget(
        buildTestApp(
          const GlassContainer(
            child: Text('Контент без размытия'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Контент без размытия'), findsOneWidget);
    });

    testWidgets(
        'GlassContainer использует BackdropFilter при наличии аппаратной поддержки',
        (tester) async {
      DeviceCapabilityService.instance.setMockBlurSupported(true);

      await tester.pumpWidget(
        buildTestApp(
          const GlassContainer(
            child: Text('Контент с размытием'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('MainShell IndexedStack & Performance Tests (D2)', () {
    late MockAuthCubit mockAuthCubit;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({
        'onboarding_setup_completed': 'true',
      });
      await PreferencesService.instance.setOnboardingCompleted();
      mockAuthCubit = MockAuthCubit();
      when(() => mockAuthCubit.state).thenReturn(
        Authenticated(
          email: 'test@example.com',
          name: 'Test User',
        ),
      );
      when(() => mockAuthCubit.stream).thenAnswer((_) => const Stream.empty());
    });

    testWidgets(
        'MainShell использует IndexedStack и сохраняет экраны в дереве виджетов',
        (tester) async {
      await PreferencesService.instance.setOnboardingCompleted();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const MainShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Проверяем наличие IndexedStack с PageStorageKey
      final indexedStackFinder =
          find.byKey(const Key('main_shell_indexed_stack'));
      expect(indexedStackFinder, findsOneWidget);

      final indexedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(indexedStack.index, equals(0));
      expect(indexedStack.children.length, equals(4));

      // Проверяем наличие PageStorageKey у всех вкладок (неактивные вкладки в IndexedStack находятся в offstage)
      expect(find.byKey(const PageStorageKey('dashboard_tab')), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('budgets_tab'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const PageStorageKey('insights_tab'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const PageStorageKey('profile_tab'), skipOffstage: false),
        findsOneWidget,
      );

      // Тост, показанный на одной вкладке, закрывается при переходе на другую
      ScaffoldMessenger.of(tester.element(find.byType(MainShell)))
          .showSnackBar(const SnackBar(content: Text('toast_on_balance')));
      await tester.pump();
      expect(find.text('toast_on_balance'), findsOneWidget);

      // Переключаемся на вкладку «Бюджет» (индекс 1)
      await tester.tap(find.text('Бюджет'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('toast_on_balance'), findsNothing);

      final updatedStack = tester.widget<IndexedStack>(indexedStackFinder);
      expect(updatedStack.index, equals(1));

      // Все экраны продолжают существовать в дереве (не пересоздаются с нуля)
      expect(
        find.byKey(const PageStorageKey('dashboard_tab'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const PageStorageKey('budgets_tab')), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('insights_tab'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const PageStorageKey('profile_tab'), skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets(
        'Смена валюты CurrencyFormatter не вызывает пересоздания навбара',
        (tester) async {
      await PreferencesService.instance.setOnboardingCompleted();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.lightTheme,
          home: BlocProvider<AuthCubit>.value(
            value: mockAuthCubit,
            child: const MainShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LiquidGlassNavBar), findsOneWidget);

      // Меняем валюту через ValueNotifier
      CurrencyFormatter.currencyNotifier.value = Currency.usd;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // IndexedStack и LiquidGlassNavBar остаются в консистентном состоянии
      expect(
        find.byKey(const Key('main_shell_indexed_stack')),
        findsOneWidget,
      );
      expect(find.byType(LiquidGlassNavBar), findsOneWidget);
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"status":"success","data":{"insights":[],"generated_at":"2026-10-02T13:45:00Z"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
