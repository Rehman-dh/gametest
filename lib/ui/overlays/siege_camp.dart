import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../../meta/catalog.dart';
import '../../meta/progress.dart';
import '../ui_style.dart';

/// The player's base: spend gold on buildings, review crew and relics.
class SiegeCamp extends StatelessWidget {
  const SiegeCamp({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    final campaign = game.campaign!;
    return ValueListenableBuilder<Progress>(
      valueListenable: campaign.progress,
      builder: (context, progress, _) => ColoredBox(
        color: const Color(0xF2120E0B),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: game.showMap,
                      icon: const Icon(
                        Icons.arrow_back,
                        color: UiStyle.parchment,
                      ),
                    ),
                    const Text('SIEGE CAMP', style: UiStyle.heading),
                    const Spacer(),
                    const Icon(Icons.paid, color: Color(0xFFD4A437)),
                    const SizedBox(width: 4),
                    Text(
                      '${progress.gold} gold',
                      style: UiStyle.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section('BUILDINGS'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final id in BuildingId.values)
                              _BuildingCard(
                                spec: buildingSpecs[id]!,
                                level: progress.building(id),
                                gold: progress.gold,
                                onUpgrade: () => campaign.upgrade(id),
                              ),
                          ],
                        ),
                        _section('CREW'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final id in CrewId.values)
                              _CrewCard(
                                spec: crewSpecs[id]!,
                                joined: progress.hasCrew(id),
                                level: progress.crewLevel(id),
                                xp: progress.crewXp[id] ?? 0,
                              ),
                          ],
                        ),
                        _section('TROPHY HALL · RELICS'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final id in RelicId.values)
                              _Card(
                                width: 220,
                                dimmed: !progress.relics.contains(id),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      progress.relics.contains(id)
                                          ? relicSpecs[id]!.name
                                          : 'Undiscovered relic',
                                      style: UiStyle.body.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      progress.relics.contains(id)
                                          ? relicSpecs[id]!.effect
                                          : 'Hidden somewhere in Egypt',
                                      style: UiStyle.body.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      title,
      style: UiStyle.body.copyWith(
        fontSize: 12,
        letterSpacing: 2,
        color: UiStyle.bronze,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.width, required this.child, this.dimmed = false});

  final double width;
  final Widget child;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dimmed ? 0.45 : 1,
    child: Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: UiStyle.panelDecoration,
      child: child,
    ),
  );
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.spec,
    required this.level,
    required this.gold,
    required this.onUpgrade,
  });

  final BuildingSpec spec;
  final int level;
  final int gold;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final maxed = level >= spec.maxLevel;
    final cost = maxed ? 0 : spec.costs[level];
    return _Card(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                spec.name,
                style: UiStyle.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              for (var i = 0; i < spec.maxLevel; i++)
                Icon(
                  i < level ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: UiStyle.bronze,
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 34,
            child: Text(
              maxed ? 'Fully built.' : 'Next: ${spec.levels[level]}',
              style: UiStyle.body.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: !maxed && gold >= cost ? onUpgrade : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: UiStyle.parchment,
                side: const BorderSide(color: UiStyle.bronze),
              ),
              child: Text(maxed ? 'MAXED' : 'UPGRADE · $cost'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrewCard extends StatelessWidget {
  const _CrewCard({
    required this.spec,
    required this.joined,
    required this.level,
    required this.xp,
  });

  final CrewSpec spec;
  final bool joined;
  final int level;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final toNext = level >= crewMaxLevel
        ? null
        : crewXpPerLevel - xp % crewXpPerLevel;
    return _Card(
      width: 250,
      dimmed: !joined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            joined
                ? '${spec.name} · ${spec.role} · Lv $level'
                : '${spec.name} · ${spec.role}',
            style: UiStyle.body.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (!joined)
            Text(
              spec.joins,
              style: UiStyle.body.copyWith(fontSize: 12, color: UiStyle.bronze),
            )
          else ...[
            Text(spec.passive, style: UiStyle.body.copyWith(fontSize: 12)),
            Text(
              '${spec.abilityName}: ${spec.ability}',
              style: UiStyle.body.copyWith(fontSize: 12, color: UiStyle.bronze),
            ),
            if (toNext != null)
              Text(
                '$toNext XP to next level',
                style: UiStyle.body.copyWith(fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }
}
