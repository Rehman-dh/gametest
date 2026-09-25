import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../game/siege_game.dart';

/// Invisible sensor around the player's siege engine. Enemy fire that
/// reaches it damages the engine.
class PlayerTarget extends BodyComponent<SiegeGame> {
  PlayerTarget({required this.x}) : super(renderBody: false);

  static const halfWidth = 2.0;
  static const height = 4.0;

  final double x;

  /// Where enemy gunners aim.
  Vector2 get aimPoint => Vector2(x, -height * 0.45);

  @override
  Body createBody() {
    final body = world.createBody(
      BodyDef(position: Vector2(x, -height / 2), userData: this),
    );
    body.createFixture(
      FixtureDef(
        PolygonShape()..setAsBoxXY(halfWidth, height / 2),
        isSensor: true,
        filter: Filter()
          ..categoryBits = CollisionCategory.playerEngine
          ..maskBits = CollisionCategory.enemyProjectile,
      ),
    );
    return body;
  }
}
