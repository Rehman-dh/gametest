import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../ui_style.dart';

class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    final result = game.lastResult!;
    return ColoredBox(
      color: const Color(0x88000000),
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: UiStyle.panelDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.won ? 'THE CASTLE HAS FALLEN' : 'THE SIEGE HAS FAILED',
                style: UiStyle.heading.copyWith(
                  color: result.won ? UiStyle.parchment : UiStyle.blood,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < result.stars ? Icons.star : Icons.star_border,
                      color: UiStyle.bronze,
                      size: 44,
                    ),
                ],
              ),
              if (result.defeat != null) ...[
                const SizedBox(height: 4),
                Text(switch (result.defeat!) {
                  DefeatReason.outOfAmmo => 'Your ammunition ran out.',
                  DefeatReason.engineDestroyed =>
                    'Your siege engine was destroyed.',
                }, style: UiStyle.body.copyWith(color: UiStyle.bronze)),
              ],
              const SizedBox(height: 8),
              Text(
                'Castle destroyed: ${(result.destruction * 100).round()}%',
                style: UiStyle.body,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: [
                  SiegeButton(
                    label: 'Menu',
                    icon: Icons.menu,
                    onPressed: game.showMenu,
                  ),
                  SiegeButton(
                    label: 'Retry',
                    icon: Icons.replay,
                    onPressed: () => game.startLevel(game.levelIndex),
                  ),
                  if (result.won && game.hasNextLevel)
                    SiegeButton(
                      label: 'Next',
                      icon: Icons.arrow_forward,
                      onPressed: () => game.startLevel(game.levelIndex + 1),
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
