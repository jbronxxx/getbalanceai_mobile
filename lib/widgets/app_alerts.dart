import 'dart:async';
import 'package:flutter/material.dart';
import 'package:getbalanceai_mobile/utils/utils.dart';
import '../theme/app_theme.dart';
import 'glass_container.dart';
import 'liquid_glass_nav_bar.dart';

enum AlertType { success, error, warning, info }

class AppAlerts {
  /// Отображает всплывающее уведомление (Toast) с кастомным дизайном в стиле Liquid Glass.
  ///
  /// Имеет размытие заднего плана (BackdropFilter), тонкую световую фаску (specular rim)
  /// и неоновое рассеянное свечение соответствующего цвета.
  static void showToast(
    BuildContext context, {
    required String message,
    String? title,
    AlertType type = AlertType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassTheme = GlassTheme.of(context);

    Color iconColor;
    IconData icon;

    switch (type) {
      case AlertType.success:
        iconColor = AppTheme.successGreen;
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        iconColor = colorScheme.error;
        icon = Icons.error_rounded;
        break;
      case AlertType.warning:
        iconColor = AppTheme.warningOrange;
        icon = Icons.warning_rounded;
        break;
      case AlertType.info:
        iconColor = colorScheme.primary;
        icon = Icons.info_rounded;
        break;
    }

    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: LiquidGlassNavBar.totalHeight(context) +
            LiquidGlassNavBar.centerActionLift +
            8.0,
        top: 8,
      ),
      content: GlassContainer(
        borderRadius: 22,
        blurSigma: 20,
        color: glassTheme.toastSurface,
        border: Border.all(
          color: glassTheme.toastRim,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: isDark ? 24 : 14,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
          if (isDark)
            BoxShadow(
              color: iconColor.withValues(alpha: 0.30),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    iconColor.withValues(alpha: isDark ? 0.35 : 0.22),
                    iconColor.withValues(alpha: isDark ? 0.12 : 0.08),
                  ],
                ),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: title != null ? 12.5 : 13.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

  /// Отображает модальное окно подтверждения действия в стиле Liquid Glass.
  ///
  /// Возвращает `true`, если пользователь подтвердил действие, `false` или `null` при отмене.
  /// [isDestructive] определяет стиль акцентной кнопки (красный для деструктивных действий).
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final effectiveConfirmText = confirmText ?? l10n.dialog_ok;
    final effectiveCancelText = cancelText ?? l10n.cancel;
    final effectiveIcon = icon ??
        (isDestructive ? Icons.warning_rounded : Icons.help_outline_rounded);
    final accentColor = isDestructive ? colorScheme.error : colorScheme.primary;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _LiquidGlassDialog(
          glowColor: accentColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LiquidAlertIconBadge(
                icon: effectiveIcon,
                color: accentColor,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScaler = MediaQuery.textScalerOf(context);
                  final confirmPainter = TextPainter(
                    text: TextSpan(
                      text: effectiveConfirmText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                    textScaler: textScaler,
                    maxLines: 1,
                  )..layout();

                  final cancelPainter = TextPainter(
                    text: TextSpan(
                      text: effectiveCancelText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                    textScaler: textScaler,
                    maxLines: 1,
                  )..layout();

                  // При горизонтальном расположении кнопки делят доступную ширину поровну.
                  // Каждая кнопка должна вмещать текст плюс внутренние отступы (минимум 24px).
                  final maxButtonWidthNeeded = [
                    confirmPainter.width + 24,
                    cancelPainter.width + 24,
                  ].reduce((a, b) => a > b ? a : b);

                  final totalWidthNeeded = (maxButtonWidthNeeded * 2) + 12;
                  final shouldStackVertically =
                      constraints.maxWidth < totalWidthNeeded ||
                          effectiveConfirmText.length > 12 ||
                          effectiveCancelText.length > 12;

                  if (shouldStackVertically) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: isDestructive
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                effectiveConfirmText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.onSurface,
                              side: BorderSide(
                                color:
                                    colorScheme.outline.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                effectiveCancelText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.onSurface,
                              side: BorderSide(
                                color:
                                    colorScheme.outline.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                effectiveCancelText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: isDestructive
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                effectiveConfirmText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
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
        final errorColor = Theme.of(context).colorScheme.error;
        return _LiquidGlassDialog(
          glowColor: errorColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LiquidAlertIconBadge(
                icon: Icons.warning_rounded,
                color: errorColor,
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
        return _LiquidGlassDialog(
          glowColor: AppTheme.warningAmber,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LiquidAlertIconBadge(
                icon: Icons.engineering_rounded,
                color: AppTheme.warningAmber,
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
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
        return _LiquidGlassDialog(
          glowColor: AppTheme.warningAmber,
          child: _RateLimitDialogContent(
            title: title ?? context.l10n.rate_limit_exceeded_title,
            message: message ?? context.l10n.http_429,
            retryAfterSeconds: retryAfterSeconds,
            onRetry: onRetry,
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
        const _LiquidAlertIconBadge(
          icon: Icons.hourglass_bottom_rounded,
          color: AppTheme.warningAmber,
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

class _LiquidGlassDialog extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const _LiquidGlassDialog({
    required this.child,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassTheme = GlassTheme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        side: BorderSide.none,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: GlassContainer(
        borderRadius: 28,
        blurSigma: 24,
        color: glassTheme.toastSurface,
        border: Border.all(
          color: glassTheme.toastRim,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.08),
            blurRadius: isDark ? 32 : 16,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          if (isDark)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.22),
              blurRadius: 40,
              spreadRadius: 2,
            ),
        ],
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class _LiquidAlertIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LiquidAlertIconBadge({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.32 : 0.18),
            color.withValues(alpha: isDark ? 0.10 : 0.04),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.45 : 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          color: color,
          size: 32,
        ),
      ),
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
