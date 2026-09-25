import '../levels/level_data.dart';
import 'catalog.dart';
import 'progress.dart';

/// What a finished siege pays out.
class Reward {
  const Reward({
    this.gold = 0,
    this.relic,
    this.crew,
    this.crewLevelUps = const [],
  });

  final int gold;
  final RelicId? relic;
  final CrewId? crew;
  final List<CrewId> crewLevelUps;
}

/// Gold for a win: a first-clear bonus plus 20 per star above the previous
/// best, so replays pay only for improvement. Trophy Hall and the Eye of
/// Horus raise it.
int goldFor({
  required Progress progress,
  required int stars,
  required int? previousBest,
}) {
  final base = previousBest == null
      ? 40 + 20 * stars
      : 10 + 20 * (stars - previousBest).clamp(0, 3);
  var multiplier = 1 + 0.1 * progress.building(BuildingId.trophyHall);
  if (progress.relics.contains(RelicId.eyeOfHorus)) multiplier += 0.2;
  return (base * multiplier).round();
}

/// Applies a finished siege to [progress]; returns the new progress and
/// what was earned. Losses change nothing.
(Progress, Reward) applyResult({
  required Progress progress,
  required LevelData level,
  required bool won,
  required int stars,
  required List<CrewId> crew,
}) {
  if (!won) return (progress, const Reward());
  final previous = progress.stars[level.id];
  final gold = goldFor(
    progress: progress,
    stars: stars,
    previousBest: previous,
  );

  final barracks = progress.building(BuildingId.barracks);
  final xpMultiplier = barracks >= 3 ? 2.0 : (barracks >= 2 ? 1.5 : 1.0);
  final crewXp = {...progress.crewXp};
  final levelUps = <CrewId>[];
  for (final id in crew) {
    final before = crewLevelFor(crewXp[id] ?? 0);
    crewXp[id] = (crewXp[id] ?? 0) + (stars * xpMultiplier).round();
    if (crewLevelFor(crewXp[id]!) > before) levelUps.add(id);
  }

  final newCrew = level.unlocksCrew;
  final joined = newCrew != null && !crewXp.containsKey(newCrew);
  if (joined) crewXp[newCrew] = 0;

  final relic = level.relic;
  final foundRelic = relic != null && !progress.relics.contains(relic);

  final updated = progress.copyWith(
    gold: progress.gold + gold,
    stars: {
      ...progress.stars,
      level.id: previous == null || stars > previous ? stars : previous,
    },
    crewXp: crewXp,
    relics: {...progress.relics, if (foundRelic) relic},
  );
  return (
    updated,
    Reward(
      gold: gold,
      relic: foundRelic ? relic : null,
      crew: joined ? newCrew : null,
      crewLevelUps: levelUps,
    ),
  );
}

/// Buys the next level of [building], or returns null if unaffordable or
/// already maxed.
Progress? upgradeBuilding(Progress progress, BuildingId building) {
  final spec = buildingSpecs[building]!;
  final level = progress.building(building);
  if (level >= spec.maxLevel) return null;
  final cost = spec.costs[level];
  if (progress.gold < cost) return null;
  return progress.copyWith(
    gold: progress.gold - cost,
    buildings: {...progress.buildings, building: level + 1},
  );
}
