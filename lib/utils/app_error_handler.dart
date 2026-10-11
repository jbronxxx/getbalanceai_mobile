import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:getbalanceai_mobile/widgets/widgets.dart';
import '../main.dart';

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
  static String getMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    return error.toString();
  }

  /// Показывает уведомление об ошибке пользователю.
  ///
  /// В случае истечения сессии (401 или специальные коды) отображает модальный диалог.
  static void show(BuildContext context, dynamic error, {String? title}) {
    if (isUserCanceled(error)) {
      AppLogger.i('[AppErrorHandler] Действие отменено пользователем');
      return;
    }

    final message = getMessage(error);

    if (error is DioException) {
      final data = error.response?.data;
      final code = (data is Map) ? data['code'] : null;

      final path = error.requestOptions.path;
      final isAuthEndpoint =
          path.contains('/auth/login') || path.contains('/auth/register');

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

        final customMsg = (data is Map &&
                data['message'] != null &&
                data['message'].toString().isNotEmpty)
            ? data['message'].toString()
            : LanguageManager.l10n.http_429;

        AppAlerts.showRateLimitDialog(
          context,
          title: title ?? LanguageManager.l10n.rate_limit_exceeded_title,
          message: customMsg,
          retryAfterSeconds: retrySeconds,
        );
        return;
      }

      // Обработка временной недоступности сервиса (HTTP 503 / SERVICE_UNAVAILABLE)
      if (error.response?.statusCode == 503 ||
          code == 'SERVICE_UNAVAILABLE' ||
          (data is Map && data['status'] == 'SERVICE_UNAVAILABLE')) {
        final customMsg = (data is Map &&
                data['message'] != null &&
                data['message'].toString().isNotEmpty)
            ? data['message'].toString()
            : null;
        AppAlerts.showServiceUnavailableDialog(
          context,
          message: customMsg,
        );
        return;
      }
    }

    AppAlerts.error(context, message, title: title);
  }

  /// Обрабатывает исключения Dio и возвращает локализованное сообщение.
  static String _handleDioError(DioException error) {
    String message = LanguageManager.l10n.server_error_general;

    if (error.response != null) {
      final data = error.response?.data;

      if (data is Map) {
        // Извлечение сообщения из унифицированного контракта ErrorResponse
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          message = data['message'].toString();
        } else if (data['code'] == 'RATE_LIMIT_EXCEEDED' ||
            data['status'] == 'RATE_LIMIT_EXCEEDED' ||
            error.response?.statusCode == 429) {
          message = LanguageManager.l10n.http_429;
        } else if (data['code'] == 'SERVICE_UNAVAILABLE' ||
            data['status'] == 'SERVICE_UNAVAILABLE' ||
            error.response?.statusCode == 503) {
          message = LanguageManager.l10n.http_503;
        }

        // Обработка детальных ошибок валидации (VALIDATION_ERROR)
        final String? code = data['code'];
        if (code == 'VALIDATION_ERROR' && data['details']?['fields'] != null) {
          try {
            final fields = data['details']['fields'] as Map;
            if (fields.isNotEmpty) {
              final firstError = fields.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                message = firstError.first.toString();
              } else {
                message = firstError.toString();
              }
            }
          } catch (_) {}
        }
      } else {
        // Резервный механизм на основе HTTP статус-кодов
        switch (error.response?.statusCode) {
          case 400:
            message = LanguageManager.l10n.http_400;
            break;
          case 401:
            message = LanguageManager.l10n.http_401;
            break;
          case 403:
            message = LanguageManager.l10n.http_403;
            break;
          case 404:
            message = LanguageManager.l10n.http_404;
            break;
          case 429:
            message = LanguageManager.l10n.http_429;
            break;
          case 500:
            message = LanguageManager.l10n.http_500;
            break;
          case 503:
            message = LanguageManager.l10n.http_503;
            break;
          default:
            message =
                '${LanguageManager.l10n.server_error_code}: ${error.response?.statusCode}';
        }
      }
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
