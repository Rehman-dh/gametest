import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/ammo.dart';
import '../../core/collision.dart';
import '../../game/siege_game.dart';
import '../structure/castle_block.dart';
import 'player_target.dart';

enum EnemyShot {
  arrow(damage: 8, barricadeDamage: 5),
  stone(damage: 18, barricadeDamage: 0);

  const EnemyShot({required this.damage, required this.barricadeDamage});

  /// Damage to the player's siege engine on a direct hit.
  final double damage;

  /// Extra damage to a barricade block, on top of impact damage.
  final double barricadeDamage;
}

/// An arrow or stone fired by the castle at the player's siege engine.
class EnemyProjectile extends BodyComponent<SiegeGame> with ContactCallbacks {
  EnemyProjectile({
    required this.kind,
    required this.start,
    required this.velocity,
  }) : super(renderBody: false, priority: 8);

  final EnemyShot kind;
  final Vector2 start;
  final Vector2 velocity;

  static const _arrowRadius = 0.12;
  static const _stoneRadius = 0.45;

  bool _hasHit = false;
  bool _finished = false;
  double _age = 0;
  double _restTime = 0;

  bool get isArrow => kind == EnemyShot.arrow;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: start,
        angle: math.atan2(velocity.y, velocity.x),
        linearVelocity: velocity,
        bullet: true,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        isArrow
            ? (PolygonShape()..setAsBoxXY(_arrowRadius * 4, 0.05))
            : CircleShape(radius: _stoneRadius),
        density: isArrow ? 2 : 3,
        friction: 0.6,
        restitution: 0.1,
        filter: Filter()
          ..categoryBits = CollisionCategory.enemyProjectile
          ..maskBits = CollisionCategory.enemyProjectileMask,
      ),
    );
    return body;
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    game.onEnemyProjectileFinished(this);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    _age += dt;
    final v = body.linearVelocity;
    if (isArrow && !_hasHit && v.length > 3) {
      body
        ..setTransform(body.position, math.atan2(v.y, v.x))
        ..angularVelocity = 0;
    }
    _restTime = v.length < 0.5 ? _restTime + dt : 0;
    final p = body.position;
    if (_restTime > 0.6 ||
        _age > 8 ||
        p.y > 25 ||
        p.x < game.minWorldX ||
        p.x > game.maxWorldX) {
      _finish();
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);
    if (_hasHit) return;
    _hasHit = true;
    switch (other) {
      case PlayerTarget():
        game.damagePlayer(kind.damage, body.position.clone());
        _finish();
      case CastleBlock(isDefense: true) when kind.barricadeDamage > 0:
        other.takeDamage(kind.barricadeDamage);
        game.effects.projectileImpact(body.position, 8);
      default:
        if (!isArrow) {
          game.effects.projectileImpact(
            body.position,
            body.linearVelocity.length,
          );
        }
    }
  }

  @override
  void render(Canvas canvas) {
    if (isArrow) {
      game.theme.drawProjectile(canvas, AmmoType.bolt, _arrowRadius, 0);
    } else {
      game.theme.drawProjectile(canvas, AmmoType.stone, _stoneRadius, 0);
    }
  }
}
