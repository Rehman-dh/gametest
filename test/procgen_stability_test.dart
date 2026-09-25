import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/components/structure/castle_block.dart';
import 'package:gametest/components/units/unit.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/procgen/castle_generator.dart';

/// Generated castles must stand untouched under real physics, like the
/// hand-made ones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SiegeGame build() {
    final game = SiegeGame(audioEnabled: false);
    for (final name in ['menu', 'hud', 'result']) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  for (final depth in [1, 3, 5, 6, 9, 10, 15, 25]) {
    testWithGame<SiegeGame>('generated castles at depth $depth stand', build, (
      game,
    ) async {
      final failures = <String>[];
      for (var seed = 0; seed < 25; seed++) {
        await game.startCustomLevel(CastleGenerator(seed).generate(depth));
        await game.ready();
        final blocks = game.world.children.whereType<CastleBlock>().toList();
        final units = game.world.children.whereType<Unit>().toList();
        for (var step = 0; step < 480; step++) {
          game.update(1 / 60);
        }
        final broken = blocks.where((b) => b.isDestroyed).length;
        final dead = units.where((u) => u.isDestroyed).length;
        final drifted = blocks
            .where(
              (b) =>
                  !b.isDestroyed && (b.body.position.x - b.data.x).abs() > 0.5,
            )
            .length;
        if (broken + dead + drifted > 0) {
          failures.add(
            'seed $seed: $broken broken, $dead dead, $drifted drifted',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
