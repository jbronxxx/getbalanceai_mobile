import 'package:getbalanceai_mobile/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

/// Кастомный виджет Pull-to-Refresh с эффектом «протягивания» всего контента
/// и отображением подложки под ним.
class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? pullText;
  final String? releaseText;
  final String? refreshingText;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool releaseImmediately;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.pullText,
    this.releaseText,
    this.refreshingText,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.foregroundColor = const Color(0xFF0F766E),
    this.releaseImmediately = false,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
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
      duration: const Duration(
          milliseconds: 600), // Плавная кинематографическая анимация возврата
    );
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
    _controller.reset();

    // Используем более плавную и вязкую кривую вместо прыгучего elasticOut
    final curve = target == 0.0 ? Curves.easeOutBack : Curves.easeOutCubic;

    final animation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );
    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Нижний слой (Подложка)
        Container(
          color: widget.backgroundColor == const Color(0xFFF1F5F9)
              ? Theme.of(context).colorScheme.surface
              : widget.backgroundColor,
          width: double.infinity,
          height: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: _maxDragOffset,
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _canRefresh ? 0.5 : 0.0,
                    child: Icon(
                      _isRefreshing ? Icons.sync : Icons.arrow_downward,
                      color: widget.foregroundColor.withValues(alpha: 0.7),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRefreshing
                        ? (widget.refreshingText ??
                            context.l10n.refreshing_data)
                        : (_canRefresh
                            ? (widget.releaseText ??
                                context.l10n.release_to_refresh)
                            : (widget.pullText ??
                                context.l10n.pull_to_refresh)),
                    style: TextStyle(
                      color: widget.foregroundColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Верхний слой (Контент), который сдвигается
        Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                if (_dragOffset > 0)
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .shadow
                        .withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, -2),
                  ),
              ],
              borderRadius: BorderRadius.vertical(
                top: Radius.circular((_dragOffset / 5).clamp(0.0, 32.0)),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular((_dragOffset / 5).clamp(0.0, 32.0)),
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
