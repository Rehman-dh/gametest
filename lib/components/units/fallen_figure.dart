import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../../theme/figure_painter.dart';

/// A defender who has just been killed: thrown back by the blow, he
/// topples, drops to where he stood, lies still a moment and fades.
class FallenFigure extends PositionComponent with HasGameReference<SiegeGame> {
  FallenFigure({
    required this.kind,
    required Vector2 feet,
    required Vector2 velocity,
    required this.seed,
  }) : _velocity = velocity.clone(),
       _floor = feet.y,
       super(position: feet, priority: 4);

  final UnitKind kind;
  final int seed;
  final Vector2 _velocity;
  final double _floor;

  static const _lieTime = 1.6;
  static const _fadeTime = 0.6;

  double _age = 0;
  double _tilt = 0;
  bool _landed = false;
  double _landedAt = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (!_landed) {
      _velocity.y += 12 * dt;
      position += _velocity * dt;
      // Topple backwards, away from the catapult.
      _tilt = math.min(math.pi / 2, _tilt + dt * 5);
      if (position.y >= _floor && _velocity.y > 0) {
        position.y = _floor;
        _landed = true;
        _landedAt = _age;
      }
    } else {
      _tilt = math.pi / 2;
    }
    if (_landed && _age - _landedAt > _lieTime + _fadeTime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final fade = _landed
        ? 1 - ((_age - _landedAt - _lieTime) / _fadeTime).clamp(0.0, 1.0)
        : 1.0;
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(255, 255, 255, fade),
    );
    canvas
      ..scale(-1, 1)
      ..rotate(-_tilt);
    FigurePainter.paint(
      canvas,
      kind,
      FigurePose(time: game.realTime, seed: seed, limp: 1, panic: 0.3),
    );
    canvas.restore();
  }
}
