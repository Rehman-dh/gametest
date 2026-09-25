import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../../meta/progress.dart';
import '../ui_style.dart';

/// The campaign map: the current era's sieges along a winding road, each
/// with its best star rating. Later eras are shown but sealed.
class WorldMap extends StatelessWidget {
  const WorldMap({super.key, required this.game});

  final SiegeGame game;

  static const _eras = [
    'Egypt',
    'Rome',
    'Persia',
    'Medieval',
    'China',
    'Mythic',
  ];

  /// Node positions as fractions of the map area.
  static Offset _nodeAt(int i, int count) => Offset(
    0.07 + 0.86 * i / math.max(1, count - 1),
    0.5 + 0.28 * math.sin(i * 1.15 + 0.4),
  );

  @override
  Widget build(BuildContext context) {
    final campaign = game.campaign!;
    return ValueListenableBuilder<Progress>(
      valueListenable: campaign.progress,
      builder: (context, progress, _) {
        final count = campaign.levels.length;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [Color(0xFF3A2E22), Color(0xFF15100C)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: game.showMenu,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: UiStyle.parchment,
                        ),
                      ),
                      const Text('ERA I · EGYPT', style: UiStyle.heading),
                      const Spacer(),
                      _GoldBadge(gold: progress.gold),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: game.showCamp,
                        icon: const Icon(Icons.fort),
                        label: const Text('SIEGE CAMP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UiStyle.parchment,
                          side: const BorderSide(color: UiStyle.bronze),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = box.biggest;
                        Offset at(int i) {
                          final f = _nodeAt(i, count);
                          return Offset(f.dx * size.width, f.dy * size.height);
                        }

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RoadPainter([
                                  for (var i = 0; i < count; i++) at(i),
                                ]),
                              ),
                            ),
                            for (var i = 0; i < count; i++)
                              Positioned(
                                left: at(i).dx - 28,
                                top: at(i).dy - 28,
                                child: _SiegeNode(
                                  number: i + 1,
                                  name: campaign.levels[i].name,
                                  stars: campaign.starsFor(i),
                                  won: progress.isWon(campaign.levels[i].id),
                                  unlocked: campaign.isUnlocked(i),
                                  onTap: () => game.openLevel(i),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (i, era) in _eras.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Chip(
                            avatar: i == 0
                                ? null
                                : const Icon(
                                    Icons.lock,
                                    size: 14,
                                    color: UiStyle.bronze,
                                  ),
                            label: Text(era),
                            backgroundColor: i == 0
                                ? const Color(0x55B0874A)
                                : UiStyle.ink,
                            side: const BorderSide(color: UiStyle.bronze),
                            labelStyle: UiStyle.body.copyWith(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    // Dashed road: short strokes along the path.
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 14) {
        canvas.drawPath(
          metric.extractPath(d, d + 7),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0x88B0874A),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.points != points;
}

class _SiegeNode extends StatelessWidget {
  const _SiegeNode({
    required this.number,
    required this.name,
    required this.stars,
    required this.won,
    required this.unlocked,
    required this.onTap,
  });

  final int number;
  final String name;
  final int stars;
  final bool won;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: unlocked ? onTap : null,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: won
                      ? const Color(0xFF6B4A22)
                      : (unlocked ? UiStyle.blood : const Color(0xFF2A2420)),
                  border: Border.all(
                    color: unlocked
                        ? UiStyle.parchment
                        : UiStyle.bronze.withValues(alpha: 0.4),
                    width: unlocked && !won ? 3 : 1.5,
                  ),
                ),
                child: unlocked
                    ? Text(
                        '$number',
                        style: UiStyle.body.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : const Icon(Icons.lock, color: UiStyle.bronze, size: 18),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var s = 0; s < 3; s++)
                    Icon(
                      s < stars ? Icons.star : Icons.star_border,
                      size: 13,
                      color: won
                          ? UiStyle.bronze
                          : UiStyle.bronze.withValues(alpha: 0.3),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldBadge extends StatelessWidget {
  const _GoldBadge({required this.gold});

  final int gold;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.paid, color: Color(0xFFD4A437), size: 20),
      const SizedBox(width: 4),
      Text('$gold', style: UiStyle.body.copyWith(fontWeight: FontWeight.w700)),
    ],
  );
}
