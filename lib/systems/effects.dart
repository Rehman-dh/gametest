import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;

import '../components/structure/castle_block.dart';
import '../components/structure/debris_shard.dart';
import '../components/units/unit.dart';
import '../core/fracture.dart';
import '../core/materials.dart';
import '../game/siege_game.dart';
import 'audio.dart';

/// "Game feel": particles, debris, sound, screen shake, hit-stop and
/// slow motion. Gameplay code reports events here and never deals with
/// presentation directly.
class Effects {
  Effects(this.game);

  final SiegeGame game;
  final GameAudio audio = GameAudio();
  final math.Random _rng = math.Random();

  static const _maxShards = 80;
  static const _slowMoDuration = 1.8;
  static const _slowMoScale = 0.25;
  static const _hitStopScale = 0.03;
  static const _maxShake = 0.7;

  double _trauma = 0;
  double _hitStop = 0;
  double _slowMo = 0;
  double _clock = 0;

  /// Multiplier applied to the simulation's dt this frame.
  double get timeScale {
    if (_hitStop > 0) return _hitStopScale;
    if (_slowMo > 0) {
      // Ease back to full speed over the last part of the slow-mo.
      final t = (_slowMo / _slowMoDuration).clamp(0.0, 1.0);
      final ease = math.min(1.0, t * 2.5);
      return 1 + (_slowMoScale - 1) * ease;
    }
    return 1;
  }

  /// Camera offset from screen shake, in meters.
  Vector2 get shakeOffset {
    final s = _trauma * _trauma * _maxShake;
    if (s == 0) return Vector2.zero();
    return Vector2(
      s * (math.sin(_clock * 47) + 0.5 * math.sin(_clock * 83)) / 1.5,
      s * (math.sin(_clock * 59 + 1.3) + 0.5 * math.sin(_clock * 97)) / 1.5,
    );
  }

  double get shakeAngle => _trauma * _trauma * 0.015 * math.sin(_clock * 37);

  void tick(double realDt) {
    _clock += realDt;
    _hitStop = math.max(0, _hitStop - realDt);
    _slowMo = math.max(0, _slowMo - realDt);
    _trauma = math.max(0, _trauma - realDt * 1.3);
  }

  void reset() {
    _trauma = 0;
    _hitStop = 0;
    _slowMo = 0;
  }

  void addTrauma(double amount) => _trauma = math.min(1, _trauma + amount);

  void _burst(Vector2 at, Particle particle) {
    game.world.add(
      ParticleSystemComponent(
        particle: particle,
        position: at.clone(),
        priority: 15,
      ),
    );
  }

  // ------------------------------------------------------------- events

  void launch() {
    audio.play(Sfx.launch);
    addTrauma(0.2);
  }

  void projectileTrail(Vector2 at) =>
      _burst(at, game.theme.trailParticle(_rng));

  void projectileImpact(Vector2 at, double speed) {
    final strength = speed / 20;
    _burst(at, game.theme.impactParticles(strength, _rng));
    addTrauma(math.min(0.45, strength * 0.35));
    if (speed > 14) _hitStop = math.max(_hitStop, 0.06);
  }

  void blockHit(CastleBlock block, double damage) {
    final volume = (damage / 40).clamp(0.0, 1.0);
    audio.play(switch (block.material) {
      BlockMaterial.wood => Sfx.impactWood,
      BlockMaterial.stone => Sfx.impactStone,
      BlockMaterial.glass => Sfx.impactGlass,
    }, volume: volume);
  }

  void blockBroken(CastleBlock block) {
    final body = block.body;
    final size = block.data;
    _burst(
      body.position,
      game.theme.breakParticles(
        block.material,
        Size(size.width, size.height),
        _rng,
      ),
    );
    audio.play(switch (block.material) {
      BlockMaterial.wood => Sfx.breakWood,
      BlockMaterial.stone => Sfx.breakStone,
      BlockMaterial.glass => Sfx.breakGlass,
    });
    addTrauma(block.material == BlockMaterial.stone ? 0.3 : 0.15);
    _spawnShards(block);
  }

  void _spawnShards(CastleBlock block) {
    final alive = game.world.children.whereType<DebrisShard>().length;
    if (alive >= _maxShards) return;
    final body = block.body;
    final rotation = Rot.withAngle(body.angle);
    for (final shard in fractureRect(
      block.data.width,
      block.data.height,
      _rng,
    )) {
      final local = Vector2(shard.center.dx, shard.center.dy);
      final offset = Rot.mulVec2(rotation, local);
      final outward = local.length2 == 0
          ? Vector2(0, -1)
          : (Rot.mulVec2(rotation, local)..normalize());
      game.world.add(
        DebrisShard(
          material: block.material,
          polygon: shard.vertices,
          start: body.position + offset,
          angle: body.angle,
          velocity:
              body.linearVelocity +
              outward * (1 + _rng.nextDouble() * 2.5) +
              Vector2(0, -1.5 * _rng.nextDouble()),
          spin: (_rng.nextDouble() - 0.5) * 6,
          lifetime: 2.5 + _rng.nextDouble() * 1.5,
        ),
      );
    }
  }

  void unitKilled(Unit unit) {
    _burst(unit.body.position, game.theme.unitDeathParticles(unit.kind, _rng));
    audio.play(Sfx.unitDown);
    addTrauma(0.15);
  }

  /// The final blow: slow the world down to let the collapse breathe.
  void objectiveComplete() {
    _slowMo = _slowMoDuration;
    addTrauma(0.5);
  }

  void levelFinished({required bool won}) =>
      audio.play(won ? Sfx.victory : Sfx.defeat, volume: 0.9);
}
