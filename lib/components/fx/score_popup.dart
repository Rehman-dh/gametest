import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;

/// Points earned, popping up where they were won: the number swells in,
/// floats upward and fades.
class ScorePopup extends PositionComponent {
  ScorePopup({required this.points, required Vector2 at, required this.color})
    : super(position: at, priority: 60);

  final int points;
  final Color color;

  static const _life = 1.3;
  double _age = 0;

  late final TextPainter _fill = _painter(Paint()..color = color);
  late final TextPainter _stroke = _painter(
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.14
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2B1A0E),
  );

  TextPainter _painter(Paint paint) => TextPainter(
    text: TextSpan(
      text: '$points',
      style: TextStyle(
        fontSize: points >= 5000 ? 1.3 : 0.9,
        fontWeight: FontWeight.w900,
        foreground: paint,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void update(double dt) {
    _age += dt;
    position.y -= dt * 1.6;
    if (_age > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _age / _life;
    // Pop in bigger, settle, then fade over the last third.
    final pop = t < 0.15 ? 0.6 + t / 0.15 * 0.6 : 1.2 - (t - 0.15) * 0.25;
    final alpha = t < 0.66 ? 1.0 : (1 - t) / 0.34;
    canvas
      ..save()
      ..scale(pop)
      ..translate(-_fill.width / 2, -_fill.height / 2)
      ..saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)),
      );
    _stroke.paint(canvas, Offset.zero);
    _fill.paint(canvas, Offset.zero);
    canvas
      ..restore()
      ..restore();
  }
}
