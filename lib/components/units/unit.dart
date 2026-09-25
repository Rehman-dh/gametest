import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../damageable.dart';

/// An enemy soldier or king. Round bodies so they roll and tumble.
class Unit extends BodyComponent<SiegeGame> with ContactCallbacks, Damageable {
  Unit(this.data) : super(renderBody: false);

  final UnitData data;

  UnitKind get kind => data.kind;
  double get radius => kind == UnitKind.king ? 0.6 : 0.45;

  @override
  double get maxHp => kind == UnitKind.king ? 20 : 12;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: Vector2(data.x, -(data.y + radius)),
        angularDamping: 2,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        CircleShape(radius: radius),
        density: 1,
        friction: 0.8,
        restitution: 0.1,
      ),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Knocked off the map counts as a kill.
    if (!isDestroyed && body.position.y > 25) destroy();
  }

  @override
  void render(Canvas canvas) {
    game.theme.drawUnit(canvas, radius, kind, hurt: hurtFlash > 0);
  }

  @override
  void onDestroyed() => game.onUnitKilled(this);
}
