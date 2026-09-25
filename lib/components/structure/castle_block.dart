import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/damage.dart';
import '../../core/materials.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../damageable.dart';

class CastleBlock extends BodyComponent<SiegeGame>
    with ContactCallbacks, Damageable {
  CastleBlock(this.data) : super(renderBody: false);

  final BlockData data;
  late final int _crackSeed = Object.hash(data.x, data.y, data.width);

  BlockMaterial get material => data.material;

  @override
  double get maxHp => material.spec.maxHp;

  @override
  Body createBody() {
    final spec = material.spec;
    final shape = PolygonShape()..setAsBoxXY(data.width / 2, data.height / 2);
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        // Level y is bottom-up from the ground; Forge2D is y-down.
        position: Vector2(data.x, -(data.y + data.height / 2)),
        angle: -data.angle * math.pi / 180,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        shape,
        density: spec.density,
        friction: spec.friction,
        restitution: spec.restitution,
      ),
    );
    return body;
  }

  @override
  void render(Canvas canvas) {
    game.theme.drawBlock(
      canvas,
      Size(data.width, data.height),
      material,
      crackStage: crackStageFor(hp, maxHp),
      seed: _crackSeed,
    );
  }

  @override
  void onDestroyed() => game.onBlockDestroyed(this);
}
