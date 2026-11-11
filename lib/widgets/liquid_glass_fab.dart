import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/utils.dart';
import '../theme/app_colors.dart';

/// Плавающая кнопка действия с эффектом полированного жидкого стекла (Liquid Glass FAB).
///
/// Имеет насыщенный градиент на основе [ColorScheme.primary], световую фаску (specular rim),
/// тактильный отклик, рассеянное свечение и полную поддержку доступности (Semantics, Tooltip).
class LiquidGlassFab extends StatelessWidget {
  final VoidCallback onPressed;

  /// Долгое нажатие (голосовой ввод у «+»). Подсказка-tooltip тогда не
  /// показывается: она тоже открывается долгим нажатием и перебила бы его.
  final VoidCallback? onLongPress;

  /// Что делает долгое нажатие — для TalkBack.
  final String? longPressHint;
  final IconData icon;
  final double size;
  final String? tooltip;
  final String? semanticLabel;

  /// Непрозрачность градиентной заливки: меньше 1 — сквозь кнопку
  /// просвечивает стекло (центральная кнопка навбара).
  final double fillOpacity;

  const LiquidGlassFab({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.longPressHint,
    this.icon = Icons.add_rounded,
    this.size = 56.0,
    this.tooltip,
    this.semanticLabel,
    this.fillOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveTooltip = tooltip ?? context.l10n.new_transaction;
    final effectiveLabel = semanticLabel ?? effectiveTooltip;

    final primaryColor = colorScheme.primary;
    final secondaryColor = colorScheme.secondary;

    final button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35 * fillOpacity),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: AppColors.shadowBase.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipOval(
        child: Material(
          color: AppColors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: fillOpacity),
                  secondaryColor.withValues(alpha: fillOpacity),
                ],
              ),
              border: Border.all(
                color: AppColors.highlightBase.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onPressed();
              },
              onLongPress: onLongPress == null
                  ? null
                  : () {
                      HapticFeedback.heavyImpact();
                      onLongPress!();
                    },
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(
                  icon,
                  size: 28,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: effectiveLabel,
      onLongPressHint: onLongPress == null ? null : longPressHint,
      child: onLongPress == null
          ? Tooltip(message: effectiveTooltip, child: button)
          : button,
    );
  }
}
