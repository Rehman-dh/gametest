import 'package:flutter/material.dart';

import '../../core/ammo.dart';
import '../../game/siege_game.dart';
import '../../meta/catalog.dart';
import '../../theme/art_theme.dart';
import '../ui_style.dart';
import '../widgets/ammo_icon.dart';
import '../widgets/portrait.dart';
import '../../cutscene/cutscene_player.dart';

class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _topBar(),
        // The sky is empty; the castle's base is not.
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 84),
            child: _SpeechBanner(game: game),
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: UiStyle.panelDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(game.level.name, style: UiStyle.body),
                  const SizedBox(height: 6),
                  _AmmoPicker(game: game),
                ],
              ),
            ),
            if (game.level.hasCounterFire) ...[
              const SizedBox(width: 10),
              _EngineHealth(game: game),
            ],
            if (game.level.wind != 0) ...[
              const SizedBox(width: 10),
              _WindIndicator(wind: game.level.wind),
            ],
            const Spacer(),
            _CrewAbilities(game: game),
            _IconAction(
              icon: Icons.replay,
              onTap: () =>
                  game.startLevel(game.levelIndex, loadout: game.loadout),
            ),
            const SizedBox(width: 8),
            _IconAction(icon: Icons.map_outlined, onTap: game.showMap),
          ],
        ),
      ),
    );
  }
}

class _AmmoPicker extends StatelessWidget {
  const _AmmoPicker({required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    // A Set keeps the level's order, so the loadout reads left to right.
    final types = game.loadout.ammo.toSet();
    return ValueListenableBuilder<Map<AmmoType, int>>(
      valueListenable: game.ammo,
      builder: (_, counts, _) => ValueListenableBuilder<AmmoType?>(
        valueListenable: game.selectedAmmo,
        builder: (_, selected, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final type in types)
                  _AmmoChip(
                    type: type,
                    count: counts[type] ?? 0,
                    selected: type == selected,
                    theme: game.theme,
                    onTap: () => game.selectAmmo(type),
                  ),
              ],
            ),
            if (selected != null && _hint(selected) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _hint(selected)!,
                  style: UiStyle.body.copyWith(
                    fontSize: 12,
                    color: UiStyle.bronze,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String? _hint(AmmoType type) {
    final spec = type.spec;
    if (spec.splitsOnTap) return 'Tap mid-flight to split';
    if (spec.explodes) return 'Tap mid-flight to detonate';
    if (spec.ignites) return 'Sets wood ablaze';
    return null;
  }
}

class _AmmoChip extends StatelessWidget {
  const _AmmoChip({
    required this.type,
    required this.count,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final AmmoType type;
  final int count;
  final bool selected;
  final ArtTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = count == 0;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: type.spec.label,
        child: GestureDetector(
          onTap: empty ? null : onTap,
          child: Opacity(
            opacity: empty ? 0.3 : 1,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? const Color(0x55B0874A) : Colors.transparent,
                border: Border.all(
                  color: selected ? UiStyle.parchment : UiStyle.bronze,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  Center(
                    child: AmmoIcon(type: type, theme: theme, size: 36),
                  ),
                  Positioned(
                    right: 3,
                    bottom: 1,
                    child: Text(
                      '$count',
                      style: UiStyle.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindIndicator extends StatelessWidget {
  const _WindIndicator({required this.wind});

  final double wind;

  @override
  Widget build(BuildContext context) {
    final towardCastle = wind > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: UiStyle.panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'WIND',
            style: UiStyle.body.copyWith(fontSize: 11, letterSpacing: 2),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < wind.abs().ceil().clamp(1, 4); i++)
                Icon(
                  towardCastle ? Icons.chevron_right : Icons.chevron_left,
                  color: UiStyle.parchment,
                  size: 18,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: UiStyle.panel,
      shape: const CircleBorder(side: BorderSide(color: UiStyle.bronze)),
      child: IconButton(
        icon: Icon(icon, color: UiStyle.parchment),
        onPressed: onTap,
      ),
    );
  }
}

/// Hit points of the player's siege engine, plus a warning while the
/// enemy is taking its turn.
class _EngineHealth extends StatelessWidget {
  const _EngineHealth({required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: UiStyle.panelDecoration,
      child: ValueListenableBuilder<double>(
        valueListenable: game.playerHp,
        builder: (_, hp, _) {
          final fraction = (hp / game.playerMaxHp).clamp(0.0, 1.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<SiegePhase>(
                valueListenable: game.phase,
                builder: (_, phase, _) => Text(
                  phase == SiegePhase.enemyTurn
                      ? 'ENEMY VOLLEY!'
                      : 'YOUR ENGINE',
                  style: UiStyle.body.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: phase == SiegePhase.enemyTurn
                        ? const Color(0xFFE08A6A)
                        : UiStyle.parchment,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  backgroundColor: const Color(0x33E8D9B8),
                  color: Color.lerp(
                    UiStyle.blood,
                    const Color(0xFF8FA858),
                    fraction,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hp.round()} / ${game.playerMaxHp.round()}',
                style: UiStyle.body.copyWith(fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One button per crew member brought to this siege; each ability can be
/// used once, while aiming.
class _CrewAbilities extends StatelessWidget {
  const _CrewAbilities({required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    if (game.loadout.crew.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<Set<CrewId>>(
      valueListenable: game.usedAbilities,
      builder: (_, used, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final id in game.loadout.crew)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: used.contains(id)
                    ? null
                    : () => game.useCrewAbility(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UiStyle.parchment,
                  backgroundColor: UiStyle.panel,
                  side: const BorderSide(color: UiStyle.bronze),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      crewSpecs[id]!.abilityName.toUpperCase(),
                      style: const TextStyle(fontSize: 11, letterSpacing: 1),
                    ),
                    Text(
                      crewSpecs[id]!.name,
                      style: const TextStyle(
                        fontSize: 10,
                        color: UiStyle.bronze,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A line spoken mid-siege (tutorial hints, crew advice, enemy taunts).
class _SpeechBanner extends StatelessWidget {
  const _SpeechBanner({required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SpokenLine?>(
      valueListenable: game.banner,
      builder: (_, line, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: line == null
            ? const SizedBox.shrink()
            : SafeArea(
                key: ValueKey(line),
                child: GestureDetector(
                  onTap: () => game.banner.value = null,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(8),
                    decoration: UiStyle.panelDecoration,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Portrait(look: line.look, theme: game.theme, size: 44),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                line.look.name.toUpperCase(),
                                style: UiStyle.body.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: UiStyle.bronze,
                                ),
                              ),
                              Text(
                                line.text,
                                style: UiStyle.body.copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
