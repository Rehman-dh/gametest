import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../../meta/catalog.dart';
import '../ui_style.dart';

/// The end of a siege: a ribbon, stars that pop in one by one, the score
/// counting up, rewards, and where to go next.
class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    final result = game.lastResult!;
    if (result.endless != null) return _endless(result, result.endless!);
    return _Frame(
      ribbon: RibbonTitle(
        result.won ? 'VICTORY!' : 'DEFEAT',
        color: result.won ? const Color(0xFF4FB33A) : UiStyle.blood,
      ),
      content: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                // The middle star sits higher, like a crown.
                padding: EdgeInsets.only(bottom: i == 1 ? 12 : 0),
                child: _Star(
                  earned: i < result.stars,
                  size: i == 1 ? 64 : 52,
                  delay: Duration(milliseconds: 350 + 280 * i),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _CountUp(value: game.score.value),
        if (result.defeat != null)
          Text(switch (result.defeat!) {
            DefeatReason.outOfAmmo => 'Your ammunition ran out.',
            DefeatReason.engineDestroyed => 'Your siege engine was destroyed.',
          }, style: UiStyle.body.copyWith(color: UiStyle.blood)),
        Text(
          'Castle destroyed: ${(result.destruction * 100).round()}%',
          style: UiStyle.body,
        ),
        ..._rewardLines(result),
      ],
      buttons: [
        CartoonButton(
          icon: Icons.map_rounded,
          tone: ButtonTone.orange,
          size: 1.2,
          onPressed: () => game.leaveResult(next: false),
        ),
        CartoonButton(
          icon: Icons.replay_rounded,
          tone: ButtonTone.blue,
          size: 1.2,
          onPressed: () => game.showPrep(game.levelIndex),
        ),
        if (result.won && game.hasNextLevel)
          CartoonButton(
            label: 'Next',
            icon: Icons.play_arrow_rounded,
            size: 1.2,
            onPressed: () => game.leaveResult(next: true),
          ),
      ],
    );
  }

  List<Widget> _rewardLines(LevelResult result) {
    final reward = result.reward;
    final lines = <(IconData, Color, String)>[
      if (reward.gold > 0)
        (Icons.monetization_on, UiStyle.gold, '+${reward.gold} gold'),
      if (reward.relic != null)
        (
          Icons.diamond,
          const Color(0xFF7FD3F7),
          'Relic found: ${relicSpecs[reward.relic]!.name}',
        ),
      if (reward.crew != null)
        (
          Icons.person_add_alt_1,
          UiStyle.leaf,
          '${crewSpecs[reward.crew]!.name} the '
              '${crewSpecs[reward.crew]!.role} joins you',
        ),
      for (final id in reward.crewLevelUps)
        (Icons.upgrade, UiStyle.leaf, '${crewSpecs[id]!.name} grows stronger'),
    ];
    return [
      for (final (i, (icon, color, text)) in lines.indexed)
        PopIn(
          delay: Duration(milliseconds: 1300 + 150 * i),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                  shadows: const [
                    Shadow(color: UiStyle.ink, offset: Offset(0, 1.5)),
                  ],
                ),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: UiStyle.body.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _endless(LevelResult result, EndlessOutcome outcome) {
    final title = outcome.runOver
        ? 'THE RUN ENDS'
        : '${game.level.name.toUpperCase()} TAKEN';
    final lines = outcome.runOver
        ? [
            'Castles taken: ${outcome.castles}',
            if (outcome.newBest) 'A new best!',
            if (outcome.gold > 0) '+${outcome.gold} gold for the war chest',
          ]
        : ['+${outcome.points} points', 'Your ammunition and damage carry on.'];
    return _Frame(
      ribbon: RibbonTitle(
        title,
        color: outcome.runOver ? UiStyle.blood : const Color(0xFF4FB33A),
      ),
      content: [
        _CountUp(value: outcome.score),
        for (final line in lines)
          Text(line, style: UiStyle.body.copyWith(fontWeight: FontWeight.w800)),
      ],
      buttons: outcome.runOver
          ? [
              CartoonButton(
                icon: Icons.map_rounded,
                tone: ButtonTone.orange,
                size: 1.2,
                onPressed: game.showMap,
              ),
              CartoonButton(
                label: 'New run',
                icon: Icons.replay_rounded,
                size: 1.2,
                onPressed: game.startEndless,
              ),
            ]
          : [
              CartoonButton(
                label: 'End run',
                icon: Icons.flag_rounded,
                tone: ButtonTone.red,
                size: 1.2,
                onPressed: game.endEndlessRun,
              ),
              CartoonButton(
                label: 'Next castle',
                icon: Icons.play_arrow_rounded,
                size: 1.2,
                onPressed: game.continueEndless,
              ),
            ],
    );
  }
}

/// The dimmed backdrop and the card, with the ribbon riding its top edge
/// and the buttons hanging from its bottom.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.ribbon,
    required this.content,
    required this.buttons,
  });

  final Widget ribbon;
  final List<Widget> content;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x66000000),
      child: Center(
        child: PopIn(
          from: const Offset(0, 0.3),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 400,
                margin: const EdgeInsets.only(top: 24, bottom: 30),
                padding: const EdgeInsets.fromLTRB(20, 38, 20, 44),
                decoration: UiStyle.panelDecoration,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: content,
                ),
              ),
              ribbon,
              Positioned(
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, b) in buttons.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      PopIn(
                        delay: Duration(milliseconds: 1100 + 120 * i),
                        child: b,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A star that slams in with a spin when earned, or sits dim when not.
class _Star extends StatefulWidget {
  const _Star({required this.earned, required this.size, required this.delay});

  final bool earned;
  final double size;
  final Duration delay;

  @override
  State<_Star> createState() => _StarState();
}

class _StarState extends State<_Star> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.earned) {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _icon(Color color, double size) => Icon(
    Icons.star_rounded,
    size: size,
    color: color,
    shadows: const [Shadow(color: UiStyle.ink, blurRadius: 0.5)],
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s + 8,
      height: s + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outline, then the empty socket.
          _icon(UiStyle.ink, s + 8),
          _icon(const Color(0xFFCDB88E), s),
          if (widget.earned)
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) {
                final t = Curves.elasticOut.transform(_c.value);
                return Opacity(
                  opacity: _c.value.clamp(0, 1),
                  child: Transform.rotate(
                    angle: (1 - _c.value) * 1.2,
                    child: Transform.scale(
                      scale: 0.2 + 0.8 * t + (1 - _c.value) * 0.8,
                      child: child,
                    ),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _icon(UiStyle.ink, s + 8),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFF4B0), Color(0xFFFFC933)],
                    ).createShader(b),
                    child: _icon(Colors.white, s),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The score, counting up from zero.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) =>
          OutlinedText('SCORE  ${v.round()}', size: 26, color: UiStyle.gold),
    );
  }
}
