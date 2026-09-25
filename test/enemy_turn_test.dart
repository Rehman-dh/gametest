import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/components/enemy/enemy_catapult.dart';
import 'package:gametest/components/structure/castle_block.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/game/siege_game.dart';

int _levelIndex(String id) =>
    SiegeGame.levelFiles.indexWhere((f) => f.endsWith('$id.json'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SiegeGame build() {
    final game = SiegeGame(audioEnabled: false, random: math.Random(7));
    for (final name in ['menu', 'hud', 'result']) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  /// Steps the game, letting components added mid-frame finish loading
  /// as they would between real frames.
  Future<void> step(SiegeGame game) async {
    game.update(1 / 60);
    await game.ready();
  }

  Future<void> run(SiegeGame game, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await step(game);
    }
  }

  testWithGame<SiegeGame>(
    'archers return fire after each shot and wear the engine down',
    build,
    (game) async {
      await game.startLevel(_levelIndex('egypt_08'));
      await game.ready();
      await run(game, 1.5);
      final startHp = game.playerHp.value;

      for (var volley = 1; volley <= 3; volley++) {
        // A feeble shot that lands far short of the castle.
        game.debugFire(AmmoType.stone, Vector2(1.2, -0.2));
        var sawEnemyTurn = false;
        for (
          var i = 0;
          i < 60 * 20 && game.phase.value != SiegePhase.aiming;
          i++
        ) {
          await step(game);
          if (game.phase.value == SiegePhase.enemyTurn) sawEnemyTurn = true;
        }
        expect(sawEnemyTurn, isTrue, reason: 'volley $volley');
        expect(game.phase.value, SiegePhase.aiming);
        expect(game.enemy.volleys, volley);
      }
      expect(game.playerHp.value, lessThan(startHp));
    },
  );

  testWithGame<SiegeGame>('engineers patch damaged blocks', build, (
    game,
  ) async {
    await game.startLevel(_levelIndex('egypt_09'));
    await game.ready();
    await run(game, 1.5);
    final block = game.world.children.whereType<CastleBlock>().first;
    block.takeDamage(30);
    final damaged = block.hp;
    await run(game, 4);
    expect(block.hp, greaterThan(damaged));
  });

  testWithGame<SiegeGame>(
    'defense mission is won by wrecking every enemy engine',
    build,
    (game) async {
      await game.startLevel(_levelIndex('egypt_14'));
      await game.ready();
      await run(game, 1.5);
      final engines = game.world.children.whereType<EnemyCatapult>().toList();
      expect(engines, hasLength(2));
      engines.first.destroy();
      await run(game, 0.5);
      expect(game.phase.value, SiegePhase.aiming);
      engines.last.destroy();
      await run(game, 0.5);
      expect(game.phase.value, SiegePhase.won);
    },
  );
}
