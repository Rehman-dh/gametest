import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';

/// Sky and parallax layers, drawn to fill whatever the camera sees.
class Background extends Component with HasGameReference<SiegeGame> {
  Background() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    game.theme.drawBackground(
      canvas,
      game.camera.visibleWorldRect,
      game.realTime,
    );
  }
}
