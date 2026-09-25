import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/materials.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/levels/level_data.dart';

void main() {
  test('parses a minimal level', () {
    final level = LevelData.parse('''
      {"id":"t","name":"Test","shots":2,"par":1,"objective":"killKing",
       "blocks":[{"m":"stone","x":1,"y":0,"w":1,"h":2,"a":15}],
       "units":[{"kind":"king","x":1,"y":2}]}
    ''');
    expect(level.worldWidth, 60);
    expect(level.blocks.single.material, BlockMaterial.stone);
    expect(level.blocks.single.angle, 15);
    expect(level.units.single.kind, UnitKind.king);
  });

  test('rejects unknown materials and king-less killKing levels', () {
    expect(
      () => LevelData.parse('''
        {"id":"t","name":"T","shots":1,"par":1,
         "blocks":[{"m":"cheese","x":0,"y":0,"w":1,"h":1}],"units":[]}
      '''),
      throwsFormatException,
    );
    expect(
      () => LevelData.parse('''
        {"id":"t","name":"T","shots":1,"par":1,"objective":"killKing",
         "blocks":[],"units":[{"kind":"soldier","x":0,"y":0}]}
      '''),
      throwsFormatException,
    );
  });

  test('every shipped level file parses', () {
    for (final path in SiegeGame.levelFiles) {
      final level = LevelData.parse(File(path).readAsStringSync());
      expect(level.units, isNotEmpty, reason: path);
      expect(level.par, lessThanOrEqualTo(level.shots), reason: path);
    }
  });
}
