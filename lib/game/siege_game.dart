import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../components/env/background.dart';
import '../components/env/ground.dart';
import '../components/env/ground_detail.dart';
import '../components/fx/aim_guide.dart';
import '../components/fx/vignette.dart';
import '../components/damageable.dart';
import '../components/projectiles/projectile.dart';
import '../components/structure/castle_block.dart';
import '../components/structure/debris_shard.dart';
import '../components/structure/powder_barrel.dart';
import '../components/units/unit.dart';
import '../components/weapons/siege_engine.dart';
import '../core/ammo.dart';
import '../core/scoring.dart';
import '../core/weapons.dart';
import '../levels/level_data.dart';
import '../systems/effects.dart';
import '../theme/art_theme.dart';
import '../theme/stylized_theme.dart';

enum SiegePhase { menu, aiming, flying, settling, won, lost }

class LevelResult {
  const LevelResult({
    required this.won,
    required this.stars,
    required this.destruction,
  });

  final bool won;
  final int stars;
  final double destruction;
}

class SiegeGame extends Forge2DGame with DragCallbacks, TapCallbacks {
  SiegeGame({List<ArtTheme>? themes})
    : themes = themes ?? [StylizedTheme()],
      super(gravity: Vector2(0, 12));

  static const levelFiles = [
    'assets/levels/egypt_01.json',
    'assets/levels/egypt_02.json',
    'assets/levels/egypt_03.json',
    'assets/levels/egypt_04.json',
    'assets/levels/egypt_05.json',
    'assets/levels/egypt_06.json',
    'assets/levels/egypt_07.json',
  ];

  /// Drag distances in world meters.
  static const minPull = 1.0;
  static const maxPull = 7.0;

  /// How long to let fires finish off a castle after the last shot.
  static const _maxFireWait = 15.0;

  /// Physics settles for this long after spawning before damage counts,
  /// so a castle doesn't hurt itself while blocks find their rest.
  static const _damageGracePeriod = 1.2;

  /// Minimum world height kept on screen, in meters.
  static const _minViewHeight = 20.0;

  /// Empty ground shown behind the catapult, in meters.
  static const _marginBehindCatapult = 9.0;

  /// Available art styles; the first is active by default.
  final List<ArtTheme> themes;
  late final ValueNotifier<int> themeIndex = ValueNotifier(0);
  ArtTheme get theme => themes[themeIndex.value];

  void cycleArtStyle() =>
      themeIndex.value = (themeIndex.value + 1) % themes.length;
  late final Effects effects = Effects(this);

  /// Unscaled seconds since start, for ambient animation.
  double realTime = 0;

  final ValueNotifier<SiegePhase> phase = ValueNotifier(SiegePhase.menu);

  /// Rounds left per ammo type, and the one loaded for the next shot.
  final ValueNotifier<Map<AmmoType, int>> ammo = ValueNotifier(const {});
  final ValueNotifier<AmmoType?> selectedAmmo = ValueNotifier(null);
  int get shotsLeft => ammo.value.values.fold(0, (a, b) => a + b);
  LevelResult? lastResult;

  late LevelData level;
  int levelIndex = 0;
  late SiegeEngine siegeEngine;

  bool get hasNextLevel => levelIndex + 1 < levelFiles.length;
  double get minWorldX => level.catapultX - 30;
  double get maxWorldX => level.worldWidth + 30;
  bool get damageEnabled => _levelTime > _damageGracePeriod;

  bool _levelLoaded = false;
  bool _objectiveAnnounced = false;
  bool _weakPointHit = false;
  double _cameraBaseX = 0;
  double _levelTime = 0;
  double _settleTime = 0;
  int _shotsUsed = 0;
  double _totalBlockHp = 0;
  double _destroyedBlockHp = 0;
  final Set<Projectile> _projectiles = {};
  final List<(Vector2, double, double)> _pendingExplosions = [];
  final List<(Vector2, double)> _pendingIgnitions = [];
  Vector2? _dragStart;
  Vector2? _pull;

  /// Current slingshot pull vector while aiming, or null.
  Vector2? get currentPull => _pull;

  double get destruction =>
      _totalBlockHp == 0 ? 0 : _destroyedBlockHp / _totalBlockHp;

  @override
  Color backgroundColor() => const Color(0xFF16202C);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewport.add(Vignette());
    await effects.audio.load();
  }

  // ------------------------------------------------------------ level flow

  Future<void> startLevel(int index) async {
    levelIndex = index;
    level = LevelData.parse(await rootBundle.loadString(levelFiles[index]));

    world.removeAll(world.children.toList());
    _levelTime = 0;
    _objectiveAnnounced = false;
    _weakPointHit = false;
    _pendingExplosions.clear();
    _pendingIgnitions.clear();
    effects.reset();
    _shotsUsed = 0;
    _destroyedBlockHp = 0;
    _totalBlockHp = 0;
    _projectiles.clear();
    _dragStart = null;
    _pull = null;
    lastResult = null;

    final blocks = [for (final b in level.blocks) CastleBlock(b)];
    for (final b in blocks) {
      _totalBlockHp += b.maxHp;
    }
    siegeEngine = SiegeEngine(type: level.weapon, x: level.catapultX);
    await world.addAll([
      Background(),
      Ground(left: minWorldX, right: maxWorldX),
      GroundDetail(),
      siegeEngine,
      AimGuide(),
      ...blocks,
      for (final p in level.props) PowderBarrel(p),
      for (final u in level.units) Unit(u),
    ]);

    _levelLoaded = true;
    _fitCamera();
    _cameraBaseX = _cameraHomeX;
    camera.viewfinder.position = Vector2(_cameraBaseX, _cameraY);
    effects.audio.startMusic();
    ammo.value = {
      for (final type in level.ammo.toSet())
        type: level.ammo.where((a) => a == type).length,
    };
    selectedAmmo.value = level.ammo.first;
    overlays
      ..removeAll(['menu', 'result'])
      ..add('hud');
    phase.value = SiegePhase.aiming;
  }

  void showMenu() {
    overlays
      ..removeAll(['hud', 'result'])
      ..add('menu');
    phase.value = SiegePhase.menu;
  }

  // ----------------------------------------------------------------- input

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (phase.value != SiegePhase.aiming) return;
    _dragStart = camera.globalToLocal(event.canvasPosition);
    _pull = Vector2.zero();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final start = _dragStart;
    if (start == null) return;
    _pull = (start - camera.globalToLocal(event.canvasEndPosition))
      ..clampLength(0, maxPull);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final pull = _pull;
    _dragStart = null;
    _pull = null;
    if (pull != null &&
        pull.length >= minPull &&
        phase.value == SiegePhase.aiming) {
      _fire(pull);
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragStart = null;
    _pull = null;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (phase.value != SiegePhase.flying) return;
    for (final p in _projectiles.toList()) {
      p.onPlayerTap();
    }
  }

  Vector2 launchVelocity(Vector2 pull) =>
      pull * level.weapon.spec.speedPerMeter;

  void selectAmmo(AmmoType type) {
    if (phase.value != SiegePhase.aiming || (ammo.value[type] ?? 0) == 0) {
      return;
    }
    selectedAmmo.value = type;
  }

  void _fire(Vector2 pull) {
    final type = selectedAmmo.value;
    if (type == null) return;
    final left = {...ammo.value, type: ammo.value[type]! - 1};
    ammo.value = left;
    if (left[type] == 0) {
      selectedAmmo.value = level.ammo
          .where((a) => (left[a] ?? 0) > 0)
          .firstOrNull;
    }
    _shotsUsed++;
    siegeEngine.release();
    effects.launch(ballista: level.weapon == WeaponType.ballista);
    addProjectile(
      Projectile(
        type: type,
        start: siegeEngine.launchOriginFor(pull),
        velocity: launchVelocity(pull),
        gravityScale: level.weapon.spec.gravityScale,
      ),
    );
    phase.value = SiegePhase.flying;
  }

  void addProjectile(Projectile projectile) {
    _projectiles.add(projectile);
    world.add(projectile);
  }

  // ------------------------------------------------------- world callbacks

  void onProjectileFinished(Projectile projectile) {
    _projectiles.remove(projectile);
    if (_projectiles.isEmpty && phase.value == SiegePhase.flying) {
      _settleTime = 0;
      phase.value = SiegePhase.settling;
    }
  }

  /// Explosions and ignitions requested from physics callbacks run on the
  /// next update, outside the physics step.
  void queueExplosion(
    Vector2 at, {
    required double radius,
    required double power,
  }) => _pendingExplosions.add((at, radius, power));

  void queueIgnition(Vector2 at, double radius) =>
      _pendingIgnitions.add((at, radius));

  void onWeakPointBroken(Vector2 at) {
    if (_weakPointHit) return;
    _weakPointHit = true;
    effects.weakPoint(at);
  }

  void onBlockDestroyed(CastleBlock block) {
    _destroyedBlockHp += block.maxHp;
    effects.blockBroken(block);
  }

  void onUnitKilled(Unit unit) {
    effects.unitKilled(unit);
    if (!_objectiveAnnounced && _objectiveComplete) {
      _objectiveAnnounced = true;
      effects.objectiveComplete();
    }
  }

  void _processQueues() {
    for (final (at, radius) in _pendingIgnitions) {
      for (final block in world.children.whereType<CastleBlock>()) {
        final reach =
            radius + math.max(block.data.width, block.data.height) / 2;
        if (block.body.position.distanceTo(at) <= reach) block.ignite();
      }
    }
    _pendingIgnitions.clear();

    // Chain reactions queue more explosions while these resolve.
    final explosions = List.of(_pendingExplosions);
    _pendingExplosions.clear();
    for (final (at, radius, power) in explosions) {
      _explode(at, radius, power);
    }
  }

  void _explode(Vector2 at, double radius, double power) {
    effects.explosion(at, radius);
    for (final c in world.children.whereType<BodyComponent>().toList()) {
      final body = c.body;
      if (body.bodyType != BodyType.dynamic) continue;
      final offset = body.worldCenter - at;
      final distance = offset.length;
      final falloff = explosionFalloff(distance, radius);
      if (falloff <= 0) continue;
      final dir = distance < 0.01 ? Vector2(0, -1) : offset / distance;
      // Heavier bodies are shoved less.
      final deltaV = power * 0.25 * falloff / (1 + body.mass * 0.05);
      body.applyLinearImpulse(dir * (deltaV * body.mass));
      if (c is Damageable) c.takeDamage(power * 1.6 * falloff);
      if (c is CastleBlock && falloff > 0.25) c.ignite();
    }
  }

  // ---------------------------------------------------------------- update

  @override
  void update(double dt) {
    realTime += dt;
    effects.tick(dt);
    final simDt = dt * effects.timeScale;
    super.update(simDt);
    if (phase.value == SiegePhase.menu) return;
    _processQueues();
    _levelTime += simDt;
    _updateCamera(dt);

    if (phase.value == SiegePhase.settling) {
      _settleTime += simDt;
      if (_settleTime > 0.6 && (_worldAtRest() || _settleTime > 4)) {
        _resolveShot();
      }
    } else if (phase.value == SiegePhase.aiming && _objectiveComplete) {
      // Fire finished the job between shots.
      _finish(won: true);
    }
  }

  bool get _anyBurning =>
      world.children.whereType<CastleBlock>().any((b) => b.burning);

  bool _worldAtRest() => world.children.whereType<BodyComponent>().every(
    (c) =>
        c is DebrisShard ||
        c.body.bodyType != BodyType.dynamic ||
        c.body.linearVelocity.length2 < 0.04,
  );

  Iterable<Unit> get _aliveUnits =>
      world.children.whereType<Unit>().where((u) => !u.isDestroyed);

  bool get _objectiveComplete => switch (level.objective) {
    Objective.killAll => _aliveUnits.isEmpty,
    Objective.killKing => !_aliveUnits.any((u) => u.kind == UnitKind.king),
  };

  void _resolveShot() {
    if (_objectiveComplete) {
      _finish(won: true);
    } else if (shotsLeft == 0) {
      // Out of ammo: give any fires the chance to win the siege.
      if (_anyBurning && _settleTime < _maxFireWait) return;
      _finish(won: false);
    } else {
      phase.value = SiegePhase.aiming;
    }
  }

  void _finish({required bool won}) {
    lastResult = LevelResult(
      won: won,
      destruction: destruction,
      stars: starsFor(
        won: won,
        shotsUsed: _shotsUsed,
        par: level.par,
        destruction: destruction,
        weakPointHit: level.hasWeakPoints ? _weakPointHit : null,
      ),
    );
    phase.value = won ? SiegePhase.won : SiegePhase.lost;
    effects.levelFinished(won: won);
    overlays.add('result');
  }

  // ---------------------------------------------------------------- camera

  double _halfViewWidth = 0;
  double _cameraY = 0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_levelLoaded) _fitCamera();
  }

  /// Zooms so the whole battlefield fits on any screen aspect ratio,
  /// with the ground line near the bottom.
  void _fitCamera() {
    final span = level.worldWidth - (level.catapultX - _marginBehindCatapult);
    final zoom = math.min(size.x / span, size.y / _minViewHeight);
    camera.viewfinder.zoom = zoom;
    final viewHeight = size.y / zoom;
    _halfViewWidth = size.x / zoom / 2;
    // Ground (y = 0) sits 82% of the way down the screen.
    _cameraY = -viewHeight * 0.32;
  }

  double get _cameraHomeX =>
      level.catapultX - _marginBehindCatapult + _halfViewWidth;

  void _updateCamera(double dt) {
    final minX = _cameraHomeX;
    final maxX = math.max(minX, level.worldWidth + 4 - _halfViewWidth);
    final lead = _projectiles.isEmpty
        ? minX
        : _projectiles.map((p) => p.body.position.x).reduce(math.max);
    final target = lead.clamp(minX, maxX);
    _cameraBaseX += (target - _cameraBaseX) * (1 - math.exp(-4 * dt));
    camera.viewfinder
      ..position = Vector2(_cameraBaseX, _cameraY) + effects.shakeOffset
      ..angle = effects.shakeAngle;
  }
}
