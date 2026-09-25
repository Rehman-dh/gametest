// Balancing report, skipped in the regular suite. Run with:
//   flutter test --tags balance --run-skipped
// or one level (0-based): add --dart-define=level=4
//
// For every level and every ammo type the level offers, fires one shot at
// each point of an aim grid and reports how often a single shot wins, breaks
// the weak point, and how much castle it destroys on average.
@Tags(['balance'])
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/game/siege_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SiegeGame build() {
    final game = SiegeGame(audioEnabled: false);
    for (final name in ['menu', 'hud', 'result']) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  final onlyLevel = int.tryParse(const String.fromEnvironment('level'));

  for (var level = 0; level < SiegeGame.levelFiles.length; level++) {
    if (onlyLevel != null && onlyLevel != level) continue;
    testWithGame<SiegeGame>('balance ${SiegeGame.levelFiles[level]}', build, (
      game,
    ) async {
      await game.startLevel(level);
      final types = game.level.ammo.toSet();
      final lines = <String>[];
      for (final type in types) {
        var shots = 0, wins = 0, weak = 0, kills = 0;
        var destruction = 0.0;
        for (var angle = 8.0; angle <= 68; angle += 4) {
          for (var power = 2.0; power <= 7.0; power += 0.5) {
            await game.startLevel(level);
            await game.ready();
            // Let the castle settle and the damage grace period pass.
            for (var i = 0; i < 90; i++) {
              game.update(1 / 60);
            }
            final a = angle * math.pi / 180;
            game.debugFire(type, Vector2(math.cos(a), -math.sin(a)) * power);
            // Tap-activated ammo triggers near the castle's front.
            // Fire needs longer to do its work.
            final seconds = type.spec.ignites ? 16 : 7;
            final alive = game.debugAliveUnits;
            var tapped = false;
            for (var i = 0; i < 60 * seconds; i++) {
              game.update(1 / 60);
              if (!tapped &&
                  (type.spec.splitsOnTap || type.spec.explodes) &&
                  game.debugLeadProjectileX >= game.debugCastleFrontX - 6) {
                tapped = true;
                game.debugTap();
              }
            }
            shots++;
            if (game.debugObjectiveComplete) wins++;
            if (game.debugWeakPointHit) weak++;
            kills += alive - game.debugAliveUnits;
            destruction += game.destruction;
          }
        }
        String pct(int n) => '${(100 * n / shots).toStringAsFixed(0)}%';
        lines.add(
          '  ${type.name.padRight(10)} one-shot wins ${pct(wins).padLeft(4)}'
          '  weak point ${pct(weak).padLeft(4)}'
          '  avg destroyed ${(100 * destruction / shots).toStringAsFixed(0)}%'
          '  kills/shot ${(kills / shots).toStringAsFixed(2)}',
        );
      }
      // ignore: avoid_print
      print(
        '\n${game.level.id} "${game.level.name}" '
        '(par ${game.level.par}, ${game.level.shots} shots, '
        'wind ${game.level.wind})\n${lines.join('\n')}',
      );
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}
