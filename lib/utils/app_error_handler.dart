import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:getbalanceai_mobile/services/services.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import '../config/api_config.dart';

/// Централизованный обработчик ошибок приложения.
///
/// Отвечает за преобразование технических исключений (сетевых, серверных)
/// в понятные пользователю сообщения и их отображение в UI.
class AppErrorHandler {
  /// Проверяет, является ли исключение результатом отмены действия пользователем
  /// (например, закрытие системного окна авторизации Google или Apple).
  static bool isUserCanceled(dynamic error) {
    if (error == null || error is DioException) return false;

    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled;
    }

    if (error is SignInWithAppleAuthorizationException) {
      return error.code == AuthorizationErrorCode.canceled;
    }

    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = error.message?.toLowerCase() ?? '';
      return code == 'sign_in_canceled' ||
          code == 'canceled' ||
          code == 'cancelled' ||
          code == '12501' ||
          code == '16' ||
          message.contains('canceled') ||
          message.contains('cancelled');
    }

    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('googlesigninexceptioncode.canceled') ||
        errorStr.contains('authorizationerrorcode.canceled') ||
        errorStr.contains('sign_in_canceled') ||
        errorStr.contains('12501') ||
        (errorStr.contains('google') &&
            (errorStr.contains('canceled') ||
                errorStr.contains('cancelled'))) ||
        (errorStr.contains('apple') &&
            (errorStr.contains('canceled') || errorStr.contains('cancelled')));
  }

  /// Возвращает текстовое сообщение на основе типа ошибки.
  ///
  /// Для неизвестных исключений — общий локализованный текст: сырой
  /// `toString()` пользователю не показывается, детали уходят в лог.
  static String getMessage(dynamic error) {
    if (error is SyncException) {
      final cause = error.cause;
      if (cause is DioException) return _handleDioError(cause);
      return error.getLocalizedMessage();
    }
    if (error is DioException) {
      return _handleDioError(error);
    }
    AppLogger.e('[AppErrorHandler] Необработанная ошибка', error);
    CrashReporter.recordError(error, null, reason: 'shown to user');
    return LanguageManager.l10n.err_unexpected;
  }

  static bool _isTermsNotAccepted(dynamic error) {
    final dioError = error is SyncException ? error.cause : error;
    if (dioError is! DioException) return false;
    final data = dioError.response?.data;
    return data is Map && data['code'] == 'TERMS_NOT_ACCEPTED';
  }

  /// Показывает уведомление об ошибке пользователю.
  ///
  /// В случае истечения сессии (401 или специальные коды) отображает модальный диалог.
  static void show(BuildContext context, dynamic error, {String? title}) {
    if (isUserCanceled(error)) {
      AppLogger.i('[AppErrorHandler] Действие отменено пользователем');
      return;
    }

    // Не принята новая версия соглашения: вместо сообщения — экран новой
    // версии (LegalConsentGate), его открывает ответ сервера
    if (_isTermsNotAccepted(error)) return;

    final message = getMessage(error);

    if (error is SyncException) {
      if (error.code == SyncErrorCode.unauthorized) {
        AppAlerts.showErrorDialog(
          context,
          title: LanguageManager.l10n.session_expired_title,
          message: LanguageManager.l10n.session_expired_desc,
          onPressed: () {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        );
        return;
      }
      // Синк упал на запросе: 429, 503, сеть показываются как у любого
      // запроса, а не «Ошибка синхронизации: 429».
      final cause = error.cause;
      if (cause is DioException) {
        show(context, cause, title: title);
        return;
      }
      AppAlerts.error(context, message,
          title: title ?? LanguageManager.l10n.sync_error);
      return;
    }

    if (error is DioException) {
      final data = error.response?.data;
      final code = (data is Map) ? data['code'] : null;

      // 401 на входе — отказ провайдера, а не конец сессии
      final path = error.requestOptions.path;
      final isAuthEndpoint = path.contains(ApiConfig.loginGoogle) ||
          path.contains(ApiConfig.loginApple);

      // Обработка истечения срока действия сессии (только для защищенных запросов)
      if (!isAuthEndpoint &&
          (error.response?.statusCode == 401 ||
              code == 'EXPIRED_TOKEN' ||
              code == 'INVALID_TOKEN' ||
              code == 'TOKEN_REVOKED')) {
        AppAlerts.showErrorDialog(
          context,
          title: LanguageManager.l10n.session_expired_title,
          message: LanguageManager.l10n.session_expired_desc,
          onPressed: () {
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        );
        return;
      }

      // Обработка превышения лимита запросов (HTTP 429 / RATE_LIMIT_EXCEEDED)
      if (error.response?.statusCode == 429 ||
          code == 'RATE_LIMIT_EXCEEDED' ||
          (data is Map && data['status'] == 'RATE_LIMIT_EXCEEDED')) {
        final retryAfterHeader = error.response?.headers.value('retry-after');
        final retrySeconds = retryAfterHeader != null
            ? int.tryParse(retryAfterHeader.trim())
            : null;

        AppAlerts.showRateLimitDialog(
          context,
          title: title ?? LanguageManager.l10n.rate_limit_exceeded_title,
          message: LanguageManager.l10n.http_429,
          retryAfterSeconds: retrySeconds,
        );
        return;
      }

      // Обработка временной недоступности сервиса (HTTP 503 / SERVICE_UNAVAILABLE)
      if (error.response?.statusCode == 503 ||
          code == 'SERVICE_UNAVAILABLE' ||
          (data is Map && data['status'] == 'SERVICE_UNAVAILABLE')) {
        AppAlerts.showServiceUnavailableDialog(context);
        return;
      }
    }

    AppAlerts.error(context, message, title: title);
  }

  /// Обрабатывает исключения Dio и возвращает локализованное сообщение.
  ///
  /// Текст ответа сервера (`message`, ошибки полей) пользователю не
  /// показывается: он для разработчика и не на языке интерфейса. Сообщение —
  /// по коду ошибки и HTTP-статусу из l10n.
  static String _handleDioError(DioException error) {
    String message;
    final response = error.response;

    if (response != null) {
      final data = response.data;
      final code = data is Map ? data['code'] ?? data['status'] : null;
      if (code == 'PLAN_LIMIT_REACHED') {
        return LanguageManager.l10n.plan_limit_reached;
      }
      if (code == 'RATE_LIMIT_EXCEEDED' || response.statusCode == 429) {
        return LanguageManager.l10n.http_429;
      }
      if (code == 'SERVICE_UNAVAILABLE' || response.statusCode == 503) {
        return LanguageManager.l10n.http_503;
      }
      message = switch (response.statusCode) {
        400 || 422 => LanguageManager.l10n.http_400,
        401 => LanguageManager.l10n.http_401,
        403 => LanguageManager.l10n.http_403,
        404 => LanguageManager.l10n.http_404,
        500 => LanguageManager.l10n.http_500,
        _ => LanguageManager.l10n.server_error_general,
      };
    } else {
      // Ошибки транспортного уровня (сеть, таймауты)
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          message = LanguageManager.l10n.err_connection_timeout;
          break;
        case DioExceptionType.sendTimeout:
          message = LanguageManager.l10n.err_send_timeout;
          break;
        case DioExceptionType.receiveTimeout:
          message = LanguageManager.l10n.err_receive_timeout;
          break;
        case DioExceptionType.connectionError:
          message = LanguageManager.l10n.err_connection_error;
          break;
        default:
          message = LanguageManager.l10n.err_network_default;
      }
    }

    return message;
  }
}
