import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';

/// Blowing sand across the screen during a sandstorm: a warm haze and
/// streaks racing with the current gust, faster and thicker the harder it
/// blows. Lives in the viewport, above the world.
class Sandstorm extends Component with HasGameReference<SiegeGame> {
  Sandstorm() : super(priority: 90);

  static const _streaks = 70;
  final _paint = Paint()..strokeCap = StrokeCap.round;
  double _drift = 0;

  @override
  void update(double dt) {
    if (!_active) return;
    // Streaks travel with the wind; a calm moment still stirs the dust.
    final wind = game.windNow.value;
    _drift += dt * (0.4 + wind.abs() * 0.5) * (wind < 0 ? -1 : 1);
  }

  bool get _active => game.levelLoaded && game.level.storm > 0 && !game.attract;

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    final size = game.size.toSize();
    final strength = (game.windNow.value.abs() / 3).clamp(0.25, 1.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(214, 160, 90, 0.10 + 0.12 * strength),
    );
    final rng = math.Random(4);
    final dir = game.windNow.value < 0 ? -1.0 : 1.0;
    for (var i = 0; i < _streaks; i++) {
      final speed = 0.6 + rng.nextDouble();
      final y = rng.nextDouble() * size.height;
      final len = (18 + rng.nextDouble() * 40) * (0.6 + strength);
      final x =
          ((rng.nextDouble() + _drift * speed) % 1) * (size.width + len) - len;
      final wobble = math.sin(_drift * 3 + i) * 6;
      _paint
        ..strokeWidth = 1 + rng.nextDouble() * 2
        ..color = Color.fromRGBO(
          240,
          205,
          150,
          (0.25 + 0.35 * rng.nextDouble()) * strength,
        );
      canvas.drawLine(
        Offset(x, y + wobble),
        Offset(x + len * dir, y + wobble + 3),
        _paint,
      );
    }
  }
}
