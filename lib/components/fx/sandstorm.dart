import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/era.dart';
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
    if (_thunder) {
      _flash = math.max(0, _flash - dt * 3);
      _nextFlash -= dt;
      if (_nextFlash <= 0) {
        _flash = 1;
        _nextFlash = 4 + _sky.nextDouble() * 6;
        game.effects.thunder();
      }
    }
  }

  /// A storm over the Titan's lands: slanting rain driven by the gust and
  /// lightning washing the sky white now and then.
  void _renderRain(Canvas canvas) {
    final size = game.size.toSize();
    final wind = game.windNow.value;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x2A2A1E48),
    );
    final rng = math.Random(7);
    final slant = (wind / 3).clamp(-0.6, 0.6) * 40;
    final rain = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 110; i++) {
      final speed = 0.8 + rng.nextDouble();
      final x = rng.nextDouble() * (size.width + 80) - 40;
      final y =
          ((rng.nextDouble() + _drift * speed * 2.5) % 1) * (size.height + 60) -
          30;
      rain.color = Color.fromRGBO(200, 210, 255, 0.25 + 0.3 * rng.nextDouble());
      canvas.drawLine(Offset(x, y), Offset(x + slant * 0.4, y + 22), rain);
    }
    if (_flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(235, 230, 255, 0.55 * _flash),
      );
    }
  }

  bool get _active => game.levelLoaded && game.level.storm > 0 && !game.attract;

  /// Seconds until the next lightning flash, and how bright it still is.
  double _nextFlash = 3;
  double _flash = 0;
  final math.Random _sky = math.Random();

  bool get _thunder => game.level.era == Era.mythic;

  @override
  void render(Canvas canvas) {
    if (!_active) return;
    if (_thunder) {
      _renderRain(canvas);
      return;
    }
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
