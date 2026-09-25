import 'dart:convert';

import '../core/ammo.dart';
import '../core/materials.dart';
import '../core/weapons.dart';
import '../meta/catalog.dart';

/// Level files use a y-up coordinate system measured from the ground
/// (y = distance of an object's *bottom* above the ground), which is
/// intuitive to author. Components convert to Forge2D's y-down space.

enum Objective {
  killAll,
  killKing,

  /// Defense missions: wreck every enemy siege engine before they wreck
  /// yours.
  destroyEngines,
}

enum UnitKind {
  soldier,
  king,

  /// Shoots arrows at the player's siege engine on the enemy's turn.
  archer,

  /// Repairs damaged castle blocks nearby while alive.
  engineer,

  /// An era's boss king: tougher, and counts as the king to slay.
  pharaoh;

  bool get isRoyal => this == king || this == pharaoh;
}

enum PropKind { powderBarrel, enemyCatapult }

class BlockData {
  const BlockData({
    required this.material,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.angle = 0,
    this.weak = false,
    this.look,
    this.toughness = 1,
  });

  factory BlockData.fromJson(Map<String, dynamic> json) => BlockData(
    material: BlockMaterialSpec.parse(json['m'] as String),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['w'] as num).toDouble(),
    height: (json['h'] as num).toDouble(),
    angle: (json['a'] as num? ?? 0).toDouble(),
    weak: json['weak'] as bool? ?? false,
    look: json['look'] as String?,
    toughness: (json['hp'] as num? ?? 1).toDouble(),
  );

  final BlockMaterial material;
  final double x, y, width, height, angle;

  /// A hidden structural flaw (rotten beam, cracked keystone): much weaker,
  /// and breaking it earns the level's hidden-objective star.
  final bool weak;

  /// A fortress piece the 3D renderer draws with a real model: `tower`,
  /// `wall` or `gate`. Null draws a plain block.
  final String? look;

  /// Multiplies the material's hit points, for massive masonry.
  final double toughness;

  BlockData shifted(double dx) => copyWith(x: x + dx);

  BlockData copyWith({double? x, bool? weak}) => BlockData(
    material: material,
    x: x ?? this.x,
    y: y,
    width: width,
    height: height,
    angle: angle,
    weak: weak ?? this.weak,
    look: look,
    toughness: toughness,
  );
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

  UnitData shifted(double dx) => UnitData(kind: kind, x: x + dx, y: y);
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

  PropData shifted(double dx) => PropData(kind: kind, x: x + dx, y: y);
}

/// A line spoken during a siege, shown briefly over the HUD.
class LevelLine {
  const LevelLine({
    required this.trigger,
    required this.speaker,
    required this.text,
  });

  factory LevelLine.fromJson(Map<String, dynamic> json) => LevelLine(
    trigger: json['trigger'] as String,
    speaker: json['speaker'] as String,
    text: json['text'] as String,
  );

  /// `start`, `shot:N` (after the Nth shot lands), `volley:N` (the enemy's
  /// Nth volley) or `phase:N` (the Nth phase of a multi-phase siege begins).
  final String trigger;

  /// A story [CharacterId] name.
  final String speaker;
  final String text;
}

/// A later stage of a multi-phase siege: more castle rises once the
/// previous stage's objective is met.
class PhaseData {
  const PhaseData({
    required this.title,
    required this.objective,
    required this.blocks,
    required this.units,
    required this.props,
    required this.ammo,
  });

  factory PhaseData.fromJson(Map<String, dynamic> json) => PhaseData(
    title: json['title'] as String,
    objective: Objective.values.byName(json['objective'] as String),
    blocks: [
      for (final b in json['blocks'] as List? ?? const [])
        BlockData.fromJson(b as Map<String, dynamic>),
    ],
    units: [
      for (final u in json['units'] as List? ?? const [])
        UnitData.fromJson(u as Map<String, dynamic>),
    ],
    props: [
      for (final p in json['props'] as List? ?? const [])
        PropData.fromJson(p as Map<String, dynamic>),
    ],
    ammo: [
      for (final a in json['ammo'] as List? ?? const [])
        AmmoType.values.byName(a as String),
    ],
  );

  /// Announced when the phase begins.
  final String title;
  final Objective objective;
  final List<BlockData> blocks;
  final List<UnitData> units;
  final List<PropData> props;

  /// Reinforcements added to the player's ammunition.
  final List<AmmoType> ammo;
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
    this.defenses = const [],
    this.playerHp = 100,
    this.enemyFireEvery = 1,
    this.weaponLocked = false,
    this.budget,
    this.relic,
    this.unlocksCrew,
    this.introCutscene,
    this.outroCutscene,
    this.lines = const [],
    this.phases = const [],
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
      defenses: [
        for (final b in json['defenses'] as List? ?? const [])
          BlockData.fromJson(b as Map<String, dynamic>),
      ],
      playerHp: (json['playerHp'] as num? ?? 100).toDouble(),
      enemyFireEvery: json['enemyFireEvery'] as int? ?? 1,
      weaponLocked: json.containsKey('weapon'),
      budget: json['budget'] as int?,
      relic: switch (json['relic']) {
        final String name => RelicId.values.byName(name),
        _ => null,
      },
      unlocksCrew: switch (json['unlocksCrew']) {
        final String name => CrewId.values.byName(name),
        _ => null,
      },
      introCutscene: json['introCutscene'] as String?,
      outroCutscene: json['outroCutscene'] as String?,
      lines: [
        for (final l in json['lines'] as List? ?? const [])
          LevelLine.fromJson(l as Map<String, dynamic>),
      ],
      phases: [
        for (final p in json['phases'] as List? ?? const [])
          PhaseData.fromJson(p as Map<String, dynamic>),
      ],
    );
    for (final (objective, units, props) in [
      (level.objective, level.units, level.props),
      for (final p in level.phases) (p.objective, p.units, p.props),
    ]) {
      if (objective == Objective.killKing &&
          !units.any((u) => u.kind.isRoyal)) {
        throw FormatException('Level ${level.id} needs a king to kill');
      }
      if (objective == Objective.destroyEngines &&
          !props.any((p) => p.kind == PropKind.enemyCatapult)) {
        throw FormatException(
          'Level ${level.id} has no enemy engines to destroy',
        );
      }
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

  /// The player's own barricade, in front of the siege engine.
  final List<BlockData> defenses;

  /// Hit points of the player's siege engine.
  final double playerHp;

  /// The enemy returns fire after every this many player shots.
  final int enemyFireEvery;

  /// Levels that name their weapon (ballista galleries, trebuchet ranges)
  /// don't let the player swap it in Siege Prep.
  final bool weaponLocked;

  /// Siege Prep budget; defaults to the cost of [ammo].
  final int? budget;

  /// Awarded on the first win.
  final RelicId? relic;
  final CrewId? unlocksCrew;

  /// Story scenes played before the first attempt and after the first win.
  final String? introCutscene;
  final String? outroCutscene;
  final List<LevelLine> lines;

  /// Further stages after the first, for boss sieges.
  final List<PhaseData> phases;

  /// Whether anything in this level shoots back.
  bool get hasCounterFire =>
      [(units, props), for (final p in phases) (p.units, p.props)].any(
        (s) =>
            s.$1.any((u) => u.kind == UnitKind.archer) ||
            s.$2.any((p) => p.kind == PropKind.enemyCatapult),
      );

  bool get hasWeakPoints =>
      blocks.any((b) => b.weak) ||
      props.any((p) => p.kind == PropKind.powderBarrel) ||
      phases.any(
        (p) =>
            p.blocks.any((b) => b.weak) ||
            p.props.any((q) => q.kind == PropKind.powderBarrel),
      );
}
