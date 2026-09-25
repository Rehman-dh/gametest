import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/ammo.dart';
import '../../core/weapons.dart';
import '../../game/siege_game.dart';

/// The player's siege weapon. Purely visual: firing is driven by the game.
class SiegeEngine extends PositionComponent with HasGameReference<SiegeGame> {
  SiegeEngine({required this.type, required double x})
    : super(position: Vector2(x, 0), priority: 5);

  final WeaponType type;

  static const _cockedAngle = -1.1;
  static const _releasedAngle = 0.35;
  static const _pivot = (x: 0.0, y: -2.8);
  static const _armLength = 3.3;
  static const _ballistaPivot = (x: 0.0, y: -1.6);
  static const _ballistaReach = 1.6;
  static const _ballistaRestAim = -0.3;

  double get _scale => switch (type) {
    WeaponType.catapult => 1.3,
    WeaponType.trebuchet => 1.7,
    WeaponType.ballista => 1.2,
  };

  bool get isThrower => type != WeaponType.ballista;

  double _armAngle = _cockedAngle;
  double _releaseTime = double.infinity;
  double _aimAngle = _ballistaRestAim;

  /// Launch direction for a ballista pulled by [pull].
  static double aimAngleFor(Vector2? pull) =>
      pull == null || pull.length2 < 0.01
      ? _ballistaRestAim
      : math.atan2(pull.y, pull.x);

  /// World position where a projectile spawns for the given [pull].
  Vector2 launchOriginFor(Vector2? pull) {
    final Vector2 local;
    if (isThrower) {
      local = Vector2(
        _pivot.x + _armLength * math.sin(_cockedAngle),
        _pivot.y - _armLength * math.cos(_cockedAngle),
      );
    } else {
      final a = aimAngleFor(pull);
      local = Vector2(
        _ballistaPivot.x + _ballistaReach * math.cos(a),
        _ballistaPivot.y + _ballistaReach * math.sin(a),
      );
    }
    return position + local * _scale;
  }

  void release() => _releaseTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    final pull = game.currentPull;
    if (pull != null) _aimAngle = aimAngleFor(pull);

    if (_releaseTime == double.infinity) return;
    _releaseTime += dt;
    if (!isThrower) {
      if (_releaseTime > 0.8) _releaseTime = double.infinity;
      return;
    }
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
    canvas
      ..save()
      ..scale(_scale);
    game.theme.drawSiegeEngine(
      canvas,
      type,
      armAngle: _armAngle,
      aimAngle: _aimAngle,
    );
    canvas.restore();

    final ammo = game.selectedAmmo.value;
    if (ammo == null ||
        game.phase.value != SiegePhase.aiming ||
        !_releaseTime.isInfinite) {
      return;
    }
    // Show the loaded round in the bucket or on the ballista's stock.
    final o = launchOriginFor(game.currentPull) - position;
    canvas
      ..save()
      ..translate(o.x, o.y);
    if (!isThrower) canvas.rotate(_aimAngle);
    game.theme.drawProjectile(canvas, ammo, ammo.spec.radius, game.realTime);
    canvas.restore();
  }
}
