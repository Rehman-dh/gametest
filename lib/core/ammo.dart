/// Projectile types the player can load. All tuning lives in [ammoSpecs].
enum AmmoType { stone, fireball, cluster, powderKeg, bolt }

class AmmoSpec {
  const AmmoSpec({
    required this.label,
    required this.radius,
    required this.density,
    this.ignites = false,
    this.splitsOnTap = false,
    this.explodes = false,
  });

  final String label;

  /// Collision radius in meters (bolts use it as half their length / 4).
  final double radius;
  final double density;

  /// Sets flammable blocks it touches on fire.
  final bool ignites;

  /// Tap mid-flight to burst into [clusterPieces] smaller stones.
  final bool splitsOnTap;

  /// Detonates on a hard impact, or on tap mid-flight.
  final bool explodes;
}

const clusterPieces = 4;
const clusterPieceRadius = 0.3;

const Map<AmmoType, AmmoSpec> ammoSpecs = {
  AmmoType.stone: AmmoSpec(label: 'Stone', radius: 0.55, density: 4),
  AmmoType.fireball: AmmoSpec(
    label: 'Fireball',
    radius: 0.5,
    density: 3,
    ignites: true,
  ),
  AmmoType.cluster: AmmoSpec(
    label: 'Cluster',
    radius: 0.6,
    density: 3,
    splitsOnTap: true,
  ),
  AmmoType.powderKeg: AmmoSpec(
    label: 'Powder keg',
    radius: 0.5,
    density: 2,
    explodes: true,
  ),
  AmmoType.bolt: AmmoSpec(label: 'Bolt', radius: 0.18, density: 12),
};

extension AmmoTypeSpec on AmmoType {
  AmmoSpec get spec => ammoSpecs[this]!;
}

/// Explosion falloff: full effect at the center, none at [radius].
double explosionFalloff(double distance, double radius) {
  if (radius <= 0 || distance >= radius) return 0;
  final t = 1 - distance / radius;
  return t * t;
}
