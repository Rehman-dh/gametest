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
        if (game.endless == null)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Score(score: game.score),
              ),
            ),
          ),
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
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PopIn(
              from: const Offset(-0.3, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                decoration: UiStyle.panelDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      game.endless == null
                          ? game.level.name
                          : 'Endless · ${game.level.name} · '
                                '${game.endless!.score} pts',
                      style: UiStyle.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AmmoPicker(game: game),
                  ],
                ),
              ),
            ),
            if (game.level.hasCounterFire) ...[
              const SizedBox(width: 8),
              PopIn(
                delay: const Duration(milliseconds: 80),
                from: const Offset(0, -0.4),
                child: _EngineHealth(game: game),
              ),
            ],
            if (game.level.wind != 0) ...[
              const SizedBox(width: 8),
              PopIn(
                delay: const Duration(milliseconds: 140),
                from: const Offset(0, -0.4),
                child: _WindIndicator(wind: game.level.wind),
              ),
            ],
            const Spacer(),
            PopIn(
              delay: const Duration(milliseconds: 100),
              from: const Offset(0, -0.4),
              child: _CrewAbilities(game: game),
            ),
            // No do-overs in endless mode.
            if (game.endless == null) ...[
              PopIn(
                delay: const Duration(milliseconds: 160),
                from: const Offset(0, -0.4),
                child: _IconAction(
                  icon: Icons.replay,
                  tone: ButtonTone.orange,
                  onTap: () =>
                      game.startLevel(game.levelIndex, loadout: game.loadout),
                ),
              ),
              const SizedBox(width: 8),
            ],
            PopIn(
              delay: const Duration(milliseconds: 220),
              from: const Offset(0, -0.4),
              child: _IconAction(
                icon: Icons.map_outlined,
                tone: ButtonTone.blue,
                onTap: game.showMap,
              ),
            ),
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
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _hint(selected)!,
                  style: UiStyle.body.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: UiStyle.ink.withValues(alpha: 0.7),
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

/// A chunky ammo slot: the round on a rounded tile, a count badge in the
/// corner, and a gold ring with a little bump when selected.
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
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Tooltip(
        message: type.spec.label,
        child: GestureDetector(
          onTap: empty ? null : onTap,
          child: AnimatedScale(
            scale: selected ? 1.1 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Opacity(
              opacity: empty ? 0.4 : 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: selected
                            ? const [Color(0xFFFFF6C8), Color(0xFFFFD86A)]
                            : const [Colors.white, UiStyle.panelDeep],
                      ),
                      border: Border.all(color: UiStyle.ink, width: 2.5),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        if (selected)
                          const BoxShadow(color: UiStyle.gold, spreadRadius: 3),
                        const BoxShadow(
                          color: Color(0x44000000),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AmmoIcon(type: type, theme: theme, size: 32),
                    ),
                  ),
                  Positioned(
                    right: -7,
                    top: -7,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: empty ? UiStyle.ink : UiStyle.blood,
                        border: Border.all(color: UiStyle.ink, width: 2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      decoration: UiStyle.panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'WIND',
            style: UiStyle.body.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < wind.abs().ceil().clamp(1, 4); i++)
                Icon(
                  towardCastle
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: UiStyle.sky,
                  size: 18,
                  shadows: const [
                    Shadow(color: UiStyle.ink, offset: Offset(0, 1.5)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A round, icon-only cartoon button for the top-right corner.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    this.tone = ButtonTone.plain,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) =>
      CartoonButton(icon: icon, onPressed: onTap, tone: tone, size: 0.9);
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: UiStyle.panelDecoration,
      child: ValueListenableBuilder<double>(
        valueListenable: game.playerHp,
        builder: (_, hp, _) {
          final fraction = (hp / game.playerMaxHp).clamp(0.0, 1.0);
          final fill = Color.lerp(UiStyle.blood, UiStyle.leaf, fraction)!;
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
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: phase == SiegePhase.enemyTurn
                        ? UiStyle.blood
                        : UiStyle.ink,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              // A chunky outlined bar with the hit points printed inside.
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: UiStyle.ink.withValues(alpha: 0.25),
                  border: Border.all(color: UiStyle.ink, width: 2.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7.5),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: fraction,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(fill, Colors.white, 0.35)!,
                                fill,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: OutlinedText(
                          '${hp.round()} / ${game.playerMaxHp.round()}',
                          size: 11,
                          stroke: 3,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final id in game.loadout.crew)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CartoonButton(
                    label: crewSpecs[id]!.abilityName,
                    icon: Icons.bolt,
                    tone: ButtonTone.blue,
                    size: 0.7,
                    onPressed: used.contains(id)
                        ? null
                        : () => game.useCrewAbility(id),
                  ),
                  const SizedBox(height: 2),
                  OutlinedText(
                    crewSpecs[id]!.name,
                    size: 11,
                    stroke: 3,
                    letterSpacing: 0.5,
                  ),
                ],
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
                child: PopIn(
                  from: const Offset(0, -0.3),
                  child: GestureDetector(
                    onTap: () => game.banner.value = null,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                      decoration: UiStyle.panelDecoration,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Portrait(
                            look: line.look,
                            theme: game.theme,
                            size: 46,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _NameTag(
                                  name: line.look.name,
                                  color: line.look.cloth,
                                ),
                                const SizedBox(height: 3),
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
      ),
    );
  }
}

/// A small coloured tag with the speaker's name.
class _NameTag extends StatelessWidget {
  const _NameTag({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: UiStyle.ink, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: OutlinedText(
        name.toUpperCase(),
        size: 10,
        stroke: 3,
        letterSpacing: 1.5,
      ),
    );
  }
}

/// The siege score, big and bold at the top of the screen; it bumps up
/// each time points land.
class _Score extends StatelessWidget {
  const _Score({required this.score});

  final ValueNotifier<int> score;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: score,
      builder: (context, value, _) => TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: value == 0 ? 1 : 1.18, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Stack(
          children: [
            Text(
              'SCORE  $value',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 5
                  ..strokeJoin = StrokeJoin.round
                  ..color = const Color(0xFF2B1A0E),
              ),
            ),
            Text(
              'SCORE  $value',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
