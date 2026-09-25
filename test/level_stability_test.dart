import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/components/enemy/enemy_catapult.dart';
import 'package:gametest/components/structure/castle_block.dart';
import 'package:gametest/components/structure/powder_barrel.dart';
import 'package:gametest/components/units/unit.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/levels/level_data.dart';

/// Every shipped castle must stand on its own: after spawning and settling,
/// nothing may break or die before the player fires a shot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SiegeGame build() {
    final game = SiegeGame(audioEnabled: false);
    for (final name in ['menu', 'hud', 'result']) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  Future<void> run(SiegeGame game, int frames) async {
    for (var step = 0; step < frames; step++) {
      game.update(1 / 60);
      await game.ready();
    }
  }

  for (var i = 0; i < SiegeGame.levelFiles.length; i++) {
    testWithGame<SiegeGame>(
      '${SiegeGame.levelFiles[i]} stands untouched',
      build,
      (game) async {
        await game.startLevel(i);
        await game.ready();

        final blocks = game.world.children.whereType<CastleBlock>().toList();
        final units = game.world.children.whereType<Unit>().toList();
        final barrels = game.world.children.whereType<PowderBarrel>().toList();
        expect(blocks, isNotEmpty);

        // Twelve simulated seconds at 60 fps.
        await run(game, 720);

        final broken = blocks
            .where((b) => b.isDestroyed)
            .map((b) => '${b.data.x},${b.data.y}');
        final dead = units
            .where((u) => u.isDestroyed)
            .map((u) => '${u.kind.name}@${u.data.x}');
        expect(broken, isEmpty, reason: 'blocks broke on their own');
        expect(dead, isEmpty, reason: 'units died on their own');
        expect(barrels.where((b) => b.isDestroyed), isEmpty);

        // Nothing should have toppled far from where it was placed.
        for (final b in blocks) {
          final moved = (b.body.position.x - b.data.x).abs();
          expect(
            moved,
            lessThan(0.5),
            reason: 'block at ${b.data.x},${b.data.y} drifted $moved m',
          );
        }
      },
    );
  }

  // Later stages of boss sieges must also stand once they rise, on top of
  // whatever the player left of the previous stage.
  for (var i = 0; i < SiegeGame.levelFiles.length; i++) {
    testWithGame<SiegeGame>(
      '${SiegeGame.levelFiles[i]} stages rise intact',
      build,
      (game) async {
        await game.startLevel(i);
        await game.ready();
        for (var stage = 1; stage <= game.level.phases.length; stage++) {
          final before = game.world.children.whereType<CastleBlock>().toSet();

          // Meet the current objective the blunt way; the game raises the
          // next stage on its own.
          final objective = stage == 1
              ? game.level.objective
              : game.level.phases[stage - 2].objective;
          if (objective == Objective.destroyEngines) {
            for (final e
                in game.world.children.whereType<EnemyCatapult>().toList()) {
              e.destroy();
            }
          } else {
            for (final u in game.world.children.whereType<Unit>().toList()) {
              u.destroy();
            }
          }
          for (var step = 0; step < 120 && game.stage < stage; step++) {
            await run(game, 1);
          }
          expect(game.stage, stage, reason: 'stage $stage did not begin');

          final risen = game.world.children
              .whereType<CastleBlock>()
              .where((b) => !before.contains(b))
              .toList();
          final units = game.world.children.whereType<Unit>().toList();
          expect(risen, isNotEmpty, reason: 'stage $stage');

          await run(game, 480);

          expect(
            risen
                .where((b) => b.isDestroyed)
                .map((b) => '${b.data.x},${b.data.y}'),
            isEmpty,
            reason: 'stage $stage blocks broke on their own',
          );
          expect(
            units
                .where((u) => u.isDestroyed)
                .map((u) => '${u.kind.name}@${u.data.x}'),
            isEmpty,
            reason: 'stage $stage units died on their own',
          );
        }
      },
    );
  }
}
