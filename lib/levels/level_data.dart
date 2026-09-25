import 'dart:convert';

import '../core/materials.dart';

/// Level files use a y-up coordinate system measured from the ground
/// (y = distance of an object's *bottom* above the ground), which is
/// intuitive to author. Components convert to Forge2D's y-down space.

enum Objective { killAll, killKing }

enum UnitKind { soldier, king }

class BlockData {
  const BlockData({
    required this.material,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.angle = 0,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) => BlockData(
    material: BlockMaterialSpec.parse(json['m'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['w'] as num).toDouble(),
    height: (json['h'] as num).toDouble(),
    angle: (json['a'] as num? ?? 0).toDouble(),
  );

  final BlockMaterial material;
  final double x, y, width, height, angle;
}

class UnitData {
  const UnitData({required this.kind, required this.x, required this.y});

  factory UnitData.fromJson(Map<String, dynamic> json) => UnitData(
    kind: UnitKind.values.byName(json['kind'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  final UnitKind kind;
  final double x, y;
}

class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.worldWidth,
    required this.catapultX,
    required this.shots,
    required this.par,
    required this.objective,
    required this.blocks,
    required this.units,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final level = LevelData(
      id: json['id'] as String,
      name: json['name'] as String,
      worldWidth: (json['worldWidth'] as num? ?? 60).toDouble(),
      catapultX: (json['catapultX'] as num? ?? 0).toDouble(),
      shots: json['shots'] as int,
      par: json['par'] as int,
      objective: Objective.values.byName(
        json['objective'] as String? ?? 'killAll',
      ),
      blocks: [
        for (final b in json['blocks'] as List)
          BlockData.fromJson(b as Map<String, dynamic>),
      ],
      units: [
        for (final u in json['units'] as List)
          UnitData.fromJson(u as Map<String, dynamic>),
      ],
    );
    if (level.objective == Objective.killKing &&
        !level.units.any((u) => u.kind == UnitKind.king)) {
      throw FormatException('Level ${level.id} needs a king to kill');
    }
    return level;
  }

  factory LevelData.parse(String source) =>
      LevelData.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String id;
  final String name;
  final double worldWidth;
  final double catapultX;
  final int shots;
  final int par;
  final Objective objective;
  final List<BlockData> blocks;
  final List<UnitData> units;
}
