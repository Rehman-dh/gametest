import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';

/// Pebbles and tufts drawn in front of the battlefield's base.
class GroundDetail extends Component with HasGameReference<SiegeGame> {
  GroundDetail() : super(priority: 20);

  @override
  void render(Canvas canvas) {
    game.theme.drawGroundDetail(canvas, game.camera.visibleWorldRect);
  }
}
