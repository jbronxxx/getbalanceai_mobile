import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Environment {
  prod,
  dev,
  local,
}

/// Выбор окружения и базового URL бэкенда.
///
/// Все значения задаются только через `--dart-define`: в release —
/// `PROD_API_BASE_URL`, в debug/profile удобнее передать весь локальный
/// файл: `--dart-define-from-file=.env`. Сам `.env` в бандл не попадает.
/// В release всегда используется prod.
class EnvironmentConfig {
  static const String _envKey = 'selected_environment';
  static const String _prodUrlKey = 'PROD_API_BASE_URL';
  static const String _devUrlKey = 'DEV_API_BASE_URL';
  static const String _localUrlKey = 'API_BASE_URL';
  static const String _defaultEnvKey = 'DEFAULT_ENVIRONMENT';
  static const Map<String, String> _compiledDefines = {
    _prodUrlKey: String.fromEnvironment(_prodUrlKey),
    _devUrlKey: String.fromEnvironment(_devUrlKey),
    _localUrlKey: String.fromEnvironment(_localUrlKey),
    _defaultEnvKey: String.fromEnvironment(_defaultEnvKey),
  };
  static const bool _debugMenuFlag = bool.fromEnvironment('ENABLE_DEBUG_MENU');
  static const String _defaultLocalUrl = 'http://10.0.2.2:8000/api/v1';

  static Map<String, String> _defines = _compiledDefines;

  // До init() в debug — dev: prod без URL дал бы ошибку на первом запросе.
  static Environment _current =
      kReleaseMode ? Environment.prod : Environment.dev;
  static final List<Future<void> Function(Environment)> _listeners = [];

  static Environment get current => _current;

  static Environment get _defaultNonReleaseEnvironment {
    final raw = _define(_defaultEnvKey);
    final envName = raw.isNotEmpty ? raw : 'dev';
    return Environment.values.firstWhere(
      (e) => e.name.toLowerCase() == envName.toLowerCase(),
      orElse: () => Environment.dev,
    );
  }

  /// Debug-меню доступно в debug-сборке и в profile-сборке при
  /// `--dart-define=ENABLE_DEBUG_MENU=true`; в release недоступно никогда.
  static bool get debugMenuEnabled =>
      !kReleaseMode && (kDebugMode || _debugMenuFlag);

  static Future<void> init() async {
    if (kReleaseMode) {
      _current = Environment.prod;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final envStr = prefs.getString(_envKey);
    final saved = Environment.values.where((e) => e.name == envStr);
    // Сохранённое окружение могло остаться от запуска с другими define —
    // без URL на нём приложение не стартует.
    _current = saved.isNotEmpty && isConfigured(saved.first)
        ? saved.first
        : _defaultNonReleaseEnvironment;
  }

  /// Для окружения задан URL. Dev и local без URL уходят на локальный бэкенд.
  static bool isConfigured(Environment env) =>
      env != Environment.prod || _define(_prodUrlKey).isNotEmpty;

  static void addEnvironmentListener(
      Future<void> Function(Environment) listener) {
    _listeners.add(listener);
  }

  static void removeEnvironmentListener(
      Future<void> Function(Environment) listener) {
    _listeners.remove(listener);
  }

  @visibleForTesting
  static void clearListenersForTesting() {
    _listeners.clear();
  }

  @visibleForTesting
  static void setCurrentForTesting(Environment env) {
    _current = env;
  }

  /// Подменяет значения `--dart-define`; `null` — вернуть скомпилированные.
  @visibleForTesting
  static void setDefinesForTesting(Map<String, String>? defines) {
    _defines = defines ?? _compiledDefines;
  }

  static Future<void> setEnvironment(Environment env) async {
    if (kReleaseMode) return;
    _current = env;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_envKey, env.name);
    for (final listener in List.of(_listeners)) {
      await listener(env);
    }
  }

  static String get baseUrl {
    if (kReleaseMode) return _validateProdUrl(_define(_prodUrlKey));

    switch (_current) {
      case Environment.prod:
        return _validateProdUrl(_define(_prodUrlKey));
      case Environment.dev:
        final devUrl = _define(_devUrlKey);
        if (devUrl.isNotEmpty) return devUrl;
        final localUrl = _define(_localUrlKey);
        return localUrl.isEmpty ? _defaultLocalUrl : localUrl;
      case Environment.local:
        final url = _define(_localUrlKey);
        return url.isEmpty ? _defaultLocalUrl : url;
    }
  }

  static String _define(String key) => _defines[key] ?? '';

  /// Проверяет prod-URL на корректность и протокол https.
  static String _validateProdUrl(String url) {
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || uri.host.isEmpty) {
      throw StateError(
          'PROD_API_BASE_URL is not configured. Pass it via --dart-define.');
    }
    if (uri.scheme != 'https') {
      throw StateError('Prod API base URL must use https.');
    }
    return url;
  }
}
