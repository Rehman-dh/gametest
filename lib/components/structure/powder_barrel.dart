import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../core/damage.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../damageable.dart';

/// A barrel of black powder: a weak point that explodes when broken,
/// and can set off other barrels in a chain.
class PowderBarrel extends BodyComponent<SiegeGame>
    with ContactCallbacks, Damageable {
  PowderBarrel(this.data) : super(renderBody: false);

  static const size = Size(0.9, 1.1);

  final PropData data;

  @override
  double get maxHp => 10;

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
        density: 0.8,
        friction: 0.7,
        filter: Filter()..categoryBits = CollisionCategory.structure,
      ),
    );
    return body;
  }

  @override
  void render(Canvas canvas) {
    game.theme.drawBarrel(canvas, size, crackStage: crackStageFor(hp, maxHp));
    if (game.revealWeakPoints) {
      game.theme.drawWeakPointMarker(canvas, size, game.realTime);
    }
  }

  @override
  void onDestroyed() {
    game.onWeakPointBroken(body.position.clone());
    game.queueExplosion(body.position.clone(), radius: 5.5, power: 90);
  }
}
