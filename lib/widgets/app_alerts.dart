import 'package:getbalanceai_mobile/utils/utils.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';

enum AlertType { success, error, warning, info }

class AppAlerts {
  /// Отображает всплывающее уведомление (Toast) с кастомным дизайном.
  ///
  /// Поддерживает различные типы для визуальной дифференциации.
  static void showToast(
    BuildContext context, {
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    Color iconColor;
    IconData icon;

    switch (type) {
      case AlertType.success:
        iconColor = const Color(0xFF16A34A); // Green
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        iconColor = const Color(0xFFEF4444); // Red
        icon = Icons.error_rounded;
        break;
      case AlertType.warning:
        iconColor = const Color(0xFFF59E0B); // Amber
        icon = Icons.warning_rounded;
        break;
      case AlertType.info:
        iconColor = const Color(0xFF3B82F6); // Blue
        icon = Icons.info_rounded;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);

    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      padding: EdgeInsets.zero,
      content: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: title != null ? 13 : 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.close,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: messenger.hideCurrentSnackBar,
            ),
          ],
        ),
      ),
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void success(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.success);
  }

  static void error(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.error);
  }

  static void warning(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.warning);
  }

  static void info(BuildContext context, String message, {String? title}) {
    showToast(context, message: message, title: title, type: AlertType.info);
  }

  /// Уведомление об отсутствии сети. Единый стиль для всех экранов.
  static void noInternet(BuildContext context) {
    showToast(context,
        message: context.l10n.no_internet_connection, type: AlertType.warning);
  }

  /// Отображает критическое модальное окно, требующее действия пользователя.
  ///
  /// Используется для критических ошибок или важных системных уведомлений.
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    final effectiveButtonText = buttonText ?? context.l10n.dialog_ok;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFEF4444),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onPressed != null) onPressed();
                    },
                    child: Text(
                      effectiveButtonText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Отображает модальное окно недоступности сервиса (HTTP 503 / SERVICE_UNAVAILABLE).
  static void showServiceUnavailableDialog(
    BuildContext context, {
    String? title,
    String? message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.engineering_rounded,
                    color: Color(0xFFD97706),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title ?? context.l10n.service_unavailable_title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message ?? context.l10n.service_unavailable_desc,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (onRetry != null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        onRetry();
                      },
                      child: Text(
                        context.l10n.service_unavailable_retry,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      context.l10n.dialog_ok,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        context.l10n.dialog_ok,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Отображает модальное окно превышения лимита запросов (HTTP 429 / RATE_LIMIT_EXCEEDED).
  ///
  /// При наличии [retryAfterSeconds] запускает локальный таймер обратного отсчета,
  /// информирующий пользователя об оставшемся времени блокировки.
  static void showRateLimitDialog(
    BuildContext context, {
    String? title,
    String? message,
    int? retryAfterSeconds,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _RateLimitDialogContent(
              title: title ?? context.l10n.rate_limit_exceeded_title,
              message: message ?? context.l10n.http_429,
              retryAfterSeconds: retryAfterSeconds,
              onRetry: onRetry,
            ),
          ),
        );
      },
    );
  }
}

/// Внутренний виджет диалога лимита запросов с таймером обратного отсчета.
class _RateLimitDialogContent extends StatefulWidget {
  final String title;
  final String message;
  final int? retryAfterSeconds;
  final VoidCallback? onRetry;

  const _RateLimitDialogContent({
    required this.title,
    required this.message,
    this.retryAfterSeconds,
    this.onRetry,
  });

  @override
  State<_RateLimitDialogContent> createState() =>
      _RateLimitDialogContentState();
}

class _RateLimitDialogContentState extends State<_RateLimitDialogContent> {
  int _secondsLeft = 0;
  StreamSubscription<int>? _timerSubscription;

  @override
  void initState() {
    super.initState();
    final initial = widget.retryAfterSeconds;
    if (initial != null && initial > 0) {
      _secondsLeft = initial;
      // Запуск посекундного декремента счетчика до нуля
      _timerSubscription =
          Stream.periodic(const Duration(seconds: 1), (i) => i).listen((_) {
        if (!mounted) return;
        if (_secondsLeft > 1) {
          setState(() => _secondsLeft--);
        } else {
          setState(() {
            _secondsLeft = 0;
          });
          _timerSubscription?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFFEF3C7),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_bottom_rounded,
            color: Color(0xFFD97706),
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          widget.message,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.retryAfterSeconds != null &&
            widget.retryAfterSeconds! > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _secondsLeft > 0
                      ? Icons.timer_outlined
                      : Icons.check_circle_outline,
                  size: 18,
                  color: AppTheme.warningAmber,
                ),
                const SizedBox(width: 8),
                Text(
                  _secondsLeft > 0
                      ? '${context.l10n.rate_limit_countdown_prefix} $_secondsLeft ${context.l10n.uzs_symbol == 'сум' ? 'сек.' : 'sec'}'
                      : context.l10n.rate_limit_ready,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (widget.onRetry != null && _secondsLeft == 0) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRetry!();
              },
              child: Text(
                context.l10n.service_unavailable_retry,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.dialog_ok,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.l10n.dialog_ok,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
