import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/utils.dart';
import '../theme/app_colors.dart';

/// Плавающая кнопка действия с эффектом полированного жидкого стекла (Liquid Glass FAB).
///
/// Имеет насыщенный градиент на основе [ColorScheme.primary], световую фаску (specular rim),
/// тактильный отклик, рассеянное свечение и полную поддержку доступности (Semantics, Tooltip).
///
/// С [onLongPress] кнопка сжимается до 0,9, пока её держат, — к моменту
/// срабатывания долгого нажатия; [pulseOnMount] — короткий пульс иконки
/// после появления (один раз за монтирование), чтобы кнопку заметили.
class LiquidGlassFab extends StatefulWidget {
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

  /// Пульс иконки один раз после появления кнопки.
  final bool pulseOnMount;

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
    this.pulseOnMount = false,
  });

  /// Насколько сжимается удерживаемая кнопка.
  static const double heldScale = 0.9;

  /// Пауза после появления и длительность пульса иконки.
  static const pulseDelay = Duration(milliseconds: 600);
  static const pulseDuration = Duration(milliseconds: 900);

  @override
  State<LiquidGlassFab> createState() => _LiquidGlassFabState();
}

class _LiquidGlassFabState extends State<LiquidGlassFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: LiquidGlassFab.pulseDuration,
  );

  /// Увеличение — уменьшение — меньшее увеличение — покой.
  late final Animation<double> _pulseScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.12), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 25),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  Timer? _pulseTimer;
  bool _held = false;

  @override
  void initState() {
    super.initState();
    if (widget.pulseOnMount) {
      _pulseTimer = Timer(LiquidGlassFab.pulseDelay, () {
        // Системная настройка «убрать анимации» — без пульса
        if (!mounted || MediaQuery.maybeDisableAnimationsOf(context) == true) {
          return;
        }
        _pulse.forward();
      });
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    final onLongPress = widget.onLongPress;
    final icon = widget.icon;
    final size = widget.size;
    final fillOpacity = widget.fillOpacity;
    final longPressHint = widget.longPressHint;
    final tooltip = widget.tooltip;
    final semanticLabel = widget.semanticLabel;
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
              // Вибрацию долгого нажатия даёт сам InkWell — системная
              // LONG_PRESS (HapticFeedback.vibrate). heavyImpact на Android —
              // CONTEXT_CLICK, слабый тик: он перебивал её и ощущался слабее
              // тапа по вкладкам (lightImpact — VIRTUAL_KEY)
              onLongPress: onLongPress,
              // Удержание: кнопка сжимается к моменту срабатывания долгого
              // нажатия и возвращается, когда палец отпущен
              onHighlightChanged: onLongPress == null
                  ? null
                  : (held) => setState(() => _held = held),
              customBorder: const CircleBorder(),
              child: Center(
                child: ScaleTransition(
                  scale: _pulseScale,
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
      ),
    );

    return Semantics(
      button: true,
      label: effectiveLabel,
      onLongPressHint: onLongPress == null ? null : longPressHint,
      child: onLongPress == null
          ? Tooltip(message: effectiveTooltip, child: button)
          : AnimatedScale(
              key: const ValueKey('fab_hold_scale'),
              scale: _held ? LiquidGlassFab.heldScale : 1.0,
              duration: _held ? kLongPressTimeout : _releaseDuration,
              curve: Curves.easeOut,
              child: button,
            ),
    );
  }
}

const _releaseDuration = Duration(milliseconds: 150);
