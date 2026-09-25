import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../../meta/catalog.dart';
import '../../meta/progress.dart';
import '../ui_style.dart';

/// Warm brown for secondary notes on cream cards.
const _note = Color(0xFF9A5B12);

/// The player's base: spend gold on buildings, review crew and relics.
class SiegeCamp extends StatelessWidget {
  const SiegeCamp({super.key, required this.game});

  final SiegeGame game;

  /// Stagger for card entrances.
  static Duration _delay(int i) => Duration(milliseconds: 100 + 50 * i);

  @override
  Widget build(BuildContext context) {
    final campaign = game.campaign!;
    return ValueListenableBuilder<Progress>(
      valueListenable: campaign.progress,
      builder: (context, progress, _) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3FA6DC), Color(0xFF70E0D5)],
          ),
        ),
        child: CustomPaint(
          painter: const _CloudPainter(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PopIn(
                    from: const Offset(0, -0.4),
                    child: Row(
                      children: [
                        CartoonButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: game.showMap,
                          tone: ButtonTone.blue,
                          size: 0.9,
                        ),
                        const SizedBox(width: 12),
                        const OutlinedText('SIEGE CAMP', size: 28),
                        const Spacer(),
                        _GoldPill(gold: progress.gold),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('BUILDINGS', UiStyle.blood),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final (i, id) in BuildingId.values.indexed)
                                PopIn(
                                  delay: _delay(i),
                                  child: _BuildingCard(
                                    spec: buildingSpecs[id]!,
                                    level: progress.building(id),
                                    gold: progress.gold,
                                    onUpgrade: () => campaign.upgrade(id),
                                  ),
                                ),
                            ],
                          ),
                          _section('CREW', const Color(0xFF2E8FCB)),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final (i, id) in CrewId.values.indexed)
                                PopIn(
                                  delay: _delay(i + 2),
                                  child: _CrewCard(
                                    spec: crewSpecs[id]!,
                                    joined: progress.hasCrew(id),
                                    level: progress.crewLevel(id),
                                    xp: progress.crewXp[id] ?? 0,
                                  ),
                                ),
                            ],
                          ),
                          _section('TROPHY HALL · RELICS', UiStyle.bronze),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final (i, id) in RelicId.values.indexed)
                                PopIn(
                                  delay: _delay(i + 4),
                                  child: _RelicCard(
                                    spec: relicSpecs[id]!,
                                    found: progress.relics.contains(id),
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
      ),
    );
  }

  Widget _section(String title, Color color) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 10),
    child: RibbonTitle(title, color: color),
  );
}

/// Soft white cartoon clouds drifting behind the camp.
class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  /// Clouds as (x, y, scale) fractions of the screen.
  static const _clouds = [(0.2, 0.12, 0.9), (0.62, 0.3, 1.1), (0.9, 0.7, 0.8)];

  @override
  void paint(Canvas canvas, Size size) {
    // Opaque puffs in one translucent layer, so overlaps leave no seams.
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    final white = Paint()..color = Colors.white;
    for (final (x, y, s) in _clouds) {
      final c = Offset(x * size.width, y * size.height);
      final r = 26.0 * s;
      canvas
        ..drawCircle(c + Offset(-r * 1.1, r * 0.3), r * 0.8, white)
        ..drawCircle(c, r, white)
        ..drawCircle(c + Offset(r * 1.1, r * 0.25), r * 0.85, white)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(c.dx - r * 1.9, c.dy, c.dx + r * 1.95, c.dy + r),
            Radius.circular(r / 2),
          ),
          white,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloudPainter old) => false;
}

class _Card extends StatelessWidget {
  const _Card({required this.width, required this.child, this.dimmed = false});

  final double width;
  final Widget child;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: dimmed ? 0.7 : 1,
    child: Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: dimmed
          ? UiStyle.panelDecoration.copyWith(color: UiStyle.panelDeep)
          : UiStyle.panelDecoration,
      child: child,
    ),
  );
}

/// A round icon medallion heading a card.
class _Medal extends StatelessWidget {
  const _Medal({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, 0.35)!, color],
      ),
      border: Border.all(color: UiStyle.ink, width: 3),
    ),
    child: Icon(
      icon,
      color: Colors.white,
      size: 20,
      shadows: const [Shadow(color: UiStyle.ink, offset: Offset(0, 2))],
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
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Medal(icon: Icons.foundation, color: UiStyle.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.name,
                  style: UiStyle.body.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              // Level pips.
              for (var i = 0; i < spec.maxLevel; i++)
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < level ? UiStyle.gold : UiStyle.panelDeep,
                    border: Border.all(color: UiStyle.ink, width: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: Text(
              maxed ? 'Fully built.' : 'Next: ${spec.levels[level]}',
              style: UiStyle.body.copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          CartoonButton(
            width: double.infinity,
            size: 0.8,
            label: maxed ? 'Maxed' : 'Upgrade  $cost',
            icon: maxed ? Icons.check_rounded : Icons.monetization_on,
            tone: ButtonTone.green,
            onPressed: !maxed && gold >= cost ? onUpgrade : null,
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
      width: 260,
      dimmed: !joined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Medal(
                icon: joined ? Icons.person : Icons.lock,
                color: joined ? UiStyle.sky : const Color(0xFF8E8880),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.name,
                      style: UiStyle.body.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      spec.role,
                      style: UiStyle.body.copyWith(fontSize: 12, color: _note),
                    ),
                  ],
                ),
              ),
              if (joined)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: UiStyle.leaf,
                    border: Border.all(color: UiStyle.ink, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: OutlinedText(
                    'Lv $level',
                    size: 13,
                    stroke: 3,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (!joined)
            Text(spec.joins, style: UiStyle.body.copyWith(fontSize: 12))
          else ...[
            Text(spec.passive, style: UiStyle.body.copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            Text(
              '${spec.abilityName}: ${spec.ability}',
              style: UiStyle.body.copyWith(fontSize: 12, color: _note),
            ),
            if (toNext != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$toNext XP to next level',
                  style: UiStyle.body.copyWith(
                    fontSize: 11,
                    color: UiStyle.ink.withValues(alpha: 0.65),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RelicCard extends StatelessWidget {
  const _RelicCard({required this.spec, required this.found});

  final RelicSpec spec;
  final bool found;

  @override
  Widget build(BuildContext context) => _Card(
    width: 230,
    dimmed: !found,
    child: Row(
      children: [
        _Medal(
          icon: found ? Icons.auto_awesome : Icons.question_mark_rounded,
          color: found ? const Color(0xFFE9A31C) : const Color(0xFF8E8880),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                found ? spec.name : 'Undiscovered relic',
                style: UiStyle.body.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                found ? spec.effect : 'Hidden somewhere in Egypt',
                style: UiStyle.body.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The player's purse: a gold coin and the amount on a cream pill.
class _GoldPill extends StatelessWidget {
  const _GoldPill({required this.gold});

  final int gold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
    decoration: BoxDecoration(
      color: UiStyle.panel,
      border: Border.all(color: UiStyle.ink, width: 3),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE27A), Color(0xFFE9A31C)],
            ),
            border: Border.all(color: UiStyle.ink, width: 2.5),
          ),
          child: const Text(
            '\$',
            style: TextStyle(
              color: _note,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$gold gold',
          style: UiStyle.body.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
