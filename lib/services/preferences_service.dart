import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/secure_storage_config.dart';
import '../utils/app_logger.dart';

/// Настройки приложения: валюта, язык, тема, онбординг, кэш курсов,
/// счётчик UX-подсказок.
///
/// Хранятся в `shared_preferences`: секретов здесь нет, а чтение из
/// EncryptedSharedPreferences/Keychain — отдельный медленный вызов на каждый
/// ключ, и при старте их было больше десятка. Обычные настройки, в отличие
/// от Keychain, удаляются вместе с приложением на iOS — после переустановки
/// онбординг проходится заново.
///
/// UX-подсказки показываются 3 «сессии» (перезапуска приложения), в каждой —
/// на каждом экране по 1 разу.
class PreferencesService {
  PreferencesService._internal();
  static final PreferencesService instance = PreferencesService._internal();

  final FlutterSecureStorage _secureStorage = appSecureStorage;

  ValueNotifier<ThemeMode>? _themeModeNotifier;
  ValueNotifier<ThemeMode> get themeModeNotifier =>
      _themeModeNotifier ??= ValueNotifier(ThemeMode.system);

  static const _keyTotalSessions = 'ux_hint_sessions_completed';
  static const _keyCurrency = 'selected_currency';
  static const _keyLanguage = 'selected_language';
  static const _keyOnboardingCompleted = 'onboarding_setup_completed';
  static const _keyThemeMode = 'settings_theme_mode';
  static const _keyExchangeRates = 'cached_exchange_rates';
  static const _keyExchangeRatesUpdated = 'cached_exchange_rates_updated';
  static const _keyLegacyTransactionsMigrated = 'legacy_transactions_migrated';

  /// Настройки перенесены из защищённого хранилища (см. [init]).
  static const _keyMovedFromSecureStorage =
      'settings_moved_from_secure_storage';

  /// Прежний булев флаг тёмной темы — только для переноса.
  static const _legacyKeyDarkMode = 'settings_dark_mode';

  /// Неиспользуемая настройка уведомлений — удаляется при переносе.
  static const _legacyKeyNotifications = 'settings_notifications';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Вызывается при старте до чтения настроек. Один раз переносит настройки
  /// из защищённого хранилища, где они лежали в прежних версиях, и удаляет
  /// их оттуда. Если хранилище не читается, перенос повторится при
  /// следующем запуске.
  Future<void> init() async {
    final prefs = await _prefs;
    if (prefs.getBool(_keyMovedFromSecureStorage) ?? false) return;

    try {
      final stored = await _secureStorage.readAll();

      Future<void> moveString(String key) async {
        final value = stored[key];
        if (value != null && !prefs.containsKey(key)) {
          await prefs.setString(key, value);
        }
      }

      Future<void> moveInt(String key) async {
        final value = int.tryParse(stored[key] ?? '');
        if (value != null && !prefs.containsKey(key)) {
          await prefs.setInt(key, value);
        }
      }

      await moveString(_keyCurrency);
      await moveString(_keyLanguage);
      await moveString(_keyExchangeRates);
      await moveInt(_keyExchangeRatesUpdated);
      await moveInt(_keyTotalSessions);

      final onboarding = stored[_keyOnboardingCompleted];
      if (onboarding != null && !prefs.containsKey(_keyOnboardingCompleted)) {
        await prefs.setBool(_keyOnboardingCompleted, onboarding == 'true');
      }

      final legacyDark = stored[_legacyKeyDarkMode];
      final themeMode = stored[_keyThemeMode] ??
          (legacyDark == null
              ? null
              : (legacyDark == 'true' ? ThemeMode.dark : ThemeMode.light).name);
      if (themeMode != null && !prefs.containsKey(_keyThemeMode)) {
        await prefs.setString(_keyThemeMode, themeMode);
      }

      const movedKeys = [
        _keyCurrency,
        _keyLanguage,
        _keyExchangeRates,
        _keyExchangeRatesUpdated,
        _keyTotalSessions,
        _keyOnboardingCompleted,
        _keyThemeMode,
        _legacyKeyDarkMode,
        _legacyKeyNotifications,
      ];
      for (final key in movedKeys) {
        if (stored.containsKey(key)) await _secureStorage.delete(key: key);
      }

      await prefs.setBool(_keyMovedFromSecureStorage, true);
    } catch (e, stack) {
      AppLogger.w('[PreferencesService] Settings migration failed', e, stack);
    }
  }

  /// Сохраняет кэшированные курсы валют в формате JSON.
  Future<void> saveExchangeRates(String ratesJson) async {
    await (await _prefs).setString(_keyExchangeRates, ratesJson);
  }

  /// Получает кэшированные курсы валют.
  Future<String?> getExchangeRates() async {
    return (await _prefs).getString(_keyExchangeRates);
  }

  /// Сохраняет временную метку последнего обновления курсов (миллисекунды).
  Future<void> saveExchangeRatesUpdated(int timestampMs) async {
    await (await _prefs).setInt(_keyExchangeRatesUpdated, timestampMs);
  }

  /// Получает временную метку последнего обновления курсов.
  Future<int?> getExchangeRatesUpdated() async {
    return (await _prefs).getInt(_keyExchangeRatesUpdated);
  }

  /// Сохраняет выбранную валюту.
  Future<void> saveCurrency(String currencyCode) async {
    await (await _prefs).setString(_keyCurrency, currencyCode);
  }

  /// Получает сохраненную валюту.
  Future<String?> getCurrency() async {
    return (await _prefs).getString(_keyCurrency);
  }

  bool _isOnboardingCompleted = false;

  /// Синхронное значение статуса завершения онбординга.
  bool get isOnboardingCompletedSync => _isOnboardingCompleted;

  /// Загружает сохраненный статус онбординга при старте приложения.
  ///
  /// Без отметки онбординг считается пройденным, если уже сохранён язык
  /// (установки из версий до отдельного флага).
  Future<bool> loadSavedOnboardingStatus() async {
    final prefs = await _prefs;
    final language = prefs.getString(_keyLanguage);
    _isOnboardingCompleted = prefs.getBool(_keyOnboardingCompleted) ??
        (language != null && language.isNotEmpty);
    return _isOnboardingCompleted;
  }

  /// Сохраняет выбранный язык.
  Future<void> saveLanguage(String languageCode) async {
    _isOnboardingCompleted = true;
    await (await _prefs).setString(_keyLanguage, languageCode);
  }

  /// Получает сохраненный язык.
  Future<String?> getLanguage() async {
    return (await _prefs).getString(_keyLanguage);
  }

  /// Фиксирует успешное завершение первоначального онбординга.
  Future<void> setOnboardingCompleted() async {
    _isOnboardingCompleted = true;
    await (await _prefs).setBool(_keyOnboardingCompleted, true);
  }

  /// Загружает сохраненный режим темы оформления.
  /// По умолчанию используется системная тема ([ThemeMode.system]).
  Future<void> loadSavedThemeMode() async {
    themeModeNotifier.value = await getThemeMode();
  }

  /// Сохраняет выбранный режим темы оформления.
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      await (await _prefs).setString(_keyThemeMode, mode.name);
    } catch (e, stack) {
      AppLogger.e('Ошибка при сохранении режима темы', e, stack);
    }
  }

  /// Получает сохраненный режим темы оформления.
  Future<ThemeMode> getThemeMode() async {
    try {
      final val = (await _prefs).getString(_keyThemeMode);
      return ThemeMode.values.firstWhere(
        (m) => m.name == val,
        orElse: () => ThemeMode.system,
      );
    } catch (e, stack) {
      AppLogger.e('Ошибка при чтении режима темы', e, stack);
    }
    return ThemeMode.system;
  }

  /// Старые операции уже приведены к текущему формату
  /// (`LocalDbService.migrateLegacyTransactions`).
  Future<bool> isLegacyTransactionsMigrated() async {
    return (await _prefs).getBool(_keyLegacyTransactionsMigrated) ?? false;
  }

  Future<void> setLegacyTransactionsMigrated() async {
    await (await _prefs).setBool(_keyLegacyTransactionsMigrated, true);
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
      await (await _prefs).setInt(_keyTotalSessions, total + 1);
    }
  }

  Future<int> _getTotalSessions() async {
    return (await _prefs).getInt(_keyTotalSessions) ?? 0;
  }
}
