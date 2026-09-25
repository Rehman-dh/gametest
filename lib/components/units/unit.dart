import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../damageable.dart';
import '../structure/castle_block.dart';

/// An enemy soldier, king, archer or engineer. Round bodies so they roll
/// and tumble.
class Unit extends BodyComponent<SiegeGame> with ContactCallbacks, Damageable {
  Unit(this.data) : super(renderBody: false);

  final UnitData data;

  static const _repairInterval = 3.5;
  static const _repairReach = 7.0;
  static const _repairAmount = 15.0;

  double _repairTimer = 0;

  UnitKind get kind => data.kind;
  double get radius => kind == UnitKind.king ? 0.6 : 0.45;

  @override
  double get maxHp => switch (kind) {
    UnitKind.king => 20,
    UnitKind.engineer => 10,
    _ => 12,
  };

  /// Where an archer's arrows leave the bow.
  Vector2 get bowPosition => body.position + Vector2(-radius, -radius * 1.2);

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
        filter: Filter()..categoryBits = CollisionCategory.unit,
      ),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Knocked off the map counts as a kill.
    if (!isDestroyed && body.position.y > 25) destroy();
    if (kind == UnitKind.engineer && !isDestroyed) _tickRepairs(dt);
  }

  /// Engineers patch the most damaged block within reach every few
  /// seconds, so the player is pushed to take them out early.
  void _tickRepairs(double dt) {
    _repairTimer += dt;
    if (_repairTimer < _repairInterval) return;
    _repairTimer = 0;
    CastleBlock? worst;
    var worstMissing = 0.0;
    for (final block in game.world.children.whereType<CastleBlock>()) {
      if (block.isDefense || block.burning || !block.isDamaged) continue;
      final distance = block.body.position.distanceTo(body.position);
      if (distance > _repairReach) continue;
      final missing = block.maxHp - block.hp;
      if (missing > worstMissing) {
        worst = block;
        worstMissing = missing;
      }
    }
    if (worst == null) return;
    worst.heal(math.min(_repairAmount, worstMissing));
    game.effects.repair(worst.body.position);
  }

  @override
  void render(Canvas canvas) {
    game.theme.drawUnit(canvas, radius, kind, hurt: hurtFlash > 0);
  }

  @override
  void onDestroyed() => game.onUnitKilled(this);
}
