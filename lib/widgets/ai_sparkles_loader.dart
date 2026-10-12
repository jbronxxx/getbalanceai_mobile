import 'package:flutter/material.dart';

/// Виджет анимированного лоадера генерации контента ИИ (пульсирующие звёздочки).
/// Заменяет стандартный индикатор загрузки на общепринятую анимацию генерации ИИ.
class AiSparklesLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const AiSparklesLoader({
    super.key,
    this.size = 54.0,
    this.color,
  });

  @override
  State<AiSparklesLoader> createState() => _AiSparklesLoaderState();
}

class _AiSparklesLoaderState extends State<AiSparklesLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.14).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowAnimation = Tween<double>(begin: 10.0, end: 24.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;

    return Center(
      key: const Key('ai_sparkles_loader'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: widget.size + 24,
                height: widget.size + 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: 0.10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(
                        alpha: 0.20 * _opacityAnimation.value,
                      ),
                      blurRadius: _glowAnimation.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: widget.size,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
