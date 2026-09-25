import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/components/units/unit.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/meta/campaign.dart';
import 'package:gametest/meta/endless.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EndlessRun', () {
    test('points reward depth, saved shots, destruction and bosses', () {
      expect(
        EndlessRun.pointsFor(
          depth: 1,
          par: 3,
          shotsUsed: 2,
          destruction: 0.5,
          boss: false,
        ),
        100 + 25 + 40 + 50,
      );
      expect(
        EndlessRun.pointsFor(
          depth: 5,
          par: 3,
          shotsUsed: 6,
          destruction: 0,
          boss: true,
        ),
        100 + 125 + 500,
      );
    });

    test('leftover ammo carries over and is restocked', () {
      final run = EndlessRun(seed: 9);
      run.recordVictory(
        ammoLeft: {AmmoType.stone: 1, AmmoType.fireball: 0},
        engineHpLeft: 70,
        engineMaxHp: 100,
        shotsUsed: 3,
        destruction: 0.4,
      );
      expect(run.depth, 2);
      expect(run.castlesTaken, 1);
      expect(run.pool[AmmoType.stone], 4);
      expect(run.pool.values.fold(0, (a, b) => a + b), 5);
      expect(run.engineHp, 70);
    });

    test('a boss castle repairs the engine', () {
      final run = EndlessRun(seed: 1)..depth = 5;
      run.recordVictory(
        ammoLeft: const {},
        engineHpLeft: 30,
        engineMaxHp: 100,
        shotsUsed: 1,
        destruction: 1,
      );
      expect(run.engineHp, 70);
      expect(run.pool.values.fold(0, (a, b) => a + b), 6);
    });
  });

  late Campaign campaign;

  SiegeGame build() {
    final game = SiegeGame(
      audioEnabled: false,
      random: math.Random(3),
      campaign: campaign,
    );
    for (final name in [
      'menu',
      'map',
      'prep',
      'camp',
      'hud',
      'result',
      'cutscene',
    ]) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  setUp(() async {
    campaign = Campaign(levelFiles: SiegeGame.levelFiles);
    await campaign.load();
  });

  Future<void> run(SiegeGame game, int frames) async {
    for (var i = 0; i < frames; i++) {
      game.update(1 / 60);
      await game.ready();
    }
  }

  testWithGame<SiegeGame>(
    'a run goes castle to castle and banks its score',
    build,
    (game) async {
      await game.startEndless();
      await game.ready();
      expect(game.level.name, 'Castle 1');

      // Take the first castle.
      for (final u in game.world.children.whereType<Unit>().toList()) {
        u.destroy();
      }
      await run(game, 2);
      expect(game.phase.value, SiegePhase.won);
      final taken = game.lastResult!.endless!;
      expect(taken.runOver, isFalse);
      expect(taken.points, greaterThan(0));

      game.continueEndless();
      await run(game, 2);
      expect(game.level.name, 'Castle 2');

      // Lose the second: fire the only round short and run dry.
      game.ammo.value = const {};
      game.debugFire(AmmoType.stone, Vector2(1.2, -0.2));
      for (var i = 0; i < 60 * 20 && game.phase.value != SiegePhase.lost; i++) {
        await run(game, 1);
      }
      expect(game.phase.value, SiegePhase.lost);
      final over = game.lastResult!.endless!;
      expect(over.runOver, isTrue);
      expect(over.score, taken.score);
      expect(game.endless, isNull);
      expect(campaign.progress.value.endlessBest, taken.score);
      expect(campaign.progress.value.gold, over.gold);
    },
  );
}
