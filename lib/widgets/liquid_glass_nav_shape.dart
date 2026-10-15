import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Форма островка навигации: капсула, верхний край которой плавно огибает
/// центральную кнопку дугой.
///
/// Прямоугольник формы включает высоту подъёма [bumpHeight]: сама капсула
/// начинается на `bumpHeight` ниже верхнего края, а дуга радиуса
/// [bumpRadius] касается верхнего края. Переходы от прямого края к дуге
/// скруглены радиусом [filletRadius]. При `bumpRadius == 0` — обычная капсула.
class LiquidGlassNavShape extends ShapeBorder {
  final double bumpRadius;
  final double bumpHeight;
  final double filletRadius;
  final double cornerRadius;
  final BorderSide side;

  const LiquidGlassNavShape({
    this.bumpRadius = 0,
    this.bumpHeight = 0,
    this.filletRadius = 10,
    this.cornerRadius = 34,
    this.side = BorderSide.none,
  });

  bool get _hasBump => bumpRadius > 0 && bumpHeight > 0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) => LiquidGlassNavShape(
        bumpRadius: bumpRadius * t,
        bumpHeight: bumpHeight * t,
        filletRadius: filletRadius * t,
        cornerRadius: cornerRadius * t,
        side: side.scale(t),
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final top = rect.top + (_hasBump ? bumpHeight : 0);
    final bar = Rect.fromLTRB(rect.left, top, rect.right, rect.bottom);
    final radius = math.min(cornerRadius, bar.height / 2);

    final path = Path()..moveTo(bar.left + radius, bar.top);

    if (_hasBump) {
      // Центр дуги: дуга касается верхнего края прямоугольника формы.
      final center = Offset(rect.center.dx, rect.top + bumpRadius);
      final r = filletRadius;
      // Скругление касается прямого края сверху и дуги снаружи:
      // |от центра скругления до центра дуги| = bumpRadius + r.
      final dy = center.dy - (top - r);
      final dx = math.sqrt(math.max(
        0,
        math.pow(bumpRadius + r, 2) - dy * dy,
      ));
      final filletLeft = Offset(center.dx - dx, top - r);
      final filletRight = Offset(center.dx + dx, top - r);
      Offset touch(Offset fillet) =>
          fillet + (center - fillet) * (r / (bumpRadius + r));

      path
        ..lineTo(filletLeft.dx, top)
        ..arcToPoint(touch(filletLeft),
            radius: Radius.circular(r), clockwise: false)
        ..arcToPoint(touch(filletRight),
            radius: Radius.circular(bumpRadius), clockwise: true)
        ..arcToPoint(Offset(filletRight.dx, top),
            radius: Radius.circular(r), clockwise: false);
    }

    path
      ..lineTo(bar.right - radius, bar.top)
      ..arcToPoint(Offset(bar.right, bar.top + radius),
          radius: Radius.circular(radius))
      ..lineTo(bar.right, bar.bottom - radius)
      ..arcToPoint(Offset(bar.right - radius, bar.bottom),
          radius: Radius.circular(radius))
      ..lineTo(bar.left + radius, bar.bottom)
      ..arcToPoint(Offset(bar.left, bar.bottom - radius),
          radius: Radius.circular(radius))
      ..lineTo(bar.left, bar.top + radius)
      ..arcToPoint(Offset(bar.left + radius, bar.top),
          radius: Radius.circular(radius))
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2)),
      side.toPaint(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassNavShape &&
      other.bumpRadius == bumpRadius &&
      other.bumpHeight == bumpHeight &&
      other.filletRadius == filletRadius &&
      other.cornerRadius == cornerRadius &&
      other.side == side;

  @override
  int get hashCode =>
      Object.hash(bumpRadius, bumpHeight, filletRadius, cornerRadius, side);
}
