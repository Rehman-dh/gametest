import '../core/ammo.dart';
import '../core/weapons.dart';
import '../levels/level_data.dart';
import 'catalog.dart';
import 'progress.dart';

/// What the player takes into a siege, chosen on the Siege Prep screen.
class Loadout {
  const Loadout({
    required this.weapon,
    required this.ammo,
    this.crew = const [],
  });

  /// The level's own suggestion, used when skipping prep (and in tests).
  factory Loadout.levelDefault(LevelData level) =>
      Loadout(weapon: level.weapon, ammo: level.ammo);

  final WeaponType weapon;

  /// Rounds in firing order.
  final List<AmmoType> ammo;
  final List<CrewId> crew;

  bool has(CrewId id) => crew.contains(id);
}

/// Prices, budgets and availability for the Siege Prep shop.
class Armory {
  const Armory(this.progress);

  final Progress progress;

  int get _alchemy => progress.building(BuildingId.alchemy);

  int priceOf(AmmoType type) =>
      (ammoPrices[type]! * (1 - 0.1 * _alchemy)).round();

  int costOf(Iterable<AmmoType> rounds) =>
      rounds.fold(0, (sum, a) => sum + priceOf(a));

  /// Budget for [level]: its own figure, or enough for its suggested
  /// loadout at base prices; the War Room adds 15% per level.
  int budgetFor(LevelData level) {
    final base =
        level.budget ??
        level.ammo.fold<int>(0, (sum, a) => sum + ammoPrices[a]!);
    return (base * (1 + 0.15 * progress.building(BuildingId.warRoom))).round();
  }

  /// Levels that name a weapon lock it; otherwise any unlocked one.
  List<WeaponType> weaponsFor(LevelData level) {
    if (level.weaponLocked) return [level.weapon];
    final workshop = progress.building(BuildingId.workshop);
    return [
      WeaponType.catapult,
      if (workshop >= 1) WeaponType.trebuchet,
      if (workshop >= 2) WeaponType.ballista,
    ];
  }

  /// Ammo on sale: whatever the level supplies plus Alchemy unlocks,
  /// limited to what [weapon] can fire.
  List<AmmoType> ammoFor(LevelData level, WeaponType weapon) {
    final unlocked = {
      ...level.ammo,
      AmmoType.stone,
      if (_alchemy >= 1) ...[AmmoType.fireball, AmmoType.cluster],
      if (_alchemy >= 2) AmmoType.powderKeg,
    };
    if (weapon == WeaponType.ballista) return [AmmoType.bolt];
    return [
      for (final a in AmmoType.values)
        if (unlocked.contains(a) && weapon.spec.ammo.contains(a)) a,
    ];
  }

  int crewSlots() => progress.building(BuildingId.barracks) >= 1 ? 2 : 1;

  List<CrewId> availableCrew() => [
    for (final id in CrewId.values)
      if (progress.hasCrew(id)) id,
  ];
}

/// Numeric effects of camp buildings, relics and the chosen crew on a
/// siege. Gameplay code reads these and never looks at progress.
class Modifiers {
  const Modifiers({
    this.engineHpBonus = 0,
    this.barricadeHpMultiplier = 1,
    this.fireMultiplier = 1,
    this.blastMultiplier = 1,
    this.trajectoryMultiplier = 1,
    this.repairAmount = 0,
  });

  factory Modifiers.from(Progress progress, Loadout loadout) {
    final alchemy = progress.building(BuildingId.alchemy);
    final workshop = progress.building(BuildingId.workshop);
    var engineHp = workshop >= 3 ? 20.0 : 0.0;
    if (progress.relics.contains(RelicId.scarabAmulet)) engineHp += 15;
    var barricade = 1.0, fire = 1 + 0.1 * alchemy, blast = 1.0;
    var trajectory = 1.0, repair = 0.0;
    if (alchemy >= 3) blast += 0.3;

    if (loadout.has(CrewId.bashir)) {
      final lv = progress.crewLevel(CrewId.bashir);
      barricade += 0.2 + 0.05 * (lv - 1);
      engineHp += 10;
      repair = 25.0 + 5 * (lv - 1);
    }
    if (loadout.has(CrewId.liWei)) {
      trajectory += 0.5 + 0.1 * (progress.crewLevel(CrewId.liWei) - 1);
    }
    if (loadout.has(CrewId.roxana)) {
      final bonus = 0.2 + 0.05 * (progress.crewLevel(CrewId.roxana) - 1);
      fire += bonus;
      blast += bonus;
    }
    return Modifiers(
      engineHpBonus: engineHp,
      barricadeHpMultiplier: barricade,
      fireMultiplier: fire,
      blastMultiplier: blast,
      trajectoryMultiplier: trajectory,
      repairAmount: repair,
    );
  }

  static const none = Modifiers();

  final double engineHpBonus;
  final double barricadeHpMultiplier;
  final double fireMultiplier;
  final double blastMultiplier;
  final double trajectoryMultiplier;

  /// Engine hit points restored by Bashir's Field Repair.
  final double repairAmount;
}
