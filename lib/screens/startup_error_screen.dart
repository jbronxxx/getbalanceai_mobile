import 'package:flutter/material.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import '../utils/utils.dart';

/// Корневой виджет на случай, когда инициализация сервисов в `main()`
/// не удалась (повреждённая БД, сбой Keystore, не задан URL API).
///
/// Не зависит от сервисов: тема и язык берутся из уже загруженных значений
/// или из значений по умолчанию.
class StartupErrorApp extends StatelessWidget {
  /// Повторяет инициализацию; `true` — приложение запущено.
  final Future<bool> Function() onRetry;

  const StartupErrorApp({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GetBalance AI',
      debugShowCheckedModeBanner: false,
      themeMode: PreferencesService.instance.themeModeNotifier.value,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: Locale(LanguageManager.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: StartupErrorScreen(onRetry: onRetry),
    );
  }
}

/// Экран ошибки запуска с кнопкой «Повторить». Данные не трогает.
class StartupErrorScreen extends StatefulWidget {
  final Future<bool> Function() onRetry;

  const StartupErrorScreen({super.key, required this.onRetry});

  @override
  State<StartupErrorScreen> createState() => _StartupErrorScreenState();
}

class _StartupErrorScreenState extends State<StartupErrorScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    var started = false;
    try {
      started = await widget.onRetry();
    } catch (e, stack) {
      AppLogger.e('[Startup] Повтор инициализации упал', e, stack);
      CrashReporter.recordError(e, stack, reason: 'startup retry');
    }
    if (!started && mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.startup_error_title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.startup_error_desc,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      disabledBackgroundColor: colorScheme.primary,
                      disabledForegroundColor: colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _retrying ? null : _retry,
                    // Пока идёт повтор — индикатор загрузки вместо подписи
                    child: _retrying
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text(context.l10n.service_unavailable_retry),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
