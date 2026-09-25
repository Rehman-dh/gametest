import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/components/structure/castle_block.dart';
import 'package:gametest/components/structure/powder_barrel.dart';
import 'package:gametest/components/units/unit.dart';
import 'package:gametest/game/siege_game.dart';

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
        for (var step = 0; step < 720; step++) {
          game.update(1 / 60);
        }

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
}
