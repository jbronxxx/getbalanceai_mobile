import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Кастомный виджет Pull-to-Refresh в стиле Liquid Glass / Material 3.
///
/// Основной контент (карточки и списки) зафиксирован на месте и не съезжает вниз,
/// а индикатор обновления отображается в виде элегантной плавающей стеклянной капсулы
/// непосредственно под хэдером экрана.
class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? pullText;
  final String? releaseText;
  final String? refreshingText;

  /// Цвет спиннера и текста; по умолчанию — `AppColors.accentText`.
  final Color? foregroundColor;
  final bool releaseImmediately;
  final double? topPadding;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.pullText,
    this.releaseText,
    this.refreshingText,
    this.foregroundColor,
    this.releaseImmediately = false,
    this.topPadding,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _animTween;
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  bool _canRefresh = false;

  // Порог, после которого срабатывает обновление
  static const double _refreshThreshold = 90.0;
  // Максимальное растяжение
  static const double _maxDragOffset = 150.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _controller.addListener(() {
      if (_animTween != null) {
        setState(() {
          _dragOffset = _animTween!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    // Срабатывает только на основном скролл-вью (глубина 0), игнорируя внутренние списки
    if (notification.depth != 0) return false;

    if (notification is OverscrollNotification) {
      if (notification.overscroll < 0 && notification.dragDetails != null) {
        setState(() {
          // Натяжение с коэффициентом сопротивления 0.5 (эффект тугой нативной резины)
          _dragOffset = (_dragOffset - notification.overscroll * 0.5)
              .clamp(0.0, _maxDragOffset);

          final newCanRefresh = _dragOffset > _refreshThreshold;
          if (newCanRefresh != _canRefresh) {
            _canRefresh = newCanRefresh;
            if (_canRefresh) {
              HapticFeedback
                  .lightImpact(); // Легкая вибрация при пересечении порога активации
            }
          }
        });
      }
    } else if (notification is ScrollUpdateNotification) {
      // Плавное уменьшение смещения, если пользователь ведет палец обратно вверх до того, как отпустить
      if (_dragOffset > 0 &&
          notification.scrollDelta != null &&
          notification.metrics.pixels <= 0 &&
          notification.dragDetails != null) {
        setState(() {
          _dragOffset = (_dragOffset - notification.scrollDelta!)
              .clamp(0.0, _maxDragOffset);
          if (_dragOffset <= 0) _canRefresh = false;
        });
      }
    } else if (notification is ScrollEndNotification) {
      // Гарантированно отлавливает завершение жеста на всех платформах
      if (_canRefresh) {
        _startRefresh();
      } else if (_dragOffset > 0) {
        _animateTo(0.0);
      }
    } else if (notification is UserScrollNotification) {
      // Срабатывает ровно в момент, когда пользователь полностью убрал палец с экрана (состояние idle)
      if (notification.direction == ScrollDirection.idle) {
        if (_canRefresh) {
          _startRefresh();
        } else if (_dragOffset > 0) {
          _animateTo(0.0);
        }
      }
    }
    return false;
  }

  Future<void> _startRefresh() async {
    AppLogger.d('[CustomPullToRefresh] Starting refresh...');
    setState(() {
      _isRefreshing = true;
      _canRefresh = false;
    });

    HapticFeedback.mediumImpact(); // Подтверждающая вибрация старта загрузки

    if (widget.releaseImmediately) {
      // Плавно возвращаем шторку на исходную позицию сразу при старте запроса
      _animateTo(0.0);
      try {
        await widget.onRefresh();
      } finally {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
        }
      }
    } else {
      // Фиксируем шторку на уровне порога на время выполнения асинхронного метода
      _animateTo(_refreshThreshold);

      try {
        await widget.onRefresh();
      } finally {
        if (mounted) {
          setState(() {
            _isRefreshing = false;
          });
          _animateTo(0.0);
        }
      }
    }
  }

  void _animateTo(double target) {
    final double start = _dragOffset;
    if ((start - target).abs() < 0.1) {
      setState(() => _dragOffset = target);
      return;
    }

    _animTween = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTopPadding = (widget.topPadding ?? 20.0) + 8.0;
    final bool showIndicator = _dragOffset > 0 || _isRefreshing;
    final double progress = (_dragOffset / _refreshThreshold).clamp(0.0, 1.0);
    final double indicatorTop = effectiveTopPadding + (progress * 18.0);

    return Stack(
      children: [
        // Основной контент экрана: остается зафиксированным на месте без сдвига вниз
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: widget.child,
        ),
        // Плавающая стеклянная капсула обновления (Liquid Glass / Material 3 Pill)
        if (showIndicator)
          Positioned(
            top: indicatorTop,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity:
                      _isRefreshing ? 1.0 : (progress * 1.5).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.85 + (progress * 0.15),
                    child: _buildFloatingPill(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingPill(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final colors = AppColors.of(context);
    final foreground = widget.foregroundColor ?? colors.accentText;
    final pillBg = colors.pillBackground;

    final borderColor = isDark
        ? AppColors.highlightBase.withValues(alpha: 0.16)
        : colors.brandGradientStart.withValues(alpha: 0.22);

    final shadowColor = isDark
        ? AppColors.shadowBase.withValues(alpha: 0.35)
        : AppColors.shadowBase.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRefreshing)
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(
                  foreground,
                ),
              ),
            )
          else
            AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _canRefresh ? 0.5 : 0.0,
              child: Icon(
                Icons.arrow_downward_rounded,
                color: foreground,
                size: 16,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            _isRefreshing
                ? (widget.refreshingText ?? context.l10n.refreshing_data)
                : (_canRefresh
                    ? (widget.releaseText ?? context.l10n.release_to_refresh)
                    : (widget.pullText ?? context.l10n.pull_to_refresh)),
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: AppFontSize.caption,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
