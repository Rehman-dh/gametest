import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// World-space callout ("WEAK POINT!") that rises and fades out.
class FloatingText extends Component {
  FloatingText(
    this.text, {
    required this.at,
    this.color = const Color(0xFFF2DCA8),
  }) : super(priority: 50);

  static const _life = 1.6;
  static const _rise = 2.0;

  final String text;
  final Vector2 at;
  final Color color;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final alpha = t < 0.7 ? 1.0 : (1 - t) / 0.3;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.12,
          color: color.withValues(alpha: alpha),
          shadows: [
            Shadow(
              color: const Color(0xFF000000).withValues(alpha: 0.8 * alpha),
              blurRadius: 0.15,
              offset: const Offset(0.06, 0.08),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final y = at.y - 1.5 - _rise * Curves.easeOut.transform(t);
    painter.paint(canvas, Offset(at.x - painter.width / 2, y));
  }
}
