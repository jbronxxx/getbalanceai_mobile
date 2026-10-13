import 'environment.dart';

/// Единая точка конфигурации обращений к бэкенду.
class ApiConfig {
  static String get baseUrl => EnvironmentConfig.baseUrl;

  static const String googleServerClientId =
      '515668069765-se9i0kkcefd93ssb06pusjorjeki73k6.apps.googleusercontent.com';

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String loginGoogle = '/auth/google';
  static const String loginApple = '/auth/apple';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String refreshToken = '/auth/refresh';

  static const String transactions = '/transactions/';
  static const String budgets = '/budgets/';
  static const String sync = '/sync/';
  static const String insights = '/insights/';
  static const String currencyRates = '/currencies/rates';
  static const String health = '/health';
}
