import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum Environment {
  prod,
  dev,
  local,
}

/// Выбор окружения и базового URL бэкенда.
///
/// В release-сборке всегда используется prod, URL берется только из
/// `--dart-define=PROD_API_BASE_URL=...`; `.env` не читается и не упаковывается в бандл.
/// В debug/profile значение ищется в `--dart-define` (приоритетно), затем в `.env`.
class EnvironmentConfig {
  static const String _envKey = 'selected_environment';
  static const String _definedProdUrl =
      String.fromEnvironment('PROD_API_BASE_URL');
  static const String _definedDevUrl =
      String.fromEnvironment('DEV_API_BASE_URL');
  static const String _definedLocalUrl = String.fromEnvironment('API_BASE_URL');
  static const bool _debugMenuFlag = bool.fromEnvironment('ENABLE_DEBUG_MENU');
  static const String _defaultLocalUrl = 'http://10.0.2.2:8000/api/v1';
  static const String _definedDefaultEnv =
      String.fromEnvironment('DEFAULT_ENVIRONMENT');

  static Environment _current = Environment.prod;
  static final List<Future<void> Function(Environment)> _listeners = [];

  static Environment get current => _current;

  static Environment get _defaultNonReleaseEnvironment {
    final raw = _resolve(_definedDefaultEnv, 'DEFAULT_ENVIRONMENT');
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
    if (envStr != null) {
      _current = Environment.values.firstWhere(
        (e) => e.name == envStr,
        orElse: () => _defaultNonReleaseEnvironment,
      );
    } else {
      _current = _defaultNonReleaseEnvironment;
    }
  }

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
    if (kReleaseMode) return _validateReleaseUrl(_definedProdUrl);

    switch (_current) {
      case Environment.prod:
        final prodUrl = _resolve(_definedProdUrl, 'PROD_API_BASE_URL');
        return prodUrl.isNotEmpty ? prodUrl : _definedProdUrl;
      case Environment.dev:
        final devUrl = _resolve(_definedDevUrl, 'DEV_API_BASE_URL');
        if (devUrl.isNotEmpty) return devUrl;
        final localUrl = _resolve(_definedLocalUrl, 'API_BASE_URL');
        return localUrl.isEmpty ? _defaultLocalUrl : localUrl;
      case Environment.local:
        final url = _resolve(_definedLocalUrl, 'API_BASE_URL');
        return url.isEmpty ? _defaultLocalUrl : url;
    }
  }

  static String _resolve(String defined, String envKey) {
    if (!kReleaseMode && dotenv.isInitialized) {
      final envVal = dotenv.maybeGet(envKey);
      if (envVal != null && envVal.isNotEmpty) {
        return envVal;
      }
    }
    if (defined.isNotEmpty) return defined;
    if (dotenv.isInitialized) return dotenv.maybeGet(envKey) ?? '';
    return '';
  }

  /// Проверяет release-URL на корректность и протокол https.
  static String _validateReleaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || uri.host.isEmpty) {
      throw StateError(
          'PROD_API_BASE_URL is not configured. Pass it via --dart-define.');
    }
    if (uri.scheme != 'https') {
      throw StateError('Release build requires an https API base URL.');
    }
    return url;
  }
}
