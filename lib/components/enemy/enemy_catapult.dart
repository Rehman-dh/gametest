import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../core/damage.dart';
import '../../core/weapons.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../damageable.dart';

/// The enemy's own catapult. Lobs stones at the player on the enemy turn;
/// wrecking every one of them wins a defense mission.
class EnemyCatapult extends BodyComponent<SiegeGame>
    with ContactCallbacks, Damageable {
  EnemyCatapult(this.data) : super(renderBody: false);

  static const size = Size(2.6, 1.2);

  /// Drawn at a fraction of the player's engine, facing left.
  static const _drawScale = 0.62;
  static const _cockedAngle = -1.1;

  final PropData data;
  double _armAngle = _cockedAngle;
  double _releaseTime = double.infinity;

  @override
  double get maxHp => 45;

  /// Where its stones leave the bucket, in world space: the cocked bucket
  /// of the mirrored, scaled-down engine drawing.
  Vector2 get launchOrigin => body.position + Vector2(1.8, -2.1);

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(data.x, -(data.y + size.height / 2)),
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(size.width / 2, size.height / 2),
        density: 1.5,
        friction: 0.8,
        filter: Filter()..categoryBits = CollisionCategory.structure,
      ),
    );
    return body;
  }

  void playRelease() => _releaseTime = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_releaseTime.isInfinite) return;
    _releaseTime += dt;
    const swing = 0.15, rewind = 1.2;
    if (_releaseTime < swing) {
      _armAngle = _cockedAngle + (0.35 - _cockedAngle) * _releaseTime / swing;
    } else if (_releaseTime < swing + rewind) {
      final t = (_releaseTime - swing) / rewind;
      _armAngle = 0.35 + (_cockedAngle - 0.35) * t * t;
    } else {
      _armAngle = _cockedAngle;
      _releaseTime = double.infinity;
    }
  }

  @override
  void render(Canvas canvas) {
    // Local origin is the body centre; the engine's origin is its base.
    canvas
      ..save()
      ..translate(0, size.height / 2)
      ..scale(-_drawScale, _drawScale);
    game.theme.drawSiegeEngine(
      canvas,
      WeaponType.catapult,
      armAngle: _armAngle,
      aimAngle: 0,
    );
    canvas.restore();
    final stage = crackStageFor(hp, maxHp);
    if (stage > 0 || hurtFlash > 0) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width,
          height: size.height,
        ),
        Paint()
          ..color = Color.fromRGBO(20, 10, 5, math.min(0.5, stage * 0.15))
          ..blendMode = BlendMode.multiply,
      );
    }
  }

  @override
  void onDestroyed() => game.onEnemyEngineDestroyed(this);
}
