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
import '../components/enemy/enemy_catapult.dart';
import '../components/enemy/enemy_projectile.dart';
import '../components/enemy/player_target.dart';
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
import '../meta/campaign.dart';
import '../meta/catalog.dart';
import '../meta/loadout.dart';
import '../meta/rewards.dart';
import '../systems/effects.dart';
import '../systems/enemy_commander.dart';
import '../theme/art_theme.dart';
import '../theme/stylized_theme.dart';

enum SiegePhase { menu, aiming, flying, settling, enemyTurn, won, lost }

enum DefeatReason { outOfAmmo, engineDestroyed }

class LevelResult {
  const LevelResult({
    required this.won,
    required this.stars,
    required this.destruction,
    this.defeat,
    this.reward = const Reward(),
  });

  final bool won;
  final int stars;
  final double destruction;
  final DefeatReason? defeat;
  final Reward reward;
}

class SiegeGame extends Forge2DGame with DragCallbacks, TapCallbacks {
  SiegeGame({
    List<ArtTheme>? themes,
    this.audioEnabled = true,
    this.random,
    this.campaign,
  }) : themes = themes ?? [StylizedTheme()],
       super(gravity: Vector2(0, 12));

  static const levelFiles = [
    'assets/levels/egypt_01.json',
    'assets/levels/egypt_02.json',
    'assets/levels/egypt_03.json',
    'assets/levels/egypt_04.json',
    'assets/levels/egypt_05.json',
    'assets/levels/egypt_06.json',
    'assets/levels/egypt_07.json',
    'assets/levels/egypt_08.json',
    'assets/levels/egypt_09.json',
    'assets/levels/egypt_10.json',
  ];

  /// Progress and rewards; absent in headless tests.
  final Campaign? campaign;

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

  /// False in headless tests, where no audio device exists.
  final bool audioEnabled;

  /// Available art styles; the first is active by default.
  final List<ArtTheme> themes;
  late final ValueNotifier<int> themeIndex = ValueNotifier(0);
  ArtTheme get theme => themes[themeIndex.value];

  void cycleArtStyle() =>
      themeIndex.value = (themeIndex.value + 1) % themes.length;
  late final Effects effects = Effects(this);

  /// Seeds enemy aim, for reproducible tests.
  final math.Random? random;
  late final EnemyCommander enemy = EnemyCommander(this, random: random);

  /// Unscaled seconds since start, for ambient animation.
  double realTime = 0;

  final ValueNotifier<SiegePhase> phase = ValueNotifier(SiegePhase.menu);

  /// Hit points left on the player's siege engine.
  final ValueNotifier<double> playerHp = ValueNotifier(0);

  /// Rounds left per ammo type, and the one loaded for the next shot.
  final ValueNotifier<Map<AmmoType, int>> ammo = ValueNotifier(const {});
  final ValueNotifier<AmmoType?> selectedAmmo = ValueNotifier(null);
  int get shotsLeft => ammo.value.values.fold(0, (a, b) => a + b);
  LevelResult? lastResult;

  late LevelData level;
  int levelIndex = 0;
  late SiegeEngine siegeEngine;
  late Loadout loadout;
  Modifiers modifiers = Modifiers.none;

  /// Crew abilities already spent this siege.
  final ValueNotifier<Set<CrewId>> usedAbilities = ValueNotifier(const {});

  /// Li Wei's Spotter: weak points glow for the rest of the siege.
  bool revealWeakPoints = false;
  bool _nextShotIgnites = false;

  WeaponType get weapon => loadout.weapon;
  double get playerMaxHp => level.playerHp + modifiers.engineHpBonus;
  late PlayerTarget playerTarget;

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
    if (audioEnabled) await effects.audio.load();
  }

  // ------------------------------------------------------------ level flow

  Future<void> startLevel(int index, {Loadout? loadout}) async {
    levelIndex = index;
    level = LevelData.parse(await rootBundle.loadString(levelFiles[index]));
    this.loadout = loadout ?? Loadout.levelDefault(level);
    modifiers = campaign == null
        ? Modifiers.none
        : Modifiers.from(campaign!.progress.value, this.loadout);
    usedAbilities.value = const {};
    revealWeakPoints = false;
    _nextShotIgnites = false;

    world.removeAll(world.children.toList());
    _levelTime = 0;
    _objectiveAnnounced = false;
    _weakPointHit = false;
    _pendingExplosions.clear();
    _pendingIgnitions.clear();
    effects.reset();
    enemy.reset();
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
    siegeEngine = SiegeEngine(type: weapon, x: level.catapultX);
    playerTarget = PlayerTarget(x: level.catapultX);
    playerHp.value = playerMaxHp;
    await world.addAll([
      Background(),
      Ground(left: minWorldX, right: maxWorldX),
      GroundDetail(),
      siegeEngine,
      playerTarget,
      AimGuide(),
      ...blocks,
      for (final b in level.defenses) CastleBlock(b, isDefense: true),
      for (final p in level.props)
        switch (p.kind) {
          PropKind.powderBarrel => PowderBarrel(p),
          PropKind.enemyCatapult => EnemyCatapult(p),
        },
      for (final u in level.units) Unit(u),
    ]);

    _levelLoaded = true;
    _fitCamera();
    _cameraBaseX = _cameraHomeX;
    camera.viewfinder.position = Vector2(_cameraBaseX, _cameraY);
    effects.audio.startMusic();
    final rounds = this.loadout.ammo;
    ammo.value = {
      for (final type in rounds.toSet())
        type: rounds.where((a) => a == type).length,
    };
    selectedAmmo.value = rounds.firstOrNull;
    overlays
      ..removeAll(_screens)
      ..add('hud');
    phase.value = SiegePhase.aiming;
  }

  static const _screens = ['menu', 'map', 'prep', 'camp', 'hud', 'result'];

  /// Level index the Siege Prep screen is preparing.
  int prepIndex = 0;

  void _showScreen(String name) {
    overlays
      ..removeAll(_screens)
      ..add(name);
    phase.value = SiegePhase.menu;
  }

  void showMenu() => _showScreen('menu');
  void showMap() => _showScreen('map');
  void showCamp() => _showScreen('camp');

  void showPrep(int index) {
    prepIndex = index;
    _showScreen('prep');
  }

  /// Spends a crew member's once-per-siege ability.
  void useCrewAbility(CrewId id) {
    if (phase.value != SiegePhase.aiming ||
        !loadout.has(id) ||
        usedAbilities.value.contains(id)) {
      return;
    }
    switch (id) {
      case CrewId.bashir:
        playerHp.value = math.min(
          playerMaxHp,
          playerHp.value + modifiers.repairAmount,
        );
        effects.repair(siegeEngine.position + Vector2(0, -3));
      case CrewId.liWei:
        revealWeakPoints = true;
      case CrewId.roxana:
        _nextShotIgnites = true;
    }
    effects.crewAbility(crewSpecs[id]!.abilityName);
    usedAbilities.value = {...usedAbilities.value, id};
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

  Vector2 launchVelocity(Vector2 pull) => pull * weapon.spec.speedPerMeter;

  void selectAmmo(AmmoType type) {
    if (phase.value != SiegePhase.aiming || (ammo.value[type] ?? 0) == 0) {
      return;
    }
    selectedAmmo.value = type;
  }

  /// Fires [type] with [pull] as if the player dragged, for automated
  /// balancing runs.
  @visibleForTesting
  void debugFire(AmmoType type, Vector2 pull) {
    ammo.value = {...ammo.value, type: (ammo.value[type] ?? 0) + 1};
    selectedAmmo.value = type;
    _fire(pull);
  }

  @visibleForTesting
  bool get debugObjectiveComplete => _objectiveComplete;

  @visibleForTesting
  bool get debugWeakPointHit => _weakPointHit;

  @visibleForTesting
  int get debugAliveUnits => _aliveUnits.length;

  @visibleForTesting
  double get debugLeadProjectileX =>
      _leadProjectileX ?? double.negativeInfinity;

  /// Furthest x reached by a projectile already in the physics world.
  /// Projectiles are tracked from the moment they are fired, a frame before
  /// their body exists.
  double? get _leadProjectileX {
    final flying = _projectiles.where((p) => p.isMounted);
    return flying.isEmpty
        ? null
        : flying.map((p) => p.body.position.x).reduce(math.max);
  }

  @visibleForTesting
  double get debugCastleFrontX => level.blocks.map((b) => b.x).reduce(math.min);

  @visibleForTesting
  void debugTap() {
    for (final p in _projectiles.toList()) {
      p.onPlayerTap();
    }
  }

  void _fire(Vector2 pull) {
    final type = selectedAmmo.value;
    if (type == null) return;
    final left = {...ammo.value, type: ammo.value[type]! - 1};
    ammo.value = left;
    if (left[type] == 0) {
      selectedAmmo.value = loadout.ammo
          .where((a) => (left[a] ?? 0) > 0)
          .firstOrNull;
    }
    _shotsUsed++;
    siegeEngine.release();
    effects.launch(ballista: weapon == WeaponType.ballista);
    addProjectile(
      Projectile(
        type: type,
        start: siegeEngine.launchOriginFor(pull),
        velocity: launchVelocity(pull),
        gravityScale: weapon.spec.gravityScale,
        forceIgnite: _nextShotIgnites,
      ),
    );
    _nextShotIgnites = false;
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
    if (!block.isDefense) _destroyedBlockHp += block.maxHp;
    effects.blockBroken(block);
  }

  void onUnitKilled(Unit unit) {
    effects.unitKilled(unit);
    _announceIfObjectiveComplete();
  }

  void onEnemyEngineDestroyed(EnemyCatapult engine) {
    effects.engineWrecked(engine.body.position);
    _announceIfObjectiveComplete();
  }

  void _announceIfObjectiveComplete() {
    if (!_objectiveAnnounced && _objectiveComplete) {
      _objectiveAnnounced = true;
      effects.objectiveComplete();
    }
  }

  void onEnemyProjectileFinished(EnemyProjectile projectile) =>
      enemy.onFinished(projectile);

  void damagePlayer(double amount, Vector2 at) {
    if (phase.value == SiegePhase.won || phase.value == SiegePhase.lost) return;
    playerHp.value = math.max(0, playerHp.value - amount);
    effects.playerHit(at, amount);
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
    } else if (phase.value == SiegePhase.enemyTurn) {
      if (enemy.tick(simDt)) _endEnemyTurn();
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
    Objective.destroyEngines => !world.children.whereType<EnemyCatapult>().any(
      (e) => !e.isDestroyed,
    ),
  };

  void _resolveShot() {
    if (_objectiveComplete) {
      _finish(won: true);
    } else if (playerHp.value <= 0) {
      _finish(won: false, defeat: DefeatReason.engineDestroyed);
    } else if (shotsLeft == 0) {
      // Out of ammo: give any fires the chance to win the siege.
      if (_anyBurning && _settleTime < _maxFireWait) return;
      _finish(won: false, defeat: DefeatReason.outOfAmmo);
    } else if (level.hasCounterFire &&
        enemy.hasShooters &&
        _shotsUsed % level.enemyFireEvery == 0) {
      phase.value = SiegePhase.enemyTurn;
      enemy.startVolley();
    } else {
      phase.value = SiegePhase.aiming;
    }
  }

  void _endEnemyTurn() {
    if (_objectiveComplete) {
      _finish(won: true);
    } else if (playerHp.value <= 0) {
      _finish(won: false, defeat: DefeatReason.engineDestroyed);
    } else {
      phase.value = SiegePhase.aiming;
    }
  }

  void _finish({required bool won, DefeatReason? defeat}) {
    final stars = starsFor(
      won: won,
      shotsUsed: _shotsUsed,
      par: level.par,
      destruction: destruction,
      weakPointHit: level.hasWeakPoints ? _weakPointHit : null,
    );
    lastResult = LevelResult(
      won: won,
      destruction: destruction,
      defeat: defeat,
      stars: stars,
      reward:
          campaign?.recordResult(
            level: level,
            won: won,
            stars: stars,
            loadout: loadout,
          ) ??
          const Reward(),
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
    final target = (_leadProjectileX ?? minX).clamp(minX, maxX);
    _cameraBaseX += (target - _cameraBaseX) * (1 - math.exp(-4 * dt));
    camera.viewfinder
      ..position = Vector2(_cameraBaseX, _cameraY) + effects.shakeOffset
      ..angle = effects.shakeAngle;
  }
}
