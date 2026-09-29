import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/era.dart';
import '../../game/siege_game.dart';
import '../../meta/progress.dart';
import '../ui_style.dart';

/// The campaign map: one era's sieges along a winding road, each with its
/// best star rating. An era opens once its first siege is unlocked; the
/// map starts on the era of the next siege to play.
class WorldMap extends StatefulWidget {
  const WorldMap({super.key, required this.game});

  final SiegeGame game;

  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  SiegeGame get game => widget.game;

  late Era _era = _currentEra();

  /// The era of the first open, unbeaten siege (or the last era reached).
  Era _currentEra() {
    final campaign = game.campaign!;
    var era = Era.egypt;
    for (var i = 0; i < campaign.levels.length; i++) {
      if (!campaign.isUnlocked(i)) break;
      era = campaign.levels[i].era;
      if (!campaign.progress.value.isWon(campaign.levels[i].id)) break;
    }
    return era;
  }

  /// Global level indices belonging to [era], in order.
  List<int> _levelsOf(Era era) => [
    for (var i = 0; i < game.campaign!.levels.length; i++)
      if (game.campaign!.levels[i].era == era) i,
  ];

  bool _isOpen(Era era) {
    final levels = _levelsOf(era);
    return levels.isNotEmpty && game.campaign!.isUnlocked(levels.first);
  }

  /// Node positions as fractions of the map area: a zigzag road, so
  /// neighbouring sieges sit on alternate rows and never crowd each other.
  static Offset _nodeAt(int i, int count) => Offset(
    0.06 + 0.88 * i / math.max(1, count - 1),
    (i.isEven ? 0.3 : 0.7) + 0.05 * math.sin(i * 0.9),
  );

  @override
  Widget build(BuildContext context) {
    final campaign = game.campaign!;
    return ValueListenableBuilder<Progress>(
      valueListenable: campaign.progress,
      builder: (context, progress, _) {
        final indices = _levelsOf(_era);
        final count = indices.length;
        // The first open, unbeaten siege pulses to invite a tap.
        var next = -1;
        for (var k = 0; k < count; k++) {
          final i = indices[k];
          if (campaign.isUnlocked(i) &&
              !progress.isWon(campaign.levels[i].id)) {
            next = k;
            break;
          }
        }
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3FA6DC), Color(0xFF70E0D5)],
            ),
          ),
          child: CustomPaint(
            painter: _SceneryPainter(_era),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    PopIn(
                      from: const Offset(0, -0.4),
                      child: Row(
                        children: [
                          CartoonButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: game.showMenu,
                            tone: ButtonTone.blue,
                            size: 0.9,
                          ),
                          const SizedBox(width: 12),
                          OutlinedText(_era.title, size: 26),
                          const Spacer(),
                          _GoldBadge(gold: progress.gold),
                          const SizedBox(width: 10),
                          CartoonButton(
                            label: 'Siege Camp',
                            icon: Icons.fort,
                            onPressed: game.showCamp,
                            tone: ButtonTone.orange,
                            size: 0.9,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final size = box.biggest;
                          Offset at(int i) {
                            final f = _nodeAt(i, count);
                            return Offset(
                              f.dx * size.width,
                              f.dy * size.height,
                            );
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
                              for (final (k, i) in indices.indexed)
                                Positioned(
                                  key: ValueKey(i),
                                  left: at(k).dx - _SiegeNode.width / 2,
                                  top: at(k).dy - _SiegeNode.badge / 2,
                                  child: PopIn(
                                    delay: Duration(milliseconds: 120 + 50 * k),
                                    from: Offset.zero,
                                    child: _SiegeNode(
                                      number: k + 1,
                                      name: campaign.levels[i].name,
                                      stars: campaign.starsFor(i),
                                      won: progress.isWon(
                                        campaign.levels[i].id,
                                      ),
                                      unlocked: campaign.isUnlocked(i),
                                      pulse: k == next,
                                      onTap: () => game.openLevel(i),
                                    ),
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
                        for (final (i, era) in Era.values.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: PopIn(
                              delay: Duration(milliseconds: 200 + 50 * i),
                              child: CartoonButton(
                                label: era.label,
                                icon: !_isOpen(era)
                                    ? Icons.lock
                                    : era == _era
                                    ? Icons.flag
                                    : null,
                                onPressed: _isOpen(era)
                                    ? () => setState(() => _era = era)
                                    : null,
                                tone: era == _era
                                    ? ButtonTone.orange
                                    : ButtonTone.plain,
                                size: 0.7,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Soft cartoon clouds in the sky, and along the bottom the era's land:
/// sandy dunes for Egypt, green hills for Rome.
class _SceneryPainter extends CustomPainter {
  const _SceneryPainter(this.era);

  final Era era;

  /// Clouds as (x, y, scale) fractions of the screen.
  static const _clouds = [
    (0.12, 0.2, 1.0),
    (0.48, 0.1, 0.8),
    (0.82, 0.24, 1.1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Opaque puffs in one translucent layer, so overlaps leave no seams.
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
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

    final h = size.height, w = size.width;
    Path dune(double top, double swell) => Path()
      ..moveTo(0, h * top)
      ..quadraticBezierTo(w * 0.25, h * (top - swell), w * 0.5, h * top)
      ..quadraticBezierTo(w * 0.75, h * (top + swell), w, h * top)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final (far, near) = switch (era) {
      Era.rome => (const Color(0xFF9BD46A), const Color(0xFF79BE4A)),
      Era.persia => (const Color(0xFFF0B872), const Color(0xFFD9914E)),
      Era.medieval => (const Color(0xFF6FA84A), const Color(0xFF4E8A36)),
      Era.china => (const Color(0xFF8CC08A), const Color(0xFF5E9E6A)),
      _ => (const Color(0xFFF4D48C), const Color(0xFFEBC173)),
    };
    canvas
      ..drawPath(dune(0.62, 0.08), Paint()..color = far)
      ..drawPath(dune(0.74, -0.06), Paint()..color = near);
  }

  @override
  bool shouldRepaint(_SceneryPainter old) => old.era != era;
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
    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    // A sandy road with an ink outline...
    canvas
      ..drawPath(path, stroke(18, UiStyle.ink))
      ..drawPath(path, stroke(12, const Color(0xFFFFE3A3)));
    // ...and a dotted centre line.
    final dots = stroke(4, const Color(0xFFC98A2E));
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 6), dots);
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
    required this.pulse,
    required this.onTap,
  });

  /// Overall width and badge diameter, used to centre nodes on the road.
  static const width = 72.0;
  static const badge = 56.0;

  final int number;
  final String name;
  final int stars;
  final bool won;
  final bool unlocked;
  final bool pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (light, dark) = won
        ? (const Color(0xFF9BE870), const Color(0xFF3E9E2C))
        : unlocked
        ? (const Color(0xFFFFD66B), const Color(0xFFE0782A))
        : (const Color(0xFFD6D2CC), const Color(0xFF8E8880));
    Widget circle = Container(
      width: badge,
      height: badge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, dark],
        ),
        border: Border.all(color: UiStyle.ink, width: 3.5),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), offset: Offset(0, 4)),
        ],
      ),
      child: unlocked
          ? OutlinedText('$number', size: 24, stroke: 5, letterSpacing: 0)
          : const Icon(
              Icons.lock,
              color: Colors.white,
              size: 24,
              shadows: [Shadow(color: UiStyle.ink, offset: Offset(0, 2))],
            ),
    );
    if (pulse) circle = _Pulse(child: circle);
    return Tooltip(
      message: name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: unlocked ? onTap : null,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              circle,
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var s = 0; s < 3; s++) _Star(filled: s < stars),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gently breathes its child in and out.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// A small gold star with an ink outline; grey when not yet earned.
class _Star extends StatelessWidget {
  const _Star({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.star_rounded, size: 22, color: UiStyle.ink),
        Icon(
          Icons.star_rounded,
          size: 15,
          color: filled ? UiStyle.gold : const Color(0xFFE8DCC4),
        ),
      ],
    ),
  );
}

class _GoldBadge extends StatelessWidget {
  const _GoldBadge({required this.gold});

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
        const _Coin(),
        const SizedBox(width: 6),
        Text(
          '$gold',
          style: UiStyle.body.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

/// A round gold coin with an ink rim.
class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) => Container(
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
        color: Color(0xFF9A5B12),
        fontSize: 13,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}
