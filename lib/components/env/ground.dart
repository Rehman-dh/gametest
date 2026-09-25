import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../game/siege_game.dart';

/// Static ground slab whose top surface is y = 0.
class Ground extends BodyComponent<SiegeGame> {
  Ground({required this.left, required this.right})
    : super(renderBody: false, priority: -1);

  static const depth = 12.0;

  final double left;
  final double right;

  double get _width => right - left;

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(position: Vector2((left + right) / 2, depth / 2)),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(_width / 2, depth / 2),
        friction: 0.9,
        filter: Filter()..categoryBits = CollisionCategory.ground,
      ),
    );
    return body;
  }

  @override
  void render(Canvas canvas) {
    game.theme.drawGround(
      canvas,
      Rect.fromCenter(center: Offset.zero, width: _width, height: depth),
    );
  }
}
