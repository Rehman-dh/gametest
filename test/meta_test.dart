import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/core/weapons.dart';
import 'package:gametest/levels/level_data.dart';
import 'package:gametest/meta/catalog.dart';
import 'package:gametest/meta/loadout.dart';
import 'package:gametest/meta/progress.dart';
import 'package:gametest/meta/rewards.dart';

LevelData _level({String extra = ''}) => LevelData.parse('''
  {"id":"t1","name":"T","par":2,"ammo":["stone","stone","fireball"],
   "blocks":[],"units":[{"kind":"soldier","x":0,"y":0}] $extra}
''');

void main() {
  group('Progress', () {
    test('survives a save round trip', () {
      const progress = Progress(
        gold: 250,
        stars: {'egypt_01': 3},
        buildings: {BuildingId.workshop: 2},
        crewXp: {CrewId.bashir: 7},
        relics: {RelicId.scarabAmulet},
      );
      final restored = Progress.decode(progress.encode());
      expect(restored.gold, 250);
      expect(restored.stars, {'egypt_01': 3});
      expect(restored.building(BuildingId.workshop), 2);
      expect(restored.crewLevel(CrewId.bashir), 2);
      expect(restored.relics, {RelicId.scarabAmulet});
    });

    test('ignores unknown names from a newer save', () {
      final p = Progress.decode(
        '{"gold":5,"buildings":{"moonBase":3},"crewXp":{"nobody":1},"relics":["x"]}',
      );
      expect(p.gold, 5);
      expect(p.buildings, isEmpty);
      expect(p.crewXp, isEmpty);
      expect(p.relics, isEmpty);
    });
  });

  group('rewards', () {
    test('first clear pays a bonus; replays pay only for new stars', () {
      const p = Progress();
      expect(goldFor(progress: p, stars: 2, previousBest: null), 80);
      expect(goldFor(progress: p, stars: 3, previousBest: 2), 30);
      expect(goldFor(progress: p, stars: 1, previousBest: 3), 10);
    });

    test('trophy hall and eye of horus raise gold', () {
      const p = Progress(
        buildings: {BuildingId.trophyHall: 2},
        relics: {RelicId.eyeOfHorus},
      );
      expect(goldFor(progress: p, stars: 1, previousBest: null), 84);
    });

    test('a win records stars, crew xp, relics and new crew once', () {
      final level = _level(
        extra: ',"relic":"scarabAmulet","unlocksCrew":"liWei"',
      );
      var (p, reward) = applyResult(
        progress: const Progress(crewXp: {CrewId.bashir: 4}),
        level: level,
        won: true,
        stars: 3,
        crew: const [CrewId.bashir],
      );
      expect(p.stars['t1'], 3);
      expect(reward.relic, RelicId.scarabAmulet);
      expect(reward.crew, CrewId.liWei);
      expect(reward.crewLevelUps, [CrewId.bashir]);
      expect(p.hasCrew(CrewId.liWei), isTrue);

      (p, reward) = applyResult(
        progress: p,
        level: level,
        won: true,
        stars: 1,
        crew: const [],
      );
      expect(p.stars['t1'], 3, reason: 'best rating is kept');
      expect(reward.relic, isNull);
      expect(reward.crew, isNull);
    });

    test('a loss changes nothing', () {
      const p = Progress(gold: 10);
      final (after, reward) = applyResult(
        progress: p,
        level: _level(),
        won: false,
        stars: 0,
        crew: const [],
      );
      expect(identical(after, p), isTrue);
      expect(reward.gold, 0);
    });

    test('buildings cost gold and stop at max level', () {
      var p = const Progress(gold: 1000);
      p = upgradeBuilding(p, BuildingId.workshop)!;
      expect(p.gold, 850);
      p = upgradeBuilding(p, BuildingId.workshop)!;
      p = upgradeBuilding(p, BuildingId.workshop)!;
      expect(p.building(BuildingId.workshop), 3);
      expect(upgradeBuilding(p, BuildingId.workshop), isNull);
      expect(
        upgradeBuilding(const Progress(gold: 10), BuildingId.barracks),
        isNull,
      );
    });
  });

  group('Armory', () {
    test(
      'budget defaults to the suggested loadout, raised by the war room',
      () {
        final level = _level();
        expect(const Armory(Progress()).budgetFor(level), 120);
        const withWarRoom = Progress(buildings: {BuildingId.warRoom: 2});
        expect(const Armory(withWarRoom).budgetFor(level), 156);
      },
    );

    test('alchemy makes ammo cheaper and unlocks more of it', () {
      final level = _level();
      const basic = Armory(Progress());
      expect(basic.ammoFor(level, WeaponType.catapult), [
        AmmoType.stone,
        AmmoType.fireball,
      ]);
      const alchemist = Armory(Progress(buildings: {BuildingId.alchemy: 2}));
      expect(alchemist.priceOf(AmmoType.stone), 24);
      expect(
        alchemist.ammoFor(level, WeaponType.catapult),
        containsAll([AmmoType.cluster, AmmoType.powderKeg]),
      );
      expect(alchemist.ammoFor(level, WeaponType.ballista), [AmmoType.bolt]);
    });

    test('weapons unlock through the workshop unless the level locks one', () {
      expect(const Armory(Progress()).weaponsFor(_level()), [
        WeaponType.catapult,
      ]);
      const workshop = Armory(Progress(buildings: {BuildingId.workshop: 2}));
      expect(workshop.weaponsFor(_level()), hasLength(3));
      final locked = LevelData.parse('''
        {"id":"b","name":"B","par":1,"shots":2,"weapon":"ballista",
         "blocks":[],"units":[{"kind":"soldier","x":0,"y":0}]}
      ''');
      expect(workshop.weaponsFor(locked), [WeaponType.ballista]);
    });
  });

  test('crew and relics feed into siege modifiers', () {
    const progress = Progress(
      crewXp: {CrewId.bashir: 0, CrewId.roxana: 12},
      relics: {RelicId.scarabAmulet},
    );
    final m = Modifiers.from(
      progress,
      const Loadout(
        weapon: WeaponType.catapult,
        ammo: [AmmoType.stone],
        crew: [CrewId.bashir, CrewId.roxana],
      ),
    );
    expect(m.engineHpBonus, 25);
    expect(m.repairAmount, 25);
    expect(m.barricadeHpMultiplier, closeTo(1.2, 1e-9));
    expect(m.fireMultiplier, closeTo(1.3, 1e-9));
    expect(m.trajectoryMultiplier, 1);
  });
}
