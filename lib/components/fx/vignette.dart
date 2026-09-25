import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';

/// Screen-space edge darkening for a dramatic, lit-from-the-center look.
/// Lives in the camera viewport so it never moves with the world.
class Vignette extends Component with HasGameReference<SiegeGame> {
  Vignette() : super(priority: 100);

  @override
  void render(Canvas canvas) {
    game.theme.drawVignette(canvas, game.size.toSize());
  }
}
