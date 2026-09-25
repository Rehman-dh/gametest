import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../game/siege_game.dart';

class StoneProjectile extends BodyComponent<SiegeGame> with ContactCallbacks {
  StoneProjectile({required this.start, required this.velocity})
    : super(renderBody: false);

  static const radius = 0.55;

  final Vector2 start;
  final Vector2 velocity;

  static const _minImpactSpeed = 7.0;
  static const _trailInterval = 0.035;

  double _age = 0;
  double _lastImpact = -1;
  double _trailTimer = 0;
  double _restTime = 0;
  bool _finished = false;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: start,
        linearVelocity: velocity,
        angularVelocity: 4,
        bullet: true,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        CircleShape(radius: radius),
        density: 4,
        friction: 0.6,
        restitution: 0.2,
        filter: Filter()
          ..categoryBits = CollisionCategory.projectile
          ..maskBits = CollisionCategory.projectileMask,
      ),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    _age += dt;
    final speed = body.linearVelocity.length;
    _trailTimer += dt;
    if (speed > 10 && _trailTimer > _trailInterval) {
      _trailTimer = 0;
      game.effects.projectileTrail(body.position);
    }
    _restTime = speed < 0.6 ? _restTime + dt : 0;
    final p = body.position;
    final outOfBounds =
        p.y > 25 || p.x < game.minWorldX || p.x > game.maxWorldX;
    if (_restTime > 0.8 || _age > 9 || outOfBounds) {
      _finished = true;
      game.onProjectileFinished(this);
      removeFromParent();
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);
    final speed = body.linearVelocity.length;
    if (speed < _minImpactSpeed || _age - _lastImpact < 0.15) return;
    _lastImpact = _age;
    game.effects.projectileImpact(body.position, speed);
  }

  @override
  void render(Canvas canvas) => game.theme.drawStone(canvas, radius);
}
