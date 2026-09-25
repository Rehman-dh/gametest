import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../ui_style.dart';

class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
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
                  ValueListenableBuilder<int>(
                    valueListenable: game.shotsLeft,
                    builder: (_, shots, _) => Row(
                      children: [
                        for (var i = 0; i < game.level.shots; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.circle,
                              size: 14,
                              color: i < shots
                                  ? UiStyle.parchment
                                  : UiStyle.parchment.withValues(alpha: 0.2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _IconAction(
              icon: Icons.replay,
              onTap: () => game.startLevel(game.levelIndex),
            ),
            const SizedBox(width: 8),
            _IconAction(icon: Icons.menu, onTap: game.showMenu),
          ],
        ),
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
