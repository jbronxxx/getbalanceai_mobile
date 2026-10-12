import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_logger.dart';

/// Сервис для управления UX-подсказками.
///
/// Логика:
/// 1. Обучение длится 3 «сессии» (перезапуска приложения).
/// 2. В каждой сессии мы показываем подсказку на каждом экране по 1 разу.
class PreferencesService {
  PreferencesService._internal();
  static final PreferencesService instance = PreferencesService._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  ValueNotifier<ThemeMode>? _themeModeNotifier;
  ValueNotifier<ThemeMode> get themeModeNotifier =>
      _themeModeNotifier ??= ValueNotifier(ThemeMode.system);

  ValueNotifier<bool>? _darkModeNotifier;
  ValueNotifier<bool> get darkModeNotifier =>
      _darkModeNotifier ??= ValueNotifier(false);

  static const _keyTotalSessions = 'ux_hint_sessions_completed';
  static const _keyCurrency = 'selected_currency';
  static const _keyLanguage = 'selected_language';
  static const _keyOnboardingCompleted = 'onboarding_setup_completed';
  static const _keyNotifications = 'settings_notifications';
  static const _keyDarkMode = 'settings_dark_mode';
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyExchangeRates = 'cached_exchange_rates';
  static const _keyExchangeRatesUpdated = 'cached_exchange_rates_updated';

  /// Сохраняет кэшированные курсы валют в формате JSON.
  Future<void> saveExchangeRates(String ratesJson) async {
    await _storage.write(key: _keyExchangeRates, value: ratesJson);
  }

  /// Получает кэшированные курсы валют.
  Future<String?> getExchangeRates() async {
    return await _storage.read(key: _keyExchangeRates);
  }

  /// Сохраняет временную метку последнего обновления курсов (миллисекунды).
  Future<void> saveExchangeRatesUpdated(int timestampMs) async {
    await _storage.write(
      key: _keyExchangeRatesUpdated,
      value: timestampMs.toString(),
    );
  }

  /// Получает временную метку последнего обновления курсов.
  Future<int?> getExchangeRatesUpdated() async {
    final val = await _storage.read(key: _keyExchangeRatesUpdated);
    return val != null ? int.tryParse(val) : null;
  }

  /// Сохраняет выбранную валюту.
  Future<void> saveCurrency(String currencyCode) async {
    await _storage.write(key: _keyCurrency, value: currencyCode);
  }

  /// Получает сохраненную валюту.
  Future<String?> getCurrency() async {
    return await _storage.read(key: _keyCurrency);
  }

  /// Сохраняет выбранный язык.
  Future<void> saveLanguage(String languageCode) async {
    await _storage.write(key: _keyLanguage, value: languageCode);
  }

  /// Получает сохраненный язык.
  Future<String?> getLanguage() async {
    return await _storage.read(key: _keyLanguage);
  }

  /// Проверяет, был ли полностью завершен первоначальный онбординг.
  Future<bool> isOnboardingCompleted() async {
    final val = await _storage.read(key: _keyOnboardingCompleted);
    return val == 'true';
  }

  /// Фиксирует успешное завершение первоначального онбординга.
  Future<void> setOnboardingCompleted() async {
    await _storage.write(key: _keyOnboardingCompleted, value: 'true');
  }

  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _storage.write(key: _keyNotifications, value: enabled.toString());
  }

  Future<bool> getNotificationsEnabled() async {
    final val = await _storage.read(key: _keyNotifications);
    return val == null || val == 'true';
  }

  /// Загружает сохраненный режим темы оформления.
  /// По умолчанию используется системная тема ([ThemeMode.system]).
  Future<void> loadSavedThemeMode() async {
    final mode = await getThemeMode();
    themeModeNotifier.value = mode;
    darkModeNotifier.value = mode == ThemeMode.dark;
  }

  /// Сохраняет выбранный режим темы оформления.
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    darkModeNotifier.value = mode == ThemeMode.dark;
    try {
      await _storage.write(key: _keyThemeMode, value: mode.name);
      await _storage.write(
        key: _keyDarkMode,
        value: (mode == ThemeMode.dark).toString(),
      );
    } catch (e, stack) {
      AppLogger.e('Ошибка при сохранении режима темы', e, stack);
    }
  }

  /// Получает сохраненный режим темы оформления с миграцией со старого булева флага.
  Future<ThemeMode> getThemeMode() async {
    try {
      final val = await _storage.read(key: _keyThemeMode);
      if (val != null) {
        return ThemeMode.values.firstWhere(
          (m) => m.name == val,
          orElse: () => ThemeMode.system,
        );
      }
      final legacyVal = await _storage.read(key: _keyDarkMode);
      if (legacyVal != null) {
        return legacyVal == 'true' ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (e, stack) {
      AppLogger.e('Ошибка при чтении режима темы', e, stack);
    }
    return ThemeMode.system;
  }

  /// Обратная совместимость для загрузки флага темной темы.
  Future<void> loadSavedDarkMode() async {
    await loadSavedThemeMode();
  }

  /// Обратная совместимость для сохранения флага темной темы.
  Future<void> saveDarkMode(bool enabled) async {
    await saveThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  /// Обратная совместимость для проверки активности темной темы.
  Future<bool> getDarkMode() async {
    final mode = await getThemeMode();
    return mode == ThemeMode.dark;
  }

  // Храним идентификаторы экранов, где хинт уже был показан в этой сессии
  final Set<String> _shownScreensInSession = {};
  bool _sessionAlreadyCounted = false;

  /// Можно ли показать хинт для конкретного экрана?
  Future<bool> shouldShowSwipeHint(String screenId) async {
    final totalSessions = await _getTotalSessions();

    // Если пользователь уже прошел 3 сессии обучения — больше не показываем нигде
    if (totalSessions >= 3) return false;

    // В рамках одной сессии показываем только если на этом экране еще не видели
    return !_shownScreensInSession.contains(screenId);
  }

  /// Фиксирует факт показа хинта на конкретном экране.
  Future<void> recordHintShown(String screenId) async {
    _shownScreensInSession.add(screenId);

    // Если это вообще первый показ в этой сессии (на любом экране),
    // увеличиваем счетчик глобальных сессий обучения.
    if (!_sessionAlreadyCounted) {
      _sessionAlreadyCounted = true;
      final total = await _getTotalSessions();
      await _storage.write(
          key: _keyTotalSessions, value: (total + 1).toString());
    }
  }

  Future<int> _getTotalSessions() async {
    final val = await _storage.read(key: _keyTotalSessions);
    return int.tryParse(val ?? '0') ?? 0;
  }
}
