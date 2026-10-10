import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/services/services.dart';
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
import 'cubits/auth/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/environment.dart';

/// Точка входа в приложение.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      AppLogger.w('[Config] .env not loaded: $e');
    }
  }

  await EnvironmentConfig.init();

  await LocalDbService.init();
  await PendingDeletionsStore.init();
  await ApiService.instance.init();
  await CurrencyFormatter.loadSavedCurrency();
  await LanguageManager.loadSavedLanguage();
  LanguageManager.initFallback();
  await PreferencesService.instance.loadSavedDarkMode();

  // Фиксируем ориентацию и стиль системных панелей до запуска приложения,
  // чтобы избежать скачков верстки при инициализации первого кадра.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const FinanceApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryTeal = Color(0xFF0F766E);

    return ValueListenableBuilder<bool>(
      valueListenable: PreferencesService.instance.darkModeNotifier,
      builder: (context, isDarkMode, child) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageManager.languageNotifier,
          builder: (context, currentLanguage, child) {
            return BlocProvider(
                create: (_) => AuthCubit(),
                child: MaterialApp(
                  navigatorKey: navigatorKey,
                  title: 'Family Budget',
                  debugShowCheckedModeBanner: false,
                  themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                  locale: Locale(currentLanguage.code),
                  supportedLocales: const [
                    Locale('ru'),
                    Locale('uz'),
                    Locale('en'),
                  ],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  routes: {
                    '/': (context) => const MainShell(),
                    '/login': (context) => const AuthScreen(),
                    '/service-unavailable': (context) =>
                        const ServiceUnavailableScreen(),
                  },
                  theme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primaryTeal,
                      primary: primaryTeal,
                      secondary: const Color(0xFF14B8A6),
                      surface: const Color(0xFFF8FAFC),
                      error: const Color(0xFFEF4444),
                    ),
                    textTheme: GoogleFonts.interTextTheme(),
                    cardTheme: CardTheme(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(
                            color: Color(0xFFF1F5F9), width: 1),
                      ),
                      color: Colors.white,
                    ),
                    floatingActionButtonTheme:
                        const FloatingActionButtonThemeData(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: CircleBorder(),
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: primaryTeal,
                      brightness: Brightness.dark,
                      primary: primaryTeal,
                      secondary: const Color(0xFF14B8A6),
                      error: const Color(0xFFEF4444),
                    ),
                    textTheme:
                        GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
                    cardTheme: CardTheme(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(
                            color: Color(0xFF334155), width: 1),
                      ),
                      color: const Color(0xFF1E293B),
                    ),
                    floatingActionButtonTheme:
                        const FloatingActionButtonThemeData(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: CircleBorder(),
                    ),
                  ),
                ));
          },
        );
      },
    );
  }
}
