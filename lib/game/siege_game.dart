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
import '../components/projectiles/stone_projectile.dart';
import '../components/structure/castle_block.dart';
import '../components/structure/debris_shard.dart';
import '../components/units/unit.dart';
import '../components/weapons/catapult.dart';
import '../core/scoring.dart';
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

class SiegeGame extends Forge2DGame with DragCallbacks {
  SiegeGame({ArtTheme? theme})
    : theme = theme ?? StylizedTheme(),
      super(gravity: Vector2(0, 12));

  static const levelFiles = [
    'assets/levels/egypt_01.json',
    'assets/levels/egypt_02.json',
    'assets/levels/egypt_03.json',
  ];

  /// Drag distances in world meters.
  static const minPull = 1.0;
  static const maxPull = 7.0;
  static const _launchSpeedPerMeter = 4.3;

  /// Physics settles for this long after spawning before damage counts,
  /// so a castle doesn't hurt itself while blocks find their rest.
  static const _damageGracePeriod = 1.2;

  /// Minimum world height kept on screen, in meters.
  static const _minViewHeight = 20.0;

  /// Empty ground shown behind the catapult, in meters.
  static const _marginBehindCatapult = 9.0;

  final ArtTheme theme;
  late final Effects effects = Effects(this);

  /// Unscaled seconds since start, for ambient animation.
  double realTime = 0;

  final ValueNotifier<SiegePhase> phase = ValueNotifier(SiegePhase.menu);
  final ValueNotifier<int> shotsLeft = ValueNotifier(0);
  LevelResult? lastResult;

  late LevelData level;
  int levelIndex = 0;
  late Catapult catapult;

  bool get hasNextLevel => levelIndex + 1 < levelFiles.length;
  double get minWorldX => level.catapultX - 30;
  double get maxWorldX => level.worldWidth + 30;
  bool get damageEnabled => _levelTime > _damageGracePeriod;

  bool _levelLoaded = false;
  bool _objectiveAnnounced = false;
  double _cameraBaseX = 0;
  double _levelTime = 0;
  double _settleTime = 0;
  int _shotsUsed = 0;
  double _totalBlockHp = 0;
  double _destroyedBlockHp = 0;
  StoneProjectile? _projectile;
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
    effects.reset();
    _shotsUsed = 0;
    _destroyedBlockHp = 0;
    _totalBlockHp = 0;
    _projectile = null;
    _dragStart = null;
    _pull = null;
    lastResult = null;

    final blocks = [for (final b in level.blocks) CastleBlock(b)];
    for (final b in blocks) {
      _totalBlockHp += b.maxHp;
    }
    catapult = Catapult(x: level.catapultX);
    await world.addAll([
      Background(),
      Ground(left: minWorldX, right: maxWorldX),
      GroundDetail(),
      catapult,
      AimGuide(),
      ...blocks,
      for (final u in level.units) Unit(u),
    ]);

    _levelLoaded = true;
    _fitCamera();
    _cameraBaseX = _cameraHomeX;
    camera.viewfinder.position = Vector2(_cameraBaseX, _cameraY);
    effects.audio.startMusic();
    shotsLeft.value = level.shots;
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

  Vector2 launchVelocity(Vector2 pull) => pull * _launchSpeedPerMeter;

  void _fire(Vector2 pull) {
    shotsLeft.value--;
    _shotsUsed++;
    catapult.release();
    effects.launch();
    _projectile = StoneProjectile(
      start: catapult.launchOrigin,
      velocity: launchVelocity(pull),
    );
    world.add(_projectile!);
    phase.value = SiegePhase.flying;
  }

  // ------------------------------------------------------- world callbacks

  void onProjectileFinished(StoneProjectile projectile) {
    if (projectile != _projectile) return;
    _projectile = null;
    _settleTime = 0;
    phase.value = SiegePhase.settling;
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

  // ---------------------------------------------------------------- update

  @override
  void update(double dt) {
    realTime += dt;
    effects.tick(dt);
    final simDt = dt * effects.timeScale;
    super.update(simDt);
    if (phase.value == SiegePhase.menu) return;
    _levelTime += simDt;
    _updateCamera(dt);

    if (phase.value == SiegePhase.settling) {
      _settleTime += simDt;
      if (_settleTime > 0.6 && (_worldAtRest() || _settleTime > 4)) {
        _resolveShot();
      }
    }
  }

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
    } else if (shotsLeft.value == 0) {
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
    final target = (_projectile?.body.position.x ?? minX).clamp(minX, maxX);
    _cameraBaseX += (target - _cameraBaseX) * (1 - math.exp(-4 * dt));
    camera.viewfinder
      ..position = Vector2(_cameraBaseX, _cameraY) + effects.shakeOffset
      ..angle = effects.shakeAngle;
  }
}
