import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/service_unavailable_screen.dart';
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

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (!kReleaseMode) {
      talker.handle(details.exception, details.stack, 'UI Error');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (!kReleaseMode) {
      talker.handle(error, stack, 'Async Error');
    }
    return true;
  };

  if (!kReleaseMode) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      try {
        final envFile = File('.env');
        if (envFile.existsSync()) {
          dotenv.testLoad(fileInput: envFile.readAsStringSync());
        }
      } catch (_) {
        AppLogger.w('[Config] .env not loaded: $e');
      }
    }
  }

  await EnvironmentConfig.init();

  await LocalDbService.init();
  await PendingDeletionsStore.init();
  await ApiService.instance.init();
  await CurrencyFormatter.loadSavedCurrency();
  await CurrencyExchangeService.instance.init();
  unawaited(CurrencyExchangeService.instance.fetchLatestRates());
  await LanguageManager.loadSavedLanguage();
  LanguageManager.initFallback();
  await PreferencesService.instance.loadSavedOnboardingStatus();
  await PreferencesService.instance.loadSavedThemeMode();

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

  runApp(const FinanceApp());
  // Скрытие нативного сплеш-экрана после передачи управления корневому виджету
  FlutterNativeSplash.remove();
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
