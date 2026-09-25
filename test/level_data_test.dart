import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/ammo.dart';
import 'package:gametest/core/materials.dart';
import 'package:gametest/core/weapons.dart';
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

  test('ammo list, weapon, wind, props and weak blocks parse', () {
    final level = LevelData.parse('''
      {"id":"t","name":"T","par":1,"weapon":"trebuchet","wind":-1.5,
       "ammo":["stone","fireball","powderKeg"],
       "blocks":[{"m":"wood","x":0,"y":0,"w":1,"h":1,"weak":true}],
       "props":[{"kind":"powderBarrel","x":2,"y":0}],
       "units":[{"kind":"soldier","x":0,"y":1}]}
    ''');
    expect(level.ammo, [AmmoType.stone, AmmoType.fireball, AmmoType.powderKeg]);
    expect(level.shots, 3);
    expect(level.weapon, WeaponType.trebuchet);
    expect(level.wind, -1.5);
    expect(level.blocks.single.weak, isTrue);
    expect(level.props.single.kind, PropKind.powderBarrel);
    expect(level.hasWeakPoints, isTrue);
  });

  test('shots shorthand loads bolts for a ballista', () {
    final level = LevelData.parse('''
      {"id":"t","name":"T","shots":2,"par":1,"weapon":"ballista",
       "blocks":[],"units":[{"kind":"soldier","x":0,"y":0}]}
    ''');
    expect(level.ammo, [AmmoType.bolt, AmmoType.bolt]);
  });

  test('rejects ammo the weapon cannot fire', () {
    expect(
      () => LevelData.parse('''
        {"id":"t","name":"T","par":1,"weapon":"ballista","ammo":["fireball"],
         "blocks":[],"units":[{"kind":"soldier","x":0,"y":0}]}
      '''),
      throwsFormatException,
    );
  });
}
