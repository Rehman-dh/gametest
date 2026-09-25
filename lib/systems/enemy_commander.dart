import 'dart:math' as math;

import 'package:flame/components.dart';

import '../components/enemy/enemy_catapult.dart';
import '../components/enemy/enemy_projectile.dart';
import '../components/units/unit.dart';
import '../core/ballistics.dart';
import '../game/siege_game.dart';
import '../levels/level_data.dart';

/// Runs the castle's return fire: on the enemy turn every archer looses an
/// arrow and every enemy catapult lobs a stone at the player's engine.
///
/// Gunners start inaccurate and tighten their aim with each volley, which
/// rewards taking them out early.
class EnemyCommander {
  EnemyCommander(this.game, {math.Random? random})
    : _rng = random ?? math.Random();

  final SiegeGame game;
  final math.Random _rng;

  static const _arrowSpeed = 24.0;
  static const _stoneSpeed = 26.0;
  static const _arrowSpread = 0.20;
  static const _stoneSpread = 0.12;

  /// Pause after the last shot lands before handing the turn back.
  static const _settleTime = 0.7;

  int volleys = 0;
  final List<(double at, void Function() fire)> _queue = [];
  final Set<EnemyProjectile> _inFlight = {};
  double _clock = 0;
  double _quiet = 0;

  Iterable<Unit> get _archers => game.world.children.whereType<Unit>().where(
    (u) => u.kind == UnitKind.archer && !u.isDestroyed,
  );

  Iterable<EnemyCatapult> get _catapults => game.world.children
      .whereType<EnemyCatapult>()
      .where((c) => !c.isDestroyed);

  bool get hasShooters => _archers.isNotEmpty || _catapults.isNotEmpty;

  /// 1 on the first volley, shrinking to 0.4 as the enemy finds its range.
  double get _spreadFactor => math.max(0.4, 1 - 0.2 * (volleys - 1));

  void reset() {
    volleys = 0;
    _queue.clear();
    _inFlight.clear();
  }

  void startVolley() {
    volleys++;
    _clock = 0;
    _quiet = 0;
    final target = game.playerTarget.aimPoint;
    var at = 0.5;
    for (final archer in _archers) {
      _queue.add((at, () => _shootArrow(archer, target)));
      at += 0.35;
    }
    for (final catapult in _catapults) {
      _queue.add((at, () => _shootStone(catapult, target)));
      at += 0.7;
    }
    game.effects.enemyVolley(target);
  }

  /// Advances the volley; returns true once it has fully played out.
  bool tick(double dt) {
    _clock += dt;
    while (_queue.isNotEmpty && _queue.first.$1 <= _clock) {
      _queue.removeAt(0).$2();
    }
    if (_queue.isNotEmpty || _inFlight.isNotEmpty) {
      _quiet = 0;
      return false;
    }
    _quiet += dt;
    return _quiet > _settleTime;
  }

  void onFinished(EnemyProjectile projectile) => _inFlight.remove(projectile);

  void _shootArrow(Unit archer, Vector2 target) {
    if (archer.isDestroyed) return;
    final from = archer.bowPosition;
    final v = _aim(from, _jitter(target), _arrowSpeed, _arrowSpread, false);
    if (v == null) return;
    _launch(EnemyShot.arrow, from, v);
    game.effects.arrowLoosed();
  }

  void _shootStone(EnemyCatapult catapult, Vector2 target) {
    if (catapult.isDestroyed) return;
    final from = catapult.launchOrigin;
    final v = _aim(from, _jitter(target), _stoneSpeed, _stoneSpread, true);
    if (v == null) return;
    catapult.playRelease();
    _launch(EnemyShot.stone, from, v);
    game.effects.enemyCatapultLaunch();
  }

  /// Aim point somewhere on the engine rather than dead centre.
  Vector2 _jitter(Vector2 target) =>
      target +
      Vector2((_rng.nextDouble() - 0.5) * 2.4, (_rng.nextDouble() - 0.5) * 1.6);

  Vector2? _aim(
    Vector2 from,
    Vector2 to,
    double speed,
    double spread,
    bool highArc,
  ) {
    final gravity = game.world.gravity.y;
    // Out of range at the usual speed: put more effort into it.
    final solution =
        launchVelocityToHit(
          fromX: from.x,
          fromY: from.y,
          toX: to.x,
          toY: to.y,
          speed: speed,
          gravity: gravity,
          highArc: highArc,
        ) ??
        launchVelocityToHit(
          fromX: from.x,
          fromY: from.y,
          toX: to.x,
          toY: to.y,
          speed: speed * 1.4,
          gravity: gravity,
          highArc: highArc,
        );
    if (solution == null) return null;
    final error = (_rng.nextDouble() - 0.5) * 2 * spread * _spreadFactor;
    final power = 1 + (_rng.nextDouble() - 0.5) * 0.06 * _spreadFactor;
    final c = math.cos(error), s = math.sin(error);
    return Vector2(
          solution.vx * c - solution.vy * s,
          solution.vx * s + solution.vy * c,
        ) *
        power;
  }

  void _launch(EnemyShot kind, Vector2 from, Vector2 velocity) {
    final projectile = EnemyProjectile(
      kind: kind,
      start: from.clone(),
      velocity: velocity,
    );
    _inFlight.add(projectile);
    game.world.add(projectile);
  }
}
