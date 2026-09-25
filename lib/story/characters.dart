import 'dart:ui';

/// Story characters and scenery. Pure data: art themes decide how a
/// [CharacterLook] is drawn.

enum Headgear { none, hood, helmet, nemes, cap, crown }

enum Carried { none, sword, staff, spear, hammer }

enum Pose { stand, walk, kneel, fallen, point, talk }

class CharacterLook {
  const CharacterLook({
    required this.name,
    required this.cloth,
    required this.clothDark,
    this.cloak,
    this.skin = const Color(0xFFC89A74),
    this.hair = const Color(0xFF2A1E16),
    this.headgear = Headgear.none,
    this.beard,
    this.carried = Carried.none,
    this.height = 1.8,
  });

  final String name;
  final Color cloth;
  final Color clothDark;
  final Color? cloak;
  final Color skin;
  final Color hair;
  final Headgear headgear;
  final Color? beard;
  final Carried carried;

  /// Standing height in meters.
  final double height;
}

enum CharacterId {
  arslan,
  idris,
  bashir,
  sethmose,
  ironHand,
  soldier,
  messenger,
}

const Map<CharacterId, CharacterLook> characterLooks = {
  CharacterId.arslan: CharacterLook(
    name: 'Arslan',
    cloth: Color(0xFF4A3A2C),
    clothDark: Color(0xFF2C2119),
    cloak: Color(0xFF6E1E1A),
    hair: Color(0xFF1E1510),
    carried: Carried.sword,
  ),
  CharacterId.idris: CharacterLook(
    name: 'Master Idris',
    cloth: Color(0xFF5B5446),
    clothDark: Color(0xFF3A342A),
    cloak: Color(0xFF3F4A52),
    skin: Color(0xFFB88A66),
    hair: Color(0xFFBEB6A8),
    beard: Color(0xFFD2CBBE),
    carried: Carried.staff,
    height: 1.72,
  ),
  CharacterId.bashir: CharacterLook(
    name: 'Bashir',
    cloth: Color(0xFF7A5634),
    clothDark: Color(0xFF4A3220),
    skin: Color(0xFF9C6B48),
    headgear: Headgear.cap,
    beard: Color(0xFF2A1E16),
    carried: Carried.hammer,
  ),
  CharacterId.sethmose: CharacterLook(
    name: 'Pharaoh Sethmose',
    cloth: Color(0xFFE2D6B8),
    clothDark: Color(0xFFB8A882),
    cloak: Color(0xFF1F3F7A),
    skin: Color(0xFF8E5E3E),
    headgear: Headgear.nemes,
    carried: Carried.staff,
    height: 1.9,
  ),
  CharacterId.ironHand: CharacterLook(
    name: 'The Iron Hand',
    cloth: Color(0xFF222226),
    clothDark: Color(0xFF111114),
    cloak: Color(0xFF18181C),
    skin: Color(0xFF6E7276),
    headgear: Headgear.hood,
    carried: Carried.sword,
    height: 1.88,
  ),
  CharacterId.soldier: CharacterLook(
    name: 'Soldier',
    cloth: Color(0xFF8C2A20),
    clothDark: Color(0xFF561812),
    headgear: Headgear.helmet,
    carried: Carried.spear,
  ),
  CharacterId.messenger: CharacterLook(
    name: 'Roman Messenger',
    cloth: Color(0xFF9E2B25),
    clothDark: Color(0xFF6A1A16),
    cloak: Color(0xFFB08A2E),
    headgear: Headgear.helmet,
  ),
};

enum SceneProp { tent, campfire, shard, banner }
