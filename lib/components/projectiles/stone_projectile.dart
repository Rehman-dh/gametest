import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../game/siege_game.dart';

class StoneProjectile extends BodyComponent<SiegeGame> with ContactCallbacks {
  StoneProjectile({required this.start, required this.velocity})
    : super(renderBody: false);

  static const radius = 0.55;

  final Vector2 start;
  final Vector2 velocity;

  double _age = 0;
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
      ),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    _age += dt;
    _restTime = body.linearVelocity.length < 0.6 ? _restTime + dt : 0;
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
  void render(Canvas canvas) => game.theme.drawStone(canvas, radius);
}
