import 'package:flutter/material.dart';

import '../../game/siege_game.dart';
import '../ui_style.dart';

class MainMenu extends StatelessWidget {
  const MainMenu({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('THE LAST SIEGE', style: UiStyle.title),
            const SizedBox(height: 4),
            Text(
              'Era I: Egypt',
              style: UiStyle.body.copyWith(color: UiStyle.bronze),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              children: [
                SiegeButton(
                  label: 'Campaign',
                  icon: Icons.map_outlined,
                  onPressed: game.showMap,
                ),
                SiegeButton(
                  label: 'Siege Camp',
                  icon: Icons.fort,
                  onPressed: game.showCamp,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: game.themeIndex,
              builder: (_, index, _) => TextButton.icon(
                onPressed: game.cycleArtStyle,
                icon: const Icon(Icons.palette_outlined, color: UiStyle.bronze),
                label: Text(
                  'Art style: ${index == 0 ? 'Painted realistic' : 'Stylized'}',
                  style: UiStyle.body.copyWith(color: UiStyle.bronze),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
