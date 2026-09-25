import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';

/// The player's siege weapon. Purely visual: firing is driven by the game.
class Catapult extends PositionComponent with HasGameReference<SiegeGame> {
  Catapult({required double x}) : super(position: Vector2(x, 0), priority: 5);

  static const _cockedAngle = -1.1;
  static const _releasedAngle = 0.35;
  static const _pivot = (x: 0.0, y: -2.8);
  static const _armLength = 3.3;

  double _armAngle = _cockedAngle;
  double _releaseTime = double.infinity;

  /// World position of the loaded bucket, where projectiles spawn.
  Vector2 get launchOrigin =>
      position +
      Vector2(
        _pivot.x + _armLength * math.sin(_cockedAngle),
        _pivot.y - _armLength * math.cos(_cockedAngle),
      );

  void release() => _releaseTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_releaseTime == double.infinity) return;
    _releaseTime += dt;
    const swing = 0.12, rewind = 1.0;
    if (_releaseTime < swing) {
      _armAngle = _lerp(_cockedAngle, _releasedAngle, _releaseTime / swing);
    } else if (_releaseTime < swing + rewind) {
      final t = (_releaseTime - swing) / rewind;
      _armAngle = _lerp(_releasedAngle, _cockedAngle, t * t);
    } else {
      _armAngle = _cockedAngle;
      _releaseTime = double.infinity;
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void render(Canvas canvas) {
    game.theme.drawCatapult(canvas, armAngle: _armAngle);
    if (game.phase.value == SiegePhase.aiming && _releaseTime.isInfinite) {
      // Show the next stone sitting in the bucket.
      final o = launchOrigin - position;
      canvas
        ..save()
        ..translate(o.x, o.y);
      game.theme.drawStone(canvas, 0.55);
      canvas.restore();
    }
  }
}
