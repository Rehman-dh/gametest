import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';

/// Pull-back band and dotted ballistic arc shown while aiming.
class AimGuide extends Component with HasGameReference<SiegeGame> {
  AimGuide() : super(priority: 10);

  static const _dots = 24;
  static const _dotInterval = 0.07;

  @override
  void render(Canvas canvas) {
    final pull = game.currentPull;
    if (pull == null || pull.length < SiegeGame.minPull) return;

    final origin = game.catapult.launchOrigin;
    final power = pull.length / SiegeGame.maxPull;
    game.theme.drawAimBand(
      canvas,
      origin.toOffset(),
      (origin - pull).toOffset(),
      power,
    );

    final v = game.launchVelocity(pull);
    final g = game.world.gravity;
    for (var i = 1; i <= _dots; i++) {
      final t = i * _dotInterval;
      final p = origin + v * t + g * (0.5 * t * t);
      if (p.y > 0) break;
      game.theme.drawTrajectoryDot(canvas, p.toOffset(), 1 - i / (_dots + 4));
    }
  }
}
