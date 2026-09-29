/// Physical and gameplay properties of castle building materials.
///
/// Every tuning value lives here so balancing never touches component code.
enum BlockMaterial { wood, stone, glass, marble, tile, bamboo, crystal }

class MaterialSpec {
  const MaterialSpec({
    required this.density,
    required this.friction,
    required this.restitution,
    required this.maxHp,
    required this.flammable,
  });

  final double density;
  final double friction;
  final double restitution;
  final double maxHp;
  final bool flammable;
}

const Map<BlockMaterial, MaterialSpec> materialSpecs = {
  BlockMaterial.wood: MaterialSpec(
    density: 0.7,
    friction: 0.7,
    restitution: 0.05,
    maxHp: 30,
    flammable: true,
  ),
  BlockMaterial.stone: MaterialSpec(
    density: 2.4,
    friction: 0.9,
    restitution: 0.02,
    maxHp: 110,
    flammable: false,
  ),
  // Roman marble: the toughest and heaviest masonry, and slick.
  BlockMaterial.marble: MaterialSpec(
    density: 2.8,
    friction: 0.6,
    restitution: 0.02,
    maxHp: 160,
    flammable: false,
  ),
  // Persian glazed tile: bright and light, and it shatters easily.
  BlockMaterial.tile: MaterialSpec(
    density: 1.4,
    friction: 0.5,
    restitution: 0.05,
    maxHp: 45,
    flammable: false,
  ),
  // Bamboo: very light, springy, and it burns fast.
  BlockMaterial.bamboo: MaterialSpec(
    density: 0.45,
    friction: 0.6,
    restitution: 0.25,
    maxHp: 22,
    flammable: true,
  ),
  // Mythic crystal: heavy and hard, but it shatters in one good blow.
  BlockMaterial.crystal: MaterialSpec(
    density: 2.0,
    friction: 0.35,
    restitution: 0.1,
    maxHp: 70,
    flammable: false,
  ),
  BlockMaterial.glass: MaterialSpec(
    density: 1.0,
    friction: 0.3,
    restitution: 0.1,
    maxHp: 10,
    flammable: false,
  ),
};

extension BlockMaterialSpec on BlockMaterial {
  MaterialSpec get spec => materialSpecs[this]!;

  static BlockMaterial parse(String name) => BlockMaterial.values.firstWhere(
    (m) => m.name == name,
    orElse: () => throw FormatException('Unknown material "$name"'),
  );
}
