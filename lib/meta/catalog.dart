import '../core/ammo.dart';

/// Static definitions of everything the meta layer can unlock or buy.
/// All costs and bonuses live here so balancing touches no logic.

enum CrewId { bashir, liWei, roxana }

class CrewSpec {
  const CrewSpec({
    required this.name,
    required this.role,
    required this.passive,
    required this.abilityName,
    required this.ability,
    required this.joins,
  });

  final String name;
  final String role;
  final String passive;
  final String abilityName;
  final String ability;

  /// Shown while locked.
  final String joins;
}

const Map<CrewId, CrewSpec> crewSpecs = {
  CrewId.bashir: CrewSpec(
    name: 'Bashir',
    role: 'Engineer',
    passive: 'Barricades are sturdier; the engine gains hit points.',
    abilityName: 'Field Repair',
    ability: 'Once per siege, restores the engine\'s hit points.',
    joins: 'Joins after The Pharaoh\'s Gate',
  ),
  CrewId.liWei: CrewSpec(
    name: 'Li Wei',
    role: 'Scout',
    passive: 'Longer trajectory preview.',
    abilityName: 'Spotter',
    ability: 'Once per siege, reveals every weak point.',
    joins: 'Joins in China',
  ),
  CrewId.roxana: CrewSpec(
    name: 'Roxana',
    role: 'Alchemist',
    passive: 'Fire and blasts are stronger.',
    abilityName: 'Greek Fire',
    ability: 'Once per siege, the next shot sets wood ablaze.',
    joins: 'Joins in Persia',
  ),
};

/// Crew levels come from experience earned on won sieges.
const int crewMaxLevel = 5;
const int crewXpPerLevel = 6;

int crewLevelFor(int xp) => (1 + xp ~/ crewXpPerLevel).clamp(1, crewMaxLevel);

enum BuildingId { workshop, alchemy, barracks, warRoom, trophyHall }

class BuildingSpec {
  const BuildingSpec({
    required this.name,
    required this.costs,
    required this.levels,
  });

  final String name;

  /// Gold to reach level 1, 2, 3.
  final List<int> costs;

  /// What each level adds, for the camp screen.
  final List<String> levels;

  int get maxLevel => costs.length;
}

const Map<BuildingId, BuildingSpec> buildingSpecs = {
  BuildingId.workshop: BuildingSpec(
    name: 'Workshop',
    costs: [150, 300, 500],
    levels: [
      'Unlocks the Trebuchet',
      'Unlocks the Ballista',
      'Reinforced frames: +20 engine hit points',
    ],
  ),
  BuildingId.alchemy: BuildingSpec(
    name: 'Alchemy Tent',
    costs: [120, 250, 450],
    levels: [
      'Fireballs and clusters in every siege; ammo 10% cheaper; +10% fire',
      'Powder kegs in every siege; ammo 20% cheaper; +20% fire',
      'Ammo 30% cheaper; +30% fire and blasts',
    ],
  ),
  BuildingId.barracks: BuildingSpec(
    name: 'Barracks',
    costs: [100, 250, 400],
    levels: [
      'A second crew slot',
      'Crew gain experience 50% faster',
      'Crew gain experience twice as fast',
    ],
  ),
  BuildingId.warRoom: BuildingSpec(
    name: 'War Room',
    costs: [120, 260, 420],
    levels: [
      '+15% siege budget',
      '+30% siege budget; scout reports show weak points',
      '+45% siege budget',
    ],
  ),
  BuildingId.trophyHall: BuildingSpec(
    name: 'Trophy Hall',
    costs: [150, 300, 500],
    levels: ['+10% gold from sieges', '+20% gold', '+30% gold'],
  ),
};

enum RelicId { scarabAmulet, eyeOfHorus }

class RelicSpec {
  const RelicSpec({required this.name, required this.effect});

  final String name;
  final String effect;
}

const Map<RelicId, RelicSpec> relicSpecs = {
  RelicId.scarabAmulet: RelicSpec(
    name: 'Scarab Amulet',
    effect: '+15 engine hit points',
  ),
  RelicId.eyeOfHorus: RelicSpec(
    name: 'Eye of Horus',
    effect: '+20% gold from sieges',
  ),
};

/// Base price of one round in the Siege Prep shop.
const Map<AmmoType, int> ammoPrices = {
  AmmoType.stone: 30,
  AmmoType.fireball: 60,
  AmmoType.cluster: 70,
  AmmoType.powderKeg: 90,
  AmmoType.bolt: 40,
};
