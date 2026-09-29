// Greedy solver: plays a level shot by shot, each time picking the best
// of a grid of shots, to check that a win is reachable within par.
//   flutter test test/tool/solve_level_test.dart --tags tool --run-skipped \
//     --dart-define=level=4
@Tags(['tool'])
library;

import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/game/siege_game.dart';

const _win = 1e6;

class _Shot {
  const _Shot(this.type, this.angle, this.power);
  final AmmoType type;
  final double angle, power;
  @override
  String toString() => '${type.name}@${angle.round()}°/$power';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final level = int.parse(
    const String.fromEnvironment('level', defaultValue: '0'),
  );

  SiegeGame build() {
    final game = SiegeGame(audioEnabled: false, random: math.Random(1));
    for (final name in ['menu', 'hud', 'result', 'cutscene']) {
      game.overlays.addEntry(name, (_, _) => const SizedBox());
    }
    return game;
  }

  Future<void> step(SiegeGame g, int frames) async {
    for (var i = 0; i < frames; i++) {
      g.update(1 / 60);
      await g.ready();
    }
  }

  /// Replays [shots] from a fresh start; returns a score for the outcome.
  Future<double> play(SiegeGame g, List<_Shot> shots) async {
    await g.startLevel(level);
    await g.ready();
    await step(g, 90);
    for (final s in shots) {
      if (g.phase.value != SiegePhase.aiming) break;
      final a = s.angle * math.pi / 180;
      g.debugFire(s.type, Vector2(math.cos(a), -math.sin(a)) * s.power);
      var tapped = false;
      // Until the shot resolves and any enemy turn is over (max 25 s).
      for (var f = 0; f < 60 * 25; f++) {
        await step(g, 1);
        if (!tapped &&
            s.type.spec.splitsOnTap &&
            g.debugLeadProjectileX >= g.debugCastleFrontX - 6) {
          tapped = true;
          g.debugTap();
        }
        final p = g.phase.value;
        if (f > 30 &&
            (p == SiegePhase.aiming ||
                p == SiegePhase.won ||
                p == SiegePhase.lost)) {
          break;
        }
      }
      if (s.type.spec.ignites) await step(g, 60 * 8);
    }
    final won = g.debugObjectiveComplete || g.phase.value == SiegePhase.won;
    // A win outranks any loss; among either, fewer defenders and more
    // damage are better.
    return (won ? _win : 0) - g.debugAliveUnits * 1000 + g.destruction * 100;
  }

  testWithGame<SiegeGame>('solve', build, (g) async {
    await g.startLevel(level);
    // Let the first load finish before replays restart the level.
    await g.ready();
    final loadout = g.loadout.ammo;
    final par = g.level.par;
    final shots = <_Shot>[];
    var best = double.negativeInfinity;
    for (var depth = 0; depth < loadout.length; depth++) {
      final remaining = [...loadout];
      for (final s in shots) {
        remaining.remove(s.type);
      }
      _Shot? pick;
      var pickScore = double.negativeInfinity;
      for (final type in remaining.toSet()) {
        for (var angle = 10.0; angle <= 70; angle += 6) {
          for (var power = 3.0; power <= 7.0; power += 0.5) {
            final shot = _Shot(type, angle, power);
            final score = await play(g, [...shots, shot]);
            if (score > pickScore) {
              pickScore = score;
              pick = shot;
            }
          }
        }
      }
      shots.add(pick!);
      best = pickScore;
      if (best >= _win / 2) break;
    }
    final won = best >= _win / 2;
    // ignore: avoid_print
    print(
      'RESULT ${g.level.id} par $par shots ${loadout.length}: '
      '${won ? 'WIN in ${shots.length}' : 'NO WIN'} '
      '${won && shots.length <= par ? '(within par)' : '(over par)'} '
      '$shots',
    );
  }, timeout: const Timeout(Duration(minutes: 40)));
}
