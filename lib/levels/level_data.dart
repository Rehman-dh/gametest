import 'dart:convert';

import '../core/ammo.dart';
import '../core/materials.dart';
import '../core/weapons.dart';

/// Level files use a y-up coordinate system measured from the ground
/// (y = distance of an object's *bottom* above the ground), which is
/// intuitive to author. Components convert to Forge2D's y-down space.

enum Objective { killAll, killKing }

enum UnitKind { soldier, king }

enum PropKind { powderBarrel }

class BlockData {
  const BlockData({
    required this.material,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.angle = 0,
    this.weak = false,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) => BlockData(
    material: BlockMaterialSpec.parse(json['m'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['w'] as num).toDouble(),
    height: (json['h'] as num).toDouble(),
    angle: (json['a'] as num? ?? 0).toDouble(),
    weak: json['weak'] as bool? ?? false,
  );

  final BlockMaterial material;
  final double x, y, width, height, angle;

  /// A hidden structural flaw (rotten beam, cracked keystone): much weaker,
  /// and breaking it earns the level's hidden-objective star.
  final bool weak;
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

class PropData {
  const PropData({required this.kind, required this.x, required this.y});

  factory PropData.fromJson(Map<String, dynamic> json) => PropData(
    kind: PropKind.values.byName(json['kind'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  final PropKind kind;
  final double x, y;
}

class LevelData {
  const LevelData({
    required this.id,
    required this.name,
    required this.worldWidth,
    required this.catapultX,
    required this.ammo,
    required this.par,
    required this.objective,
    required this.blocks,
    required this.units,
    this.props = const [],
    this.weapon = WeaponType.catapult,
    this.wind = 0,
  });

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final level = LevelData(
      id: json['id'] as String,
      name: json['name'] as String,
      worldWidth: (json['worldWidth'] as num? ?? 60).toDouble(),
      catapultX: (json['catapultX'] as num? ?? 0).toDouble(),
      ammo: _parseAmmo(json),
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
      props: [
        for (final p in json['props'] as List? ?? const [])
          PropData.fromJson(p as Map<String, dynamic>),
      ],
      weapon: WeaponType.values.byName(json['weapon'] as String? ?? 'catapult'),
      wind: (json['wind'] as num? ?? 0).toDouble(),
    );
    if (level.objective == Objective.killKing &&
        !level.units.any((u) => u.kind == UnitKind.king)) {
      throw FormatException('Level ${level.id} needs a king to kill');
    }
    final unusable = level.ammo.where(
      (a) => !level.weapon.spec.ammo.contains(a),
    );
    if (unusable.isNotEmpty) {
      throw FormatException(
        'Level ${level.id}: ${level.weapon.name} cannot fire ${unusable.first.name}',
      );
    }
    return level;
  }

  /// `ammo` lists each round in order; the older `shots` form means that
  /// many stones (or bolts, for a ballista).
  static List<AmmoType> _parseAmmo(Map<String, dynamic> json) {
    final list = json['ammo'] as List?;
    if (list != null) {
      return [for (final a in list) AmmoType.values.byName(a as String)];
    }
    final weapon = json['weapon'] as String? ?? 'catapult';
    final round = weapon == 'ballista' ? AmmoType.bolt : AmmoType.stone;
    return List.filled(json['shots'] as int, round);
  }

  factory LevelData.parse(String source) =>
      LevelData.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String id;
  final String name;
  final double worldWidth;
  final double catapultX;
  final List<AmmoType> ammo;
  int get shots => ammo.length;
  final int par;
  final Objective objective;
  final List<BlockData> blocks;
  final List<UnitData> units;
  final List<PropData> props;
  final WeaponType weapon;

  /// Horizontal acceleration on projectiles (m/s²); positive blows toward
  /// the castle.
  final double wind;

  bool get hasWeakPoints =>
      blocks.any((b) => b.weak) ||
      props.any((p) => p.kind == PropKind.powderBarrel);
}
