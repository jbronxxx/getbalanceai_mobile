import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_logger.dart';

/// Отправка крашей и нефатальных ошибок в Firebase Crashlytics.
///
/// Работает только в release на Android: для iOS Firebase ещё не настроен
/// (нет `GoogleService-Info.plist`), debug не засоряет отчёты. До [init]
/// и вне release все методы — no-op, поэтому их можно звать из любого кода
/// и из тестов.
class CrashReporter {
  CrashReporter._();

  static bool _enabled = false;
  static final Set<String> _reported = {};

  /// Отчёты действительно уходят в Crashlytics.
  static bool get isEnabled => _enabled;

  /// Поднимает Firebase и включает сбор. Сбой не мешает запуску приложения.
  static Future<void> init() async {
    if (!kReleaseMode || !Platform.isAndroid) return;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      // В манифесте сбор выключен по умолчанию, включаем только здесь.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      _enabled = true;
    } catch (e, stack) {
      AppLogger.e('[CrashReporter] Firebase не инициализирован', e, stack);
    }
  }

  /// Одинаковая ошибка (тип + текст + причина) уходит один раз за запуск:
  /// повторы — например, нажатия «Повторить» на экране ошибки — не плодят
  /// события в консоли. Возвращает `true` для первого вхождения.
  @visibleForTesting
  static bool isFirstOccurrence(Object error, {String? reason}) =>
      _reported.add('${error.runtimeType}|$error|$reason');

  @visibleForTesting
  static void resetForTesting() => _reported.clear();

  /// Необработанная ошибка фреймворка (`FlutterError.onError`).
  static void recordFlutterError(FlutterErrorDetails details) {
    if (!_enabled) return;
    if (!isFirstOccurrence(details.exception, reason: details.library)) return;
    unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
  }

  /// Ошибка с причиной [reason]. [fatal] — для неперехваченных исключений.
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    if (!_enabled) return;
    if (!isFirstOccurrence(error, reason: reason)) return;
    unawaited(FirebaseCrashlytics.instance.recordError(
      error,
      // У Exception своего стека нет — берём место вызова, чтобы отчёты
      // группировались в консоли.
      stack ?? (error is Error ? error.stackTrace : null) ?? StackTrace.current,
      reason: reason,
      fatal: fatal,
    ));
  }
}
