import 'dart:math' as math;

import '../core/ammo.dart';
import '../core/materials.dart';
import '../levels/level_data.dart';

/// Builds a castle for endless mode from a [seed] and a [depth] (1 = the
/// first castle of a run). The same seed and depth always give the same
/// castle.
///
/// Castles are assembled left to right from modules (huts, towers, walls,
/// keeps) that follow the stacking rules the hand-made levels proved
/// stable: posts stand on the ground or on a slab, slabs overhang their
/// posts slightly, and every defender has clear room between posts.
class CastleGenerator {
  const CastleGenerator(this.seed);

  final int seed;

  static const _startX = 27.0;
  static const _maxEndX = 52.0;

  static bool isBossDepth(int depth) => depth % 5 == 0;

  LevelData generate(int depth) {
    final rng = math.Random(seed * 7919 + depth * 104729);
    final boss = isBossDepth(depth);
    final stoneChance = math.min(0.85, 0.15 + 0.07 * depth);
    final maxFloors = math.min(3, 1 + depth ~/ 4);
    final archers = depth >= 3 ? math.min(3, 1 + (depth - 3) ~/ 3) : 0;
    final engineers = depth >= 6 ? 1 + (depth >= 12 ? 1 : 0) : 0;

    final plan = <_Module Function()>[];
    if (boss) {
      if (rng.nextBool()) plan.add(() => _wall(rng));
      plan.add(() => _keep(rng, withBarrel: rng.nextDouble() < 0.6));
      if (depth >= 10) plan.add(_engine);
      plan.add(() => _hut(rng, stoneChance));
    } else {
      final count = math.min(5, 2 + depth ~/ 3);
      for (var i = 0; i < count; i++) {
        final roll = rng.nextDouble();
        plan.add(
          roll < 0.4
              ? () => _hut(rng, stoneChance)
              : roll < 0.8
              ? () => _tower(rng, stoneChance, 1 + rng.nextInt(maxFloors))
              : () => _wall(rng),
        );
      }
    }

    final blocks = <BlockData>[];
    final units = <UnitData>[];
    final props = <PropData>[];
    var x = _startX;
    for (final build in plan) {
      final module = build();
      if (x + module.width > _maxEndX && units.isNotEmpty) break;
      blocks.addAll(module.blocks.map((b) => b.shifted(x)));
      units.addAll(module.units.map((u) => u.shifted(x)));
      props.addAll(module.props.map((p) => p.shifted(x)));
      x += module.width + 1.4 + rng.nextDouble() * 1.4;
    }
    if (units.isEmpty) {
      // Every module was a wall: add a hut so there is someone to defeat.
      final hut = _hut(rng, stoneChance);
      blocks.addAll(hut.blocks.map((b) => b.shifted(x)));
      units.addAll(hut.units.map((u) => u.shifted(x)));
      x += hut.width;
    }

    _assignRoles(rng, units, archers: archers, engineers: engineers);
    if (!boss && depth >= 2 && rng.nextDouble() < 0.5) {
      _weakenOnePost(rng, blocks);
    }

    final wind = depth >= 4
        ? ((rng.nextDouble() * 2 - 1) * math.min(2.0, 0.5 + 0.1 * depth))
        : 0.0;
    final counterFire =
        units.any((u) => u.kind == UnitKind.archer) ||
        props.any((p) => p.kind == PropKind.enemyCatapult);
    final defenders = units.length;

    return LevelData(
      id: 'endless_${seed}_$depth',
      name: boss ? 'Citadel $depth' : 'Castle $depth',
      worldWidth: math.max(48, x + 2),
      catapultX: 0,
      ammo: List.filled(defenders + 2, AmmoType.stone),
      par: defenders,
      objective: boss ? Objective.killKing : Objective.killAll,
      blocks: blocks,
      units: units,
      props: props,
      wind: double.parse(wind.toStringAsFixed(1)),
      defenses: counterFire
          ? const [
              BlockData(
                material: BlockMaterial.wood,
                x: 5,
                y: 0,
                width: 0.9,
                height: 2.4,
              ),
              BlockData(
                material: BlockMaterial.wood,
                x: 6.1,
                y: 0,
                width: 0.9,
                height: 2.0,
              ),
            ]
          : const [],
    );
  }

  // ------------------------------------------------------------- modules

  static BlockMaterial _pick(math.Random rng, double stoneChance) =>
      rng.nextDouble() < stoneChance ? BlockMaterial.stone : BlockMaterial.wood;

  static double _postWidth(BlockMaterial m) =>
      m == BlockMaterial.stone ? 0.8 : 0.5;
  static double _slabHeight(BlockMaterial m) =>
      m == BlockMaterial.stone ? 0.5 : 0.4;

  /// One storey: two posts and a slab across them, standing at height [y]
  /// with post centres [left] and [right]. Returns the slab's top.
  static double _storey(
    List<BlockData> blocks, {
    required BlockMaterial material,
    required double left,
    required double right,
    required double y,
    required double height,
  }) {
    final post = _postWidth(material);
    final slab = _slabHeight(material);
    blocks
      ..add(
        BlockData(
          material: material,
          x: left,
          y: y,
          width: post,
          height: height,
        ),
      )
      ..add(
        BlockData(
          material: material,
          x: right,
          y: y,
          width: post,
          height: height,
        ),
      )
      ..add(
        BlockData(
          material: material,
          x: (left + right) / 2,
          y: y + height,
          width: right - left + post + 0.3,
          height: slab,
        ),
      );
    return y + height + slab;
  }

  _Module _hut(math.Random rng, double stoneChance) {
    final material = _pick(rng, stoneChance);
    final post = _postWidth(material);
    final span = 1.6 + rng.nextDouble() * 1.4;
    final left = post / 2 + 0.15;
    final right = left + post + span;
    final blocks = <BlockData>[];
    final top = _storey(
      blocks,
      material: material,
      left: left,
      right: right,
      y: 0,
      height: 2.2 + rng.nextDouble(),
    );
    final mid = (left + right) / 2;
    final units = [UnitData(kind: UnitKind.soldier, x: mid, y: 0)];
    final slabLeft = mid - (right - left + post + 0.3) / 2;
    if (rng.nextDouble() < 0.3) {
      blocks.add(
        BlockData(
          material: BlockMaterial.glass,
          x: slabLeft + 0.6,
          y: top,
          width: 1,
          height: 1,
        ),
      );
    }
    if (rng.nextDouble() < 0.4) {
      units.add(UnitData(kind: UnitKind.soldier, x: mid + 0.8, y: top));
    }
    return _Module(
      blocks: blocks,
      units: units,
      width: right + post / 2 + 0.15,
    );
  }

  _Module _tower(math.Random rng, double stoneChance, int floors) {
    final blocks = <BlockData>[];
    final units = <UnitData>[];
    // Lower floors are sturdier.
    var material = _pick(rng, stoneChance + 0.15);
    var post = _postWidth(material);
    var left = post / 2 + 0.15;
    var right = left + post + 2.4 + rng.nextDouble() * 1.2;
    final width = right + post / 2 + 0.15;
    var y = 0.0;
    for (var floor = 0; floor < floors; floor++) {
      final mid = (left + right) / 2;
      units.add(UnitData(kind: UnitKind.soldier, x: mid, y: y));
      y = _storey(
        blocks,
        material: material,
        left: left,
        right: right,
        y: y,
        height: 2.4 + rng.nextDouble() * 0.6,
      );
      // Next storey: lighter and set in from the one below.
      material = floor == 0
          ? _pick(rng, stoneChance - 0.1)
          : BlockMaterial.wood;
      post = _postWidth(material);
      final nextLeft = left + 0.3, nextRight = right - 0.3;
      if (nextRight - nextLeft - post < 1.3) break;
      left = nextLeft;
      right = nextRight;
    }
    // Someone keeps watch on the roof.
    units.add(UnitData(kind: UnitKind.soldier, x: (left + right) / 2, y: y));
    return _Module(blocks: blocks, units: units, width: width);
  }

  _Module _wall(math.Random rng) {
    final w = 0.8 + rng.nextDouble() * 0.4;
    return _Module(
      blocks: [
        BlockData(
          material: BlockMaterial.stone,
          x: w / 2,
          y: 0,
          width: w,
          height: 1.8 + rng.nextDouble() * 1.7,
        ),
      ],
      units: const [],
      width: w,
    );
  }

  _Module _keep(math.Random rng, {required bool withBarrel}) {
    final blocks = <BlockData>[];
    const pillar = 1.0;
    final span = withBarrel ? 3.8 : 3.0 + rng.nextDouble();
    const left = pillar / 2 + 0.15;
    final right = left + pillar + span;
    final mid = (left + right) / 2;
    blocks
      ..add(
        BlockData(
          material: BlockMaterial.stone,
          x: left,
          y: 0,
          width: pillar,
          height: 4,
        ),
      )
      ..add(
        BlockData(
          material: BlockMaterial.stone,
          x: right,
          y: 0,
          width: pillar,
          height: 4,
        ),
      )
      ..add(
        BlockData(
          material: BlockMaterial.stone,
          x: mid,
          y: 4,
          width: right - left + pillar + 0.3,
          height: 0.6,
        ),
      );
    final top = _storey(
      blocks,
      material: BlockMaterial.wood,
      left: left + 0.4,
      right: right - 0.4,
      y: 4.6,
      height: 2.5,
    );
    final props = <PropData>[];
    final units = <UnitData>[
      UnitData(kind: UnitKind.soldier, x: mid, y: 4.6),
      UnitData(kind: UnitKind.soldier, x: mid, y: top),
    ];
    if (withBarrel) {
      props.add(
        PropData(kind: PropKind.powderBarrel, x: left + pillar / 2 + 0.6, y: 0),
      );
      units.add(UnitData(kind: UnitKind.king, x: mid + 0.7, y: 0));
    } else {
      units.add(UnitData(kind: UnitKind.king, x: mid, y: 0));
    }
    return _Module(
      blocks: blocks,
      units: units,
      props: props,
      width: right + pillar / 2 + 0.15,
    );
  }

  _Module _engine() => const _Module(
    blocks: [],
    units: [],
    props: [PropData(kind: PropKind.enemyCatapult, x: 1.4, y: 0)],
    width: 2.8,
  );

  /// Soldiers become engineers (on the ground) and archers (high up first).
  /// Engineers are picked first so a castle full of archers still has
  /// someone to patch it.
  void _assignRoles(
    math.Random rng,
    List<UnitData> units, {
    required int archers,
    required int engineers,
  }) {
    final grounded = [
      for (var i = 0; i < units.length; i++)
        if (units[i].kind == UnitKind.soldier && units[i].y == 0) i,
    ]..shuffle(rng);
    for (final i in grounded.take(engineers)) {
      units[i] = UnitData(
        kind: UnitKind.engineer,
        x: units[i].x,
        y: units[i].y,
      );
    }
    final soldiers = [
      for (var i = 0; i < units.length; i++)
        if (units[i].kind == UnitKind.soldier) i,
    ]..sort((a, b) => units[b].y.compareTo(units[a].y));
    for (final i in soldiers.take(archers)) {
      units[i] = UnitData(kind: UnitKind.archer, x: units[i].x, y: units[i].y);
    }
  }

  /// Marks one ground-floor post as rotten: a weak point.
  void _weakenOnePost(math.Random rng, List<BlockData> blocks) {
    final posts = [
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i].y == 0 && blocks[i].height > blocks[i].width * 2) i,
    ];
    if (posts.isEmpty) return;
    final i = posts[rng.nextInt(posts.length)];
    blocks[i] = blocks[i].copyWith(weak: true);
  }
}

class _Module {
  const _Module({
    required this.blocks,
    required this.units,
    this.props = const [],
    required this.width,
  });

  final List<BlockData> blocks;
  final List<UnitData> units;
  final List<PropData> props;
  final double width;
}
