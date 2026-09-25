import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../levels/level_data.dart';
import 'catalog.dart';
import 'endless.dart';
import 'loadout.dart';
import 'progress.dart';
import 'rewards.dart';
import 'save_repository.dart';

/// The player's campaign: level list, persistent progress and the actions
/// that change it (finishing sieges, upgrading the camp).
class Campaign {
  Campaign({required this.levelFiles, this.repository});

  final List<String> levelFiles;
  final SaveRepository? repository;

  final ValueNotifier<Progress> progress = ValueNotifier(const Progress());
  List<LevelData> levels = const [];

  Armory get armory => Armory(progress.value);

  Future<void> load() async {
    levels = [
      for (final file in levelFiles)
        LevelData.parse(await rootBundle.loadString(file)),
    ];
    final saved = await repository?.load();
    if (saved != null) progress.value = saved;
  }

  /// The first level is always open; each later one opens once the
  /// previous one is won.
  bool isUnlocked(int index) =>
      index == 0 || progress.value.isWon(levels[index - 1].id);

  int starsFor(int index) => progress.value.stars[levels[index].id] ?? 0;

  Reward recordResult({
    required LevelData level,
    required bool won,
    required int stars,
    required Loadout loadout,
  }) {
    final (updated, reward) = applyResult(
      progress: progress.value,
      level: level,
      won: won,
      stars: stars,
      crew: loadout.crew,
    );
    _commit(updated);
    return reward;
  }

  bool hasSeen(String cutscene) =>
      progress.value.seenCutscenes.contains(cutscene);

  void markSeen(String cutscene) {
    if (hasSeen(cutscene)) return;
    _commit(
      progress.value.copyWith(
        seenCutscenes: {...progress.value.seenCutscenes, cutscene},
      ),
    );
  }

  /// Endless mode opens once the Oasis Garrison has fallen.
  static const endlessUnlockLevel = 'egypt_10';

  bool get endlessUnlocked => progress.value.isWon(endlessUnlockLevel);

  /// Banks a finished endless run; returns whether it set a new best.
  bool recordEndless(EndlessRun run) {
    final p = progress.value;
    final best = run.score > p.endlessBest;
    _commit(
      p.copyWith(
        gold: p.gold + run.goldEarned,
        endlessBest: best ? run.score : p.endlessBest,
        endlessBestDepth: run.castlesTaken > p.endlessBestDepth
            ? run.castlesTaken
            : p.endlessBestDepth,
      ),
    );
    return best;
  }

  bool upgrade(BuildingId building) {
    final updated = upgradeBuilding(progress.value, building);
    if (updated == null) return false;
    _commit(updated);
    return true;
  }

  void _commit(Progress updated) {
    if (identical(updated, progress.value)) return;
    progress.value = updated;
    unawaited(repository?.save(updated));
  }
}
