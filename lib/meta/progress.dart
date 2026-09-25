import 'dart:convert';

import 'catalog.dart';

/// Everything that persists between sessions. Immutable; campaign code
/// derives updated copies and saves them.
class Progress {
  const Progress({
    this.gold = 0,
    this.stars = const {},
    this.buildings = const {},
    this.crewXp = const {},
    this.relics = const {},
  });

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    gold: json['gold'] as int? ?? 0,
    stars: {
      for (final e in (json['stars'] as Map? ?? {}).entries)
        e.key as String: e.value as int,
    },
    buildings: {
      for (final e in (json['buildings'] as Map? ?? {}).entries)
        ?_byName(BuildingId.values, e.key): e.value as int,
    },
    crewXp: {
      for (final e in (json['crewXp'] as Map? ?? {}).entries)
        ?_byName(CrewId.values, e.key): e.value as int,
    },
    relics: {
      for (final r in json['relics'] as List? ?? const [])
        ?_byName(RelicId.values, r),
    },
  );

  factory Progress.decode(String source) =>
      Progress.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final int gold;

  /// Best star rating per level id; present only for levels won.
  final Map<String, int> stars;
  final Map<BuildingId, int> buildings;

  /// Experience of each crew member who has joined.
  final Map<CrewId, int> crewXp;
  final Set<RelicId> relics;

  int building(BuildingId id) => buildings[id] ?? 0;
  bool hasCrew(CrewId id) => crewXp.containsKey(id);
  int crewLevel(CrewId id) => crewLevelFor(crewXp[id] ?? 0);
  bool isWon(String levelId) => stars.containsKey(levelId);

  Progress copyWith({
    int? gold,
    Map<String, int>? stars,
    Map<BuildingId, int>? buildings,
    Map<CrewId, int>? crewXp,
    Set<RelicId>? relics,
  }) => Progress(
    gold: gold ?? this.gold,
    stars: stars ?? this.stars,
    buildings: buildings ?? this.buildings,
    crewXp: crewXp ?? this.crewXp,
    relics: relics ?? this.relics,
  );

  Map<String, dynamic> toJson() => {
    'gold': gold,
    'stars': stars,
    'buildings': {for (final e in buildings.entries) e.key.name: e.value},
    'crewXp': {for (final e in crewXp.entries) e.key.name: e.value},
    'relics': [for (final r in relics) r.name],
  };

  String encode() => jsonEncode(toJson());

  /// Unknown names (from a newer save) are dropped rather than crashing.
  static T? _byName<T extends Enum>(List<T> values, Object? name) =>
      values.where((v) => v.name == name).firstOrNull;
}
