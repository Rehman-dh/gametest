import 'ammo.dart';

enum WeaponType { catapult, trebuchet, ballista }

class WeaponSpec {
  const WeaponSpec({
    required this.label,
    required this.speedPerMeter,
    required this.ammo,
    this.gravityScale = 1,
  });

  final String label;

  /// Launch speed (m/s) per meter of pull.
  final double speedPerMeter;

  /// Ammo this weapon can fire.
  final Set<AmmoType> ammo;

  /// Gravity multiplier for its projectiles (flat-shooting ballista bolts).
  final double gravityScale;
}

const _thrown = {
  AmmoType.stone,
  AmmoType.fireball,
  AmmoType.cluster,
  AmmoType.powderKeg,
};

const Map<WeaponType, WeaponSpec> weaponSpecs = {
  WeaponType.catapult: WeaponSpec(
    label: 'Catapult',
    speedPerMeter: 4.3,
    ammo: _thrown,
  ),
  WeaponType.trebuchet: WeaponSpec(
    label: 'Trebuchet',
    speedPerMeter: 5.2,
    ammo: _thrown,
  ),
  WeaponType.ballista: WeaponSpec(
    label: 'Ballista',
    speedPerMeter: 6.0,
    ammo: {AmmoType.bolt},
    gravityScale: 0.35,
  ),
};

extension WeaponTypeSpec on WeaponType {
  WeaponSpec get spec => weaponSpecs[this]!;
}
