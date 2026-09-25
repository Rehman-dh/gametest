import 'dart:math' as math;

import '../core/ammo.dart';
import '../levels/level_data.dart';
import '../procgen/castle_generator.dart';

/// One endless-mode run: an unending line of generated castles. Ammunition
/// and engine damage carry from castle to castle; losing one ends the run.
class EndlessRun {
  EndlessRun({required this.seed});

  final int seed;
  int depth = 1;
  int score = 0;
  int castlesTaken = 0;

  /// Ammunition carried into the next castle.
  Map<AmmoType, int> pool = {
    AmmoType.stone: 6,
    AmmoType.fireball: 1,
    AmmoType.cluster: 1,
  };

  /// Engine hit points carried over; null means undamaged.
  double? engineHp;

  static const _bossRepair = 40.0;

  LevelData get castle => CastleGenerator(seed).generate(depth);
  bool get atBoss => CastleGenerator.isBossDepth(depth);

  List<AmmoType> get rounds => [
    for (final type in AmmoType.values)
      for (var i = 0; i < (pool[type] ?? 0); i++) type,
  ];

  /// Points for taking the current castle: a base that grows with depth,
  /// a bonus per shot saved under par, destruction, and a boss bounty.
  static int pointsFor({
    required int depth,
    required int par,
    required int shotsUsed,
    required double destruction,
    required bool boss,
  }) =>
      100 +
      25 * depth +
      40 * math.max<int>(0, par - shotsUsed) +
      (100 * destruction).round() +
      (boss ? 500 : 0);

  /// Records a taken castle and moves on; returns the points earned.
  int recordVictory({
    required Map<AmmoType, int> ammoLeft,
    required double engineHpLeft,
    required double engineMaxHp,
    required int shotsUsed,
    required double destruction,
  }) {
    final current = castle;
    final boss = atBoss;
    final points = pointsFor(
      depth: depth,
      par: current.par,
      shotsUsed: shotsUsed,
      destruction: destruction,
      boss: boss,
    );
    score += points;
    castlesTaken++;

    // Restock: three stones and a special every castle, more after a boss.
    final rng = math.Random(seed * 31 + depth);
    final specials = [
      AmmoType.fireball,
      AmmoType.cluster,
      if (depth >= 3) AmmoType.powderKeg,
    ];
    final next = {...ammoLeft}..removeWhere((_, n) => n <= 0);
    void add(AmmoType type, int n) => next[type] = (next[type] ?? 0) + n;
    add(AmmoType.stone, 3);
    for (var i = 0; i < (boss ? 3 : 1); i++) {
      add(specials[rng.nextInt(specials.length)], 1);
    }
    pool = next;
    engineHp = math.min(engineMaxHp, engineHpLeft + (boss ? _bossRepair : 0));
    depth++;
    return points;
  }

  /// Gold paid into the campaign when the run ends.
  int get goldEarned => score ~/ 20;
}
