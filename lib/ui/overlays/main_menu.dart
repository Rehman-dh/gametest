import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../../meta/campaign.dart';
import '../../meta/progress.dart';
import '../ui_style.dart';

/// Title screen over a live demo siege: a bouncing title, one big play
/// button, and the camp and endless mode beside it.
class MainMenu extends StatefulWidget {
  const MainMenu({super.key, required this.game});

  final SiegeGame game;

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu>
    with SingleTickerProviderStateMixin {
  /// Drives the title's gentle float.
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final campaign = game.campaign;
    return Stack(
      fit: StackFit.expand,
      children: [
        // A soft wash at the top so the title reads over any sky.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x552B1A0E), Color(0x002B1A0E)],
                stops: [0, 0.45],
              ),
            ),
          ),
        ),
        SafeArea(
          child: ValueListenableBuilder<Progress?>(
            valueListenable:
                campaign?.progress ?? ValueNotifier<Progress?>(null),
            builder: (context, progress, _) {
              final started = progress?.stars.isNotEmpty ?? false;
              final endlessOpen = campaign?.endlessUnlocked ?? false;
              return Stack(
                children: [
                  if (progress != null)
                    Positioned(
                      top: 10,
                      right: 16,
                      child: PopIn(
                        delay: const Duration(milliseconds: 700),
                        from: const Offset(0.4, 0),
                        child: _Stats(progress: progress, campaign: campaign!),
                      ),
                    ),
                  Align(
                    alignment: const Alignment(0, -0.2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopIn(
                          from: const Offset(0, -0.6),
                          child: AnimatedBuilder(
                            animation: _float,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(
                                0,
                                math.sin(_float.value * 2 * math.pi) * 4,
                              ),
                              child: child,
                            ),
                            child: const _Title(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const PopIn(
                          delay: Duration(milliseconds: 200),
                          child: RibbonTitle(
                            'Every wall has a flaw',
                            color: Color(0xFFC98A2E),
                          ),
                        ),
                        const SizedBox(height: 22),
                        PopIn(
                          delay: const Duration(milliseconds: 380),
                          child: _PulsingPlay(
                            label: started ? 'Continue' : 'Play',
                            onTap: game.showMap,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopIn(
                              delay: const Duration(milliseconds: 520),
                              child: CartoonButton(
                                label: 'Siege Camp',
                                icon: Icons.fort,
                                tone: ButtonTone.orange,
                                onPressed: game.showCamp,
                              ),
                            ),
                            const SizedBox(width: 14),
                            PopIn(
                              delay: const Duration(milliseconds: 620),
                              child: CartoonButton(
                                label: endlessOpen
                                    ? 'Endless'
                                    : 'Endless · locked',
                                icon: endlessOpen
                                    ? Icons.all_inclusive
                                    : Icons.lock,
                                tone: ButtonTone.blue,
                                onPressed: endlessOpen
                                    ? game.startEndless
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        if (endlessOpen && (progress?.endlessBest ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedText(
                              'Endless best ${progress!.endlessBest} · '
                              '${progress.endlessBestDepth} castles',
                              size: 13,
                              stroke: 3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          'THE LAST SIEGE',
          style: TextStyle(
            fontSize: 58,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10
              ..strokeJoin = StrokeJoin.round
              ..color = UiStyle.ink,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4B0), Color(0xFFFFC933), Color(0xFFE88A1C)],
            stops: [0, 0.5, 1],
          ).createShader(bounds),
          child: const Text(
            'THE LAST SIEGE',
            style: TextStyle(
              fontSize: 58,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// The main call to action, breathing gently so the eye finds it.
class _PulsingPlay extends StatefulWidget {
  const _PulsingPlay({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PulsingPlay> createState() => _PulsingPlayState();
}

class _PulsingPlayState extends State<_PulsingPlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.06,
      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: CartoonButton(
        label: widget.label,
        icon: Icons.play_arrow_rounded,
        size: 1.5,
        width: 260,
        onPressed: widget.onTap,
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
    Widget pill(IconData icon, Color color, String text) => Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      decoration: BoxDecoration(
        color: UiStyle.panel,
        border: Border.all(color: UiStyle.ink, width: 3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
            shadows: const [Shadow(color: UiStyle.ink, offset: Offset(0, 1.5))],
          ),
          const SizedBox(width: 6),
          Text(text, style: UiStyle.body.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
    return Row(
      children: [
        pill(Icons.monetization_on, UiStyle.gold, '${progress.gold}'),
        const SizedBox(width: 10),
        pill(Icons.star_rounded, UiStyle.gold, '$stars / $maxStars'),
      ],
    );
  }
}
