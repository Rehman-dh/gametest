import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/ammo.dart';
import '../../core/collision.dart';
import '../../game/siege_game.dart';
import '../structure/castle_block.dart';

/// Anything the siege engine throws: stones, fireballs, clusters, powder
/// kegs and ballista bolts. Behaviour comes from [AmmoType.spec].
class Projectile extends BodyComponent<SiegeGame> with ContactCallbacks {
  Projectile({
    required this.type,
    required this.start,
    required this.velocity,
    this.gravityScale = 1,
    double? radius,
  }) : radius = radius ?? type.spec.radius,
       super(renderBody: false, priority: 8);

  final AmmoType type;
  final Vector2 start;
  final Vector2 velocity;
  final double gravityScale;
  final double radius;

  static const _minImpactSpeed = 7.0;
  static const _trailInterval = 0.035;
  static const _detonateSpeed = 4.0;
  static const _igniteRadius = 1.4;

  AmmoSpec get spec => type.spec;

  /// Whether the tap/impact ability (split, detonate, ignite) is unused.
  bool _armed = true;
  bool _pendingDetonation = false;
  bool _hasHit = false;
  double _age = 0;
  double _lastImpact = -1;
  double _trailTimer = 0;
  double _restTime = 0;
  bool _finished = false;

  bool get isBolt => type == AmmoType.bolt;
  double get boltLength => radius * 8;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: start,
        angle: math.atan2(velocity.y, velocity.x),
        linearVelocity: velocity,
        angularVelocity: isBolt ? 0 : 4,
        bullet: true,
        gravityScale: Vector2.all(gravityScale),
        userData: this,
      ),
    );
    final shape = isBolt
        ? (PolygonShape()..setAsBoxXY(boltLength / 2, radius * 0.6))
        : CircleShape(radius: radius);
    body.createFixture(
      FixtureDef(
        shape,
        density: spec.density,
        friction: 0.6,
        restitution: isBolt ? 0.05 : 0.2,
        filter: Filter()
          ..categoryBits = CollisionCategory.projectile
          ..maskBits = CollisionCategory.projectileMask,
      ),
    );
    return body;
  }

  /// The player tapped the screen while this was in flight.
  void onPlayerTap() {
    // A projectile fired this frame has no body yet.
    if (!_armed || _finished || !isMounted) return;
    if (spec.splitsOnTap) {
      _split();
    } else if (spec.explodes) {
      _pendingDetonation = true;
    }
  }

  void _split() {
    _armed = false;
    final v = body.linearVelocity;
    for (var i = 0; i < clusterPieces; i++) {
      final spread = (i - (clusterPieces - 1) / 2) * 0.22;
      final c = math.cos(spread), s = math.sin(spread);
      // The parent's velocity, fanned out by the spread angle.
      final piece = Vector2(v.x * c - v.y * s, v.x * s + v.y * c);
      game.addProjectile(
        Projectile(
          type: AmmoType.stone,
          start: body.position + Vector2(0, (i - 1.5) * 0.35),
          velocity: piece * (0.95 + 0.05 * i),
          gravityScale: gravityScale,
          radius: clusterPieceRadius,
        ),
      );
    }
    game.effects.clusterSplit(body.position);
    _finish();
  }

  void _detonate() {
    _armed = false;
    game.queueExplosion(body.position.clone(), radius: 3.8, power: 60);
    _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    game.onProjectileFinished(this);
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished) return;
    if (_pendingDetonation) {
      _detonate();
      return;
    }
    _age += dt;

    // Wind pushes on everything in the air.
    final wind = game.level.wind;
    if (wind != 0) body.applyForce(Vector2(wind * body.mass, 0));

    final speed = body.linearVelocity.length;
    // Bolts fly point-first until they strike something.
    if (isBolt && !_hasHit && speed > 3) {
      final v = body.linearVelocity;
      body
        ..setTransform(body.position, math.atan2(v.y, v.x))
        ..angularVelocity = 0;
    }

    _trailTimer += dt;
    if (speed > 10 && _trailTimer > _trailInterval) {
      _trailTimer = 0;
      if (type == AmmoType.fireball) {
        game.effects.fireTrail(body.position);
      } else if (!isBolt) {
        game.effects.projectileTrail(body.position);
      }
    }

    _restTime = speed < 0.6 ? _restTime + dt : 0;
    final p = body.position;
    final outOfBounds =
        p.y > 25 || p.x < game.minWorldX || p.x > game.maxWorldX;
    if (_restTime > 0.8 || _age > 9 || outOfBounds) _finish();
  }

  @override
  void beginContact(Object other, Contact contact) {
    super.beginContact(other, contact);
    final speed = body.linearVelocity.length;
    _hasHit = true;

    if (spec.ignites && _armed) {
      _armed = false;
      if (other is CastleBlock) other.ignite();
      // Contact callbacks run mid-step; the game ignites on its next update.
      game.queueIgnition(body.position.clone(), _igniteRadius);
    }
    if (spec.explodes && _armed && speed > _detonateSpeed) {
      _pendingDetonation = true;
    }

    if (speed < _minImpactSpeed || _age - _lastImpact < 0.15) return;
    _lastImpact = _age;
    game.effects.projectileImpact(body.position, speed);
  }

  @override
  void render(Canvas canvas) {
    game.theme.drawProjectile(canvas, type, radius, game.realTime);
  }
}
