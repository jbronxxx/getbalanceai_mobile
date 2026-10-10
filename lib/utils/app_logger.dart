import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Глобальный экземпляр Talker для структурированного логирования.
/// В релизной сборке отключен в целях безопасности и производительности.
final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: kDebugMode,
    useConsoleLogs: kDebugMode,
  ),
);

/// Единый логгер приложения.
/// Делегирует вывод сообщений в [Talker], обеспечивая единую точку трассировки
/// событий, сетевых запросов и ошибок для консоли и встроенного Debug Menu.
class AppLogger {
  static void debug(dynamic message) => talker.debug(message);
  static void info(dynamic message) => talker.info(message);
  static void warning(dynamic message,
          [dynamic error, StackTrace? stackTrace]) =>
      talker.warning(message, error, stackTrace);
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      talker.error(message, error, stackTrace);

  /// Краткие алиасы для удобства.
  static void d(dynamic message) => talker.debug(message);
  static void i(dynamic message) => talker.info(message);
  static void w(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      talker.warning(message, error, stackTrace);
  static void e(dynamic message, [dynamic error, StackTrace? stackTrace]) =>
      talker.error(message, error, stackTrace);
}
