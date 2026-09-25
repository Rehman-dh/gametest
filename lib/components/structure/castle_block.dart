import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../core/damage.dart';
import '../../core/materials.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../damageable.dart';
import '../units/unit.dart';
import 'powder_barrel.dart';

class CastleBlock extends BodyComponent<SiegeGame>
    with ContactCallbacks, Damageable {
  CastleBlock(this.data, {this.isDefense = false}) : super(renderBody: false);

  final BlockData data;

  /// Part of the player's barricade rather than the enemy castle.
  final bool isDefense;
  late final int _crackSeed = Object.hash(data.x, data.y, data.width);

  static const _spreadInterval = 1.2;
  static const _spreadChance = 0.6;
  static const _fireFxInterval = 0.14;
  static const _fireContactDamage = 4.0;

  final math.Random _rng = math.Random();
  bool burning = false;
  double _burnTime = 0;
  double _spreadTimer = 0;
  double _fxTimer = 0;

  BlockMaterial get material => data.material;

  /// How scorched the block looks, 0–1.
  double get char => (_burnTime / 5).clamp(0, 1);

  @override
  double get maxHp =>
      material.spec.maxHp *
      (data.weak ? weakPointHpFactor : 1) *
      (isDefense ? game.modifiers.barricadeHpMultiplier : 1);

  /// Restores hit points, as enemy engineers patch damaged masonry.
  void heal(double amount) {
    if (isDestroyed) return;
    hp = math.min(maxHp, hp + amount);
  }

  bool get isDamaged => !isDestroyed && hp < maxHp - 0.5;

  void ignite() {
    if (burning || isDestroyed || !material.spec.flammable) return;
    burning = true;
    game.effects.ignite(body.position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!burning || isDestroyed) return;
    _burnTime += dt;
    hp -= burnDamagePerSecond * game.modifiers.fireMultiplier * dt;
    if (hp <= 0) {
      destroy();
      return;
    }
    _fxTimer += dt;
    if (_fxTimer > _fireFxInterval) {
      _fxTimer = 0;
      game.effects.fireTick(this);
    }
    _spreadTimer += dt;
    if (_spreadTimer > _spreadInterval) {
      _spreadTimer = 0;
      _spreadFire();
    }
  }

  /// Fire creeps into touching wood and scorches anyone standing on it.
  void _spreadFire() {
    for (final contact in body.contacts) {
      if (!contact.isTouching()) continue;
      final other = identical(contact.fixtureA.body, body)
          ? contact.fixtureB.body
          : contact.fixtureA.body;
      switch (other.userData) {
        case final CastleBlock block when _rng.nextDouble() < _spreadChance:
          block.ignite();
        case final Unit unit:
          unit.takeDamage(_fireContactDamage);
        case final PowderBarrel barrel:
          barrel.takeDamage(_fireContactDamage);
      }
    }
  }

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
        filter: Filter()
          ..categoryBits = isDefense
              ? CollisionCategory.playerStructure
              : CollisionCategory.structure,
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
      weak: data.weak,
      char: char,
    );
    if (data.weak && game.revealWeakPoints) {
      game.theme.drawWeakPointMarker(
        canvas,
        Size(data.width, data.height),
        game.realTime,
      );
    }
    if (burning) {
      game.theme.drawFire(
        canvas,
        Size(data.width, data.height),
        game.realTime + _crackSeed % 97,
      );
    }
  }

  @override
  void onHit(double damage) => game.effects.blockHit(this, damage);

  @override
  void onDestroyed() {
    game.onBlockDestroyed(this);
    if (data.weak) game.onWeakPointBroken(body.position.clone());
  }
}
