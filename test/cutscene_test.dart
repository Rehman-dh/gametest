import 'dart:io';

import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/cutscene/cutscene_data.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/meta/campaign.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ids = [
    for (final f in Directory('assets/cutscenes').listSync())
      if (f.path.endsWith('.json'))
        f.uri.pathSegments.last.replaceAll('.json', ''),
  ];

  test('every cutscene parses and every level names a real one', () {
    for (final id in ids) {
      final data = CutsceneData.parse(
        File('assets/cutscenes/$id.json').readAsStringSync(),
      );
      expect(data.id, id);
      expect(data.steps, isNotEmpty);
    }
    for (final path in SiegeGame.levelFiles) {
      final json = File(path).readAsStringSync();
      for (final key in ['introCutscene', 'outroCutscene']) {
        final match = RegExp('"$key": "(\\w+)"').firstMatch(json);
        if (match != null) expect(ids, contains(match.group(1)), reason: path);
      }
    }
  });

  late Campaign campaign;

  SiegeGame build() {
    final game = SiegeGame(audioEnabled: false, campaign: campaign);
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

  for (final id in ids) {
    testWithGame<SiegeGame>('$id plays to the end', build, (game) async {
      var finished = false;
      await game.playCutscene(id, then: () => finished = true);
      await game.ready();
      // Tap through every line as a player would.
      for (var frame = 0; frame < 60 * 120 && !finished; frame++) {
        game.cutscene.value?.advance();
        game.update(1 / 60);
        await game.ready();
      }
      expect(finished, isTrue);
      expect(campaign.hasSeen(id), isTrue);
      expect(game.cutscene.value, isNull);
    });
  }

  testWithGame<SiegeGame>('skip ends a cutscene at once', build, (game) async {
    var finished = false;
    await game.playCutscene(ids.first, then: () => finished = true);
    await game.ready();
    game.update(1 / 60);
    game.cutscene.value!.skip();
    for (var frame = 0; frame < 10 && !finished; frame++) {
      game.update(1 / 60);
      await game.ready();
    }
    expect(finished, isTrue);
  });
}
