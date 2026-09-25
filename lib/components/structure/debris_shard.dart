import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../core/materials.dart';
import '../../game/siege_game.dart';

/// A physical piece of a broken block. Tumbles, settles, then shrinks away.
/// Debris never deals damage and never blocks shots.
class DebrisShard extends BodyComponent<SiegeGame> {
  DebrisShard({
    required this.material,
    required this.polygon,
    required this.start,
    required this.angle,
    required this.velocity,
    required this.spin,
    required this.lifetime,
    this.spriteOffset = Offset.zero,
    this.look,
    this.crackStage = 0,
    this.blockSize,
  }) : super(renderBody: false, priority: 1);

  static const _shrinkTime = 0.5;

  final BlockMaterial material;
  final List<Offset> polygon;
  final Vector2 start;
  @override
  final double angle;
  final Vector2 velocity;
  final double spin;
  final double lifetime;

  /// Where this shard sat in the block, relative to the block's centre.
  final Offset spriteOffset;

  /// The broken block's fortress look, damage and size, for themes that
  /// cut its pieces from the block's own art.
  final String? look;
  final int crackStage;
  final Size? blockSize;

  double _age = 0;

  /// How far the shard has shrunk away, 0–1.
  double get shrink => ((_age - lifetime) / _shrinkTime).clamp(0.0, 1.0);

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(
        type: BodyType.dynamic,
        position: start,
        angle: angle,
        linearVelocity: velocity,
        angularVelocity: spin,
        userData: this,
      ),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..set([for (final p in polygon) Vector2(p.dx, p.dy)]),
        density: material.spec.density,
        friction: 0.8,
        restitution: 0.1,
        filter: Filter()
          ..categoryBits = CollisionCategory.debris
          ..maskBits = CollisionCategory.debrisMask,
      ),
    );
    return body;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age > lifetime + _shrinkTime || body.position.y > 25) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (shrink > 0) {
      canvas
        ..save()
        ..scale(1 - shrink);
    }
    game.theme.drawShard(
      canvas,
      polygon,
      material,
      look: look,
      crackStage: crackStage,
      offset: spriteOffset,
      blockSize: blockSize,
    );
    if (shrink > 0) canvas.restore();
  }
}
