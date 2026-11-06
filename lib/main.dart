import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/service_unavailable_screen.dart';
import 'screens/startup_error_screen.dart';
import 'screens/welcome_setup_screen.dart';
import 'cubits/auth/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'config/environment.dart';

import 'theme/theme.dart';

/// Точка входа в приложение.
void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Удержание нативного сплеш-экрана на время асинхронной инициализации сервисов
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  GoogleFonts.config.allowRuntimeFetching = false;

  // Первым шагом: должен поймать и сбои инициализации ниже. Сам не падает.
  await CrashReporter.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    CrashReporter.recordFlutterError(details);
    if (!kReleaseMode) {
      talker.handle(details.exception, details.stack, 'UI Error');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReporter.recordError(error, stack, fatal: true);
    if (!kReleaseMode) {
      talker.handle(error, stack, 'Async Error');
    }
    return true;
  };

  try {
    await _setPreferredOrientations();
    if (await _initServices()) {
      _runFinanceApp();
    } else {
      runApp(const StartupErrorApp(onRetry: _retryStartup));
    }
  } finally {
    // Скрытие нативного сплеш-экрана после передачи управления корневому
    // виджету. В finally — чтобы сплэш не завис при любом сбое старта.
    FlutterNativeSplash.remove();
  }
}

/// Инициализирует сервисы до `runApp`. Возвращает `false`, если что-то
/// упало (повреждённая БД, сбой Keystore, не задан URL API) — тогда вместо
/// приложения показывается [StartupErrorApp].
///
/// Можно вызывать повторно: уже открытая БД не открывается заново, остальные
/// шаги просто перечитывают сохранённые значения.
Future<bool> _initServices() async {
  try {
    // Две независимые цепочки идут параллельно: каждый шаг в основном ждёт
    // платформу (диск, Keystore), а не процессор.
    await Future.wait([
      _loadSettings(),
      _restoreAccount(),
    ]);

    // Нужны и база, и сохранённая валюта (в неё переводятся операции в RUB)
    final prefs = PreferencesService.instance;
    if (!await prefs.isLegacyTransactionsMigrated() &&
        LocalDbService.instance.migrateLegacyTransactions()) {
      await prefs.setLegacyTransactionsMigrated();
    }

    unawaited(CurrencyExchangeService.instance.fetchLatestRates());
    return true;
  } catch (e, stack) {
    AppLogger.e('[Startup] Инициализация не удалась', e, stack);
    CrashReporter.recordError(e, stack, reason: 'startup init');
    return false;
  }
}

/// Настройки, язык, тема и возможности устройства. После [PreferencesService.init]
/// все чтения идут из памяти `shared_preferences`.
Future<void> _loadSettings() async {
  final prefs = PreferencesService.instance;
  await Future.wait([
    prefs.init(),
    DeviceCapabilityService.instance.init(),
  ]);
  await CurrencyFormatter.loadSavedCurrency();
  await CurrencyExchangeService.instance.init();
  await LanguageManager.loadSavedLanguage();
  LanguageManager.initFallback();
  await prefs.loadSavedOnboardingStatus();
  await prefs.loadSavedThemeMode();
}

/// База, очередь удалений и сессия. Сессия — последней: ключи ETag зависят
/// от окружения, а данные другого аккаунта на устройстве стираются из базы
/// и очереди удалений (`SyncService.claimLocalData`).
Future<void> _restoreAccount() async {
  await Future.wait([
    EnvironmentConfig.init(),
    if (!LocalDbService.isInitialized) LocalDbService.init(),
    PendingDeletionsStore.init(),
  ]);
  await ApiService.instance.init();
}

/// Повтор с экрана ошибки запуска: при успехе подменяет корневой виджет.
Future<bool> _retryStartup() async {
  final started = await _initServices();
  if (started) _runFinanceApp();
  return started;
}

void _runFinanceApp() {
  runApp(const FinanceApp());
  AutoSyncService.instance.start();
}

Future<void> _setPreferredOrientations() async {
  // На планшетах и iPad поддерживаем все ориентации согласно требованиям App Store,
  // на смартфонах фиксируем портретную ориентацию для предотвращения скачков интерфейса.
  final view = PlatformDispatcher.instance.views.firstOrNull;
  final isTablet = view != null &&
      (view.physicalSize.shortestSide / view.devicePixelRatio) >= 600;
  if (!isTablet) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: ValueListenableBuilder<ThemeMode>(
        key: const ValueKey('finance_app_theme_mode'),
        valueListenable: PreferencesService.instance.themeModeNotifier,
        builder: (context, themeMode, child) {
          return ValueListenableBuilder<AppLanguage>(
            valueListenable: LanguageManager.languageNotifier,
            builder: (context, currentLanguage, child) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                title: 'GetBalance AI',
                debugShowCheckedModeBanner: false,
                themeMode: themeMode,
                locale: Locale(currentLanguage.code),
                supportedLocales: const [
                  Locale('ru'),
                  Locale('uz'),
                  Locale('en'),
                  Locale('kk'),
                ],
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                routes: {
                  '/': (context) =>
                      PreferencesService.instance.isOnboardingCompletedSync
                          ? const MainShell()
                          : WelcomeSetupScreen(
                              onFinish: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const MainShell(),
                                  ),
                                );
                              },
                            ),
                  '/main': (context) => const MainShell(),
                  '/login': (context) => const AuthScreen(),
                  '/service-unavailable': (context) =>
                      const ServiceUnavailableScreen(),
                },
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
              );
            },
          );
        },
      ),
    );
  }
}
