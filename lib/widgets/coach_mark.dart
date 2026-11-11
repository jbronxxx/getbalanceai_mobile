import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'whole_words_text.dart';

/// Подсказка-указатель поверх всего экрана: затемнение с «окном» и кольцом
/// вокруг [target], над ним — карточка с текстом и стрелкой вниз.
/// Закрывается тапом в любом месте.
abstract final class CoachMark {
  /// Показывает подсказку в корневом оверлее и возвращает функцию, которая
  /// её закрывает (для экрана, который уходит раньше тапа); без размеров
  /// цели (виджет ещё не отрисован) не показывает и возвращает `null`.
  static VoidCallback? show(
    BuildContext context, {
    required GlobalKey target,
    required String message,
    VoidCallback? onDismissed,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final targetBox = target.currentContext?.findRenderObject();
    final overlayBox = overlay.context.findRenderObject();
    if (targetBox is! RenderBox ||
        !targetBox.hasSize ||
        overlayBox is! RenderBox) {
      return null;
    }
    final rect = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
        targetBox.size;
    late final OverlayEntry entry;
    var open = true;
    void close() {
      if (!open) return;
      open = false;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => CoachMarkLayer(
        targetRect: rect,
        message: message,
        onDismiss: () {
          close();
          onDismissed?.call();
        },
      ),
    );
    overlay.insert(entry);
    return close;
  }
}

/// Слой подсказки: отдельный виджет, чтобы проверять вёрстку в тестах.
class CoachMarkLayer extends StatelessWidget {
  final Rect targetRect;
  final String message;
  final VoidCallback onDismiss;

  const CoachMarkLayer({
    super.key,
    required this.targetRect,
    required this.message,
    required this.onDismiss,
  });

  /// Зазор между целью и кольцом.
  static const double ringGap = 8;
  static const double _arrowSize = 10;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final screen = MediaQuery.sizeOf(context);
    final ringRadius = targetRect.shortestSide / 2 + ringGap;
    final bubbleBottom =
        screen.height - (targetRect.center.dy - ringRadius) + _arrowSize + 6;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
      child: Semantics(
        key: const ValueKey('coach_mark'),
        container: true,
        button: true,
        label: message,
        onTap: onDismiss,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScrimPainter(
                    center: targetRect.center,
                    radius: ringRadius,
                    scrim: AppColors.shadowBase.withValues(alpha: 0.55),
                    ring: AppColors.highlightBase.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: bubbleBottom,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.sheetBackground,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: colors.sheetBorder),
                      boxShadow: [
                        BoxShadow(
                          color: colors.sheetShadow,
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: WholeWordsText(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: targetRect.center.dx - _arrowSize,
                bottom: bubbleBottom - _arrowSize + 1,
                child: CustomPaint(
                  size: const Size(_arrowSize * 2, _arrowSize),
                  painter: _ArrowPainter(colors.sheetBackground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Затемнение с круглым окном и светлым кольцом вокруг цели.
class _ScrimPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color scrim;
  final Color ring;

  const _ScrimPainter({
    required this.center,
    required this.radius,
    required this.scrim,
    required this.ring,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      hole,
    );
    canvas.drawPath(dim, Paint()..color = scrim);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.center != center ||
      old.radius != radius ||
      old.scrim != scrim ||
      old.ring != ring;
}

/// Стрелка карточки вниз, к цели.
class _ArrowPainter extends CustomPainter {
  final Color color;

  const _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}
