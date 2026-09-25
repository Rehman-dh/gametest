import 'dart:math' as math;
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

import '../../core/collision.dart';
import '../../game/siege_game.dart';
import '../../levels/level_data.dart';
import '../../story/characters.dart';
import '../damageable.dart';
import '../../theme/figure_painter.dart';
import '../structure/castle_block.dart';
import 'fallen_figure.dart';

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
  double get radius => switch (kind) {
    UnitKind.pharaoh => 0.7,
    UnitKind.king => 0.6,
    _ => 0.45,
  };

  @override
  double get maxHp => switch (kind) {
    UnitKind.pharaoh => 40,
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
    _tickMood(dt);
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
    if (kind == UnitKind.pharaoh) {
      // The boss is drawn as his story self, standing on the body's base.
      canvas
        ..save()
        ..translate(0, radius)
        ..scale(0.8);
      game.theme.drawCharacter(
        canvas,
        characterLooks[CharacterId.sethmose]!,
        pose: hurtFlash > 0 ? Pose.point : Pose.stand,
        time: game.realTime,
      );
      canvas.restore();
      return;
    }
    // Stand upright whatever the round body is doing, unless thrown hard
    // enough to tumble; face the catapult, leaning with the motion.
    final speed = body.linearVelocity.length;
    final tumble = ((speed - 4) / 4).clamp(0.0, 1.0);
    canvas
      ..save()
      ..rotate(-body.angle * (1 - tumble))
      ..translate(0, radius)
      ..rotate((body.linearVelocity.x * 0.04).clamp(-0.3, 0.3))
      ..scale(-1, 1);
    FigurePainter.paint(
      canvas,
      kind,
      FigurePose(
        time: game.realTime,
        seed: data.x.round(),
        alert: _alert,
        panic: _panic,
      ),
    );
    canvas.restore();
  }

  double _alert = 0;
  double _panic = 0;

  /// Eases the figure's alarm toward what is happening around him.
  void _tickMood(double dt) {
    final incoming = game.phase.value == SiegePhase.flying;
    final shaken = hurtFlash > 0 || body.linearVelocity.length > 2.5;
    final k = 1 - math.exp(-6 * dt);
    _alert += ((incoming ? 1.0 : 0.0) - _alert) * k;
    _panic +=
        ((shaken ? 1.0 : 0.0) - _panic) * (shaken ? 1 - math.exp(-20 * dt) : k);
  }

  @override
  void onDestroyed() {
    game.world.add(
      FallenFigure(
        kind: kind,
        feet: body.position + Vector2(0, radius),
        velocity: body.linearVelocity * 0.5 + Vector2(1.5, -3),
        seed: data.x.round(),
      ),
    );
    game.onUnitKilled(this);
  }
}
