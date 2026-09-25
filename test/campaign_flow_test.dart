import 'dart:math' as math;

import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/components/units/unit.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/core/weapons.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/meta/campaign.dart';
import 'package:gametest/meta/catalog.dart';
import 'package:gametest/meta/loadout.dart';
import 'package:gametest/meta/progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Campaign campaign;

  SiegeGame build() {
    final game = SiegeGame(
      audioEnabled: false,
      random: math.Random(1),
      campaign: campaign,
    );
    for (final name in ['menu', 'map', 'prep', 'camp', 'hud', 'result']) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  setUp(() async {
    campaign = Campaign(levelFiles: SiegeGame.levelFiles);
    await campaign.load();
  });

  testWithGame<SiegeGame>(
    'winning a siege records stars and pays gold',
    build,
    (game) async {
      expect(campaign.isUnlocked(1), isFalse);
      await game.startLevel(0);
      await game.ready();
      for (final unit in game.world.children.whereType<Unit>().toList()) {
        unit.destroy();
      }
      game.update(1 / 60);
      await game.ready();

      expect(game.phase.value, SiegePhase.won);
      final progress = campaign.progress.value;
      expect(progress.isWon('egypt_01'), isTrue);
      expect(progress.gold, game.lastResult!.reward.gold);
      expect(progress.gold, greaterThan(0));
      expect(campaign.isUnlocked(1), isTrue);
    },
  );

  testWithGame<SiegeGame>(
    'crew shape the siege and spend abilities once',
    build,
    (game) async {
      campaign.progress.value = const Progress(
        crewXp: {CrewId.bashir: 0, CrewId.liWei: 0},
      );
      final index = SiegeGame.levelFiles.indexWhere(
        (f) => f.endsWith('egypt_08.json'),
      );
      await game.startLevel(
        index,
        loadout: const Loadout(
          weapon: WeaponType.catapult,
          ammo: [AmmoType.stone, AmmoType.stone],
          crew: [CrewId.bashir, CrewId.liWei],
        ),
      );
      await game.ready();

      expect(game.playerMaxHp, game.level.playerHp + 10);
      expect(game.modifiers.trajectoryMultiplier, greaterThan(1));

      game.playerHp.value = 20;
      game.useCrewAbility(CrewId.bashir);
      expect(game.playerHp.value, 45);
      game.useCrewAbility(CrewId.bashir);
      expect(game.playerHp.value, 45, reason: 'only once per siege');

      expect(game.revealWeakPoints, isFalse);
      game.useCrewAbility(CrewId.liWei);
      expect(game.revealWeakPoints, isTrue);
      expect(game.usedAbilities.value, {CrewId.bashir, CrewId.liWei});
    },
  );
}
