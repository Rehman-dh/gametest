// Enemy accuracy report, skipped in the regular suite. Run with:
//   flutter test --tags balance --run-skipped test/balance/enemy_accuracy_test.dart
@Tags(['balance'])
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/game/siege_game.dart';

/// Lets the enemy fire [volleys] times at an idle player (whose own shots
/// land short) and reports average engine damage per volley.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seeds = 10;
  const volleys = 5;
  final damage = <String, List<double>>{};
  final engineHp = <String, double>{};

  for (final id in ['egypt_08', 'egypt_09', 'egypt_10']) {
    final index = SiegeGame.levelFiles.indexWhere(
      (f) => f.endsWith('$id.json'),
    );
    damage[id] = List.filled(volleys, 0);
    for (var seed = 0; seed < seeds; seed++) {
      testWithGame<SiegeGame>(
        'enemy accuracy $id seed $seed',
        () {
          final game = SiegeGame(
            audioEnabled: false,
            random: math.Random(seed),
          );
          for (final name in ['menu', 'hud', 'result']) {
            game.overlays.addEntry(name, (_, _) => const SizedBox());
          }
          return game;
        },
        (game) async {
          await game.startLevel(index);
          await game.ready();
          engineHp[id] = game.level.playerHp;
          for (var v = 0; v < volleys; v++) {
            final before = game.playerHp.value;
            game.debugFire(AmmoType.stone, Vector2(1.2, -0.2));
            for (var i = 0; i < 60 * 25; i++) {
              game.update(1 / 60);
              await game.ready();
              if (game.phase.value == SiegePhase.aiming ||
                  game.phase.value == SiegePhase.lost) {
                break;
              }
            }
            damage[id]![v] += before - game.playerHp.value;
            if (game.phase.value == SiegePhase.lost) break;
          }
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }
  }

  tearDownAll(() {
    for (final MapEntry(key: id, value: perVolley) in damage.entries) {
      // ignore: avoid_print
      print(
        '$id (engine ${engineHp[id]?.round()} hp) avg damage per volley: '
        '${perVolley.map((d) => (d / seeds).toStringAsFixed(1)).join('  ')}',
      );
    }
  });
}
