import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../units/unit.dart';

/// The water in a moat: drawn over the trench, rippling, and deadly to any
/// defender who falls in.
class Moat extends Component with HasGameReference<SiegeGame> {
  Moat(this.data) : super(priority: 12);

  final MoatData data;

  /// Water stands a little below the banks.
  static const _freeboard = 0.35;

  double get _surface => _freeboard;

  @override
  void update(double dt) {
    for (final u in game.world.children.whereType<Unit>().toList()) {
      if (u.isDestroyed || !u.isLoaded) continue;
      final p = u.body.position;
      if (p.x > data.left && p.x < data.right && p.y > _surface + 0.2) {
        game.effects.splash(Vector2(p.x, _surface));
        u.destroy();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final t = game.realTime;
    final water = Rect.fromLTRB(data.left, _surface, data.right, data.depth);
    canvas.drawRect(
      water,
      Paint()
        ..shader = Gradient.linear(water.topCenter, water.bottomCenter, const [
          Color(0xDD3C7FB8),
          Color(0xEE1F4A78),
        ]),
    );
    // Rippling surface with a pale highlight.
    final surface = Path()..moveTo(data.left, _surface);
    for (var x = data.left; x <= data.right; x += 0.25) {
      surface.lineTo(x, _surface + math.sin(x * 2.2 + t * 2.5) * 0.06);
    }
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = const Color(0xCCBFE6FF),
    );
  }
}
