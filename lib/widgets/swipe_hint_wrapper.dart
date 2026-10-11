import 'dart:async';
import 'package:flutter/material.dart';

/// Обертка, которая делает короткую анимацию «подглядывания» (peek),
/// плавно сдвигая элемент влево и возвращая назад, чтобы показать пользователю,
/// что элемент поддерживается свайп-удаление.
class SwipeHintWrapper extends StatefulWidget {
  final Widget child;
  final bool showHint;
  final Widget? background;
  final BorderRadius? borderRadius;
  final VoidCallback? onHintShown;

  const SwipeHintWrapper({
    super.key,
    required this.child,
    this.showHint = false,
    this.background,
    this.borderRadius,
    this.onHintShown,
  });

  @override
  State<SwipeHintWrapper> createState() => _SwipeHintWrapperState();
}

class _SwipeHintWrapperState extends State<SwipeHintWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  bool _hasStarted = false;
  bool _isCompleted = false;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _isCompleted = true;
        });
      }
    });

    _animation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.2, 0.0))
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(-0.2, 0.0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);

    if (widget.showHint) {
      _startHint();
    }
  }

  @override
  void didUpdateWidget(SwipeHintWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showHint && !_hasStarted) {
      _startHint();
    }
  }

  void _startHint() {
    _hasStarted = true;
    widget.onHintShown?.call();
    _startTimer?.cancel();
    _startTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStarted || _isCompleted) return widget.child;

    return Stack(
      children: [
        if (widget.background != null)
          Positioned.fill(
            child: widget.borderRadius != null
                ? ClipRRect(
                    borderRadius: widget.borderRadius!,
                    child: widget.background!,
                  )
                : widget.background!,
          ),
        SlideTransition(
          position: _animation,
          child: widget.child,
        ),
      ],
    );
  }
}
