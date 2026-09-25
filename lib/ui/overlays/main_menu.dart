import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/siege_game.dart';
import '../../meta/campaign.dart';
import '../../meta/progress.dart';
import '../ui_style.dart';

/// Title screen over a live demo siege: a dark panel on the left with the
/// title and choices, embers drifting across everything.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.game});

  final SiegeGame game;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _intro.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// Fades and slides a child in, starting at [start] of the intro (0–1).
  Widget _enter(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(
        start,
        math.min(1, start + 0.45),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (_, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(-40 * (1 - curve.value), 0),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final campaign = game.campaign;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Darken the left for the menu, leave the siege visible on the right.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xF00B0806),
                  Color(0xB00B0806),
                  Color(0x000B0806),
                ],
                stops: [0, 0.38, 0.62],
              ),
            ),
          ),
        ),
        const IgnorePointer(child: _Embers()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 16, 10),
            child: ValueListenableBuilder<Progress?>(
              valueListenable:
                  campaign?.progress ?? ValueNotifier<Progress?>(null),
              builder: (context, progress, _) {
                final started = progress?.stars.isNotEmpty ?? false;
                final endlessOpen = campaign?.endlessUnlocked ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _enter(0, _Title(glow: _glow)),
                    const SizedBox(height: 4),
                    _enter(
                      0.1,
                      Text(
                        'Every wall has a flaw.',
                        style: UiStyle.body.copyWith(
                          fontStyle: FontStyle.italic,
                          color: UiStyle.parchment.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _enter(
                      0.25,
                      _MenuButton(
                        icon: Icons.local_fire_department,
                        label: started ? 'Continue campaign' : 'Begin campaign',
                        detail: 'Era I · Egypt',
                        primary: true,
                        onTap: game.showMap,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _enter(
                      0.35,
                      _MenuButton(
                        icon: Icons.fort,
                        label: 'Siege Camp',
                        detail: 'Buildings, crew and relics',
                        onTap: game.showCamp,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _enter(
                      0.45,
                      _MenuButton(
                        icon: Icons.all_inclusive,
                        label: 'Endless',
                        detail: endlessOpen
                            ? (progress!.endlessBest > 0
                                  ? 'Best ${progress.endlessBest} · ${progress.endlessBestDepth} castles'
                                  : 'Castle after castle, until you fall')
                            : 'Opens after The Oasis Garrison',
                        locked: !endlessOpen,
                        onTap: game.startEndless,
                      ),
                    ),
                    const Spacer(),
                    if (progress != null)
                      _enter(
                        0.6,
                        _Stats(progress: progress, campaign: campaign!),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.glow});

  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ERA I · EGYPT',
            style: UiStyle.body.copyWith(
              fontSize: 12,
              letterSpacing: 5,
              color: UiStyle.bronze,
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF6E6B8), Color(0xFFD2A55A), Color(0xFF8A6230)],
            ).createShader(bounds),
            child: Text(
              'THE LAST\nSIEGE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                height: 0.95,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                shadows: [
                  Shadow(
                    color: const Color(0xFFE08A3A)
                        .withValues(alpha: 0.25 + 0.3 * glow.value),
                    blurRadius: 18 + 10 * glow.value,
                  ),
                  const Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(2, 3),
                    blurRadius: 4,
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

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.primary = false,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool primary;
  final bool locked;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.locked;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.primary
                    ? const [Color(0xFF8E2A20), Color(0xFF5A1A14)]
                    : const [Color(0xEE2A1F16), Color(0xEE17110C)],
              ),
              border: Border.all(
                color: widget.primary
                    ? const Color(0xFFD9A860)
                    : UiStyle.bronze,
                width: widget.primary ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.locked ? Icons.lock_outline : widget.icon,
                  color: UiStyle.parchment,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label.toUpperCase(),
                        style: UiStyle.body.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        widget.detail,
                        style: UiStyle.body.copyWith(
                          fontSize: 11,
                          color: UiStyle.parchment.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: UiStyle.bronze),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.progress, required this.campaign});

  final Progress progress;
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final stars = progress.stars.values.fold(0, (a, b) => a + b);
    final maxStars = campaign.levels.length * 3;
    TextStyle style() => UiStyle.body.copyWith(fontSize: 13);
    return Row(
      children: [
        const Icon(Icons.paid, color: Color(0xFFD4A437), size: 18),
        const SizedBox(width: 4),
        Text('${progress.gold}', style: style()),
        const SizedBox(width: 18),
        const Icon(Icons.star, color: UiStyle.bronze, size: 18),
        const SizedBox(width: 4),
        Text('$stars / $maxStars', style: style()),
      ],
    );
  }
}

/// Glowing embers rising and swaying across the screen.
class _Embers extends StatefulWidget {
  const _Embers();

  @override
  State<_Embers> createState() => _EmbersState();
}

class _EmbersState extends State<_Embers> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _EmberPainter(_time),
    child: const SizedBox.expand(),
  );
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.time) : super(repaint: time);

  final ValueNotifier<double> time;
  static const _count = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final rng = math.Random(11);
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint();
    for (var i = 0; i < _count; i++) {
      final speed = 18 + rng.nextDouble() * 34;
      final period = (size.height + 60) / speed;
      final phase = rng.nextDouble() * period;
      final life = ((t + phase) % period) / period;
      final x0 = rng.nextDouble() * size.width;
      final sway = 14 + rng.nextDouble() * 22;
      final x = x0 + math.sin(t * (0.6 + rng.nextDouble()) + i) * sway;
      final y = size.height + 30 - life * (size.height + 60);
      final r = 1.0 + rng.nextDouble() * 2.2;
      // Brighten in, fade out near the top.
      final alpha =
          math.sin(life * math.pi) * (0.5 + 0.5 * math.sin(t * 6 + i));
      final color = Color.lerp(
        const Color(0xFFFFD27A),
        const Color(0xFFE0561E),
        rng.nextDouble(),
      )!;
      canvas
        ..drawCircle(
          Offset(x, y),
          r * 3,
          glow..color = color.withValues(alpha: 0.35 * alpha),
        )
        ..drawCircle(
          Offset(x, y),
          r,
          core..color = color.withValues(alpha: 0.9 * alpha),
        );
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => false;
}
