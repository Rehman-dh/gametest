import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/siege_game.dart';
import 'meta/campaign.dart';
import 'meta/save_repository.dart';
import 'theme/realistic_theme.dart';
import 'ui/overlays/cutscene_overlay.dart';
import 'ui/overlays/hud.dart';
import 'ui/overlays/main_menu.dart';
import 'ui/overlays/result_panel.dart';
import 'ui/overlays/siege_camp.dart';
import 'ui/overlays/siege_prep.dart';
import 'ui/overlays/world_map.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final realistic = await RealisticTheme.load();
  final campaign = Campaign(
    levelFiles: SiegeGame.levelFiles,
    repository: SaveRepository(),
  );
  await campaign.load();
  runApp(
    SiegeApp(
      game: SiegeGame(
        theme: realistic,
        campaign: campaign,
        attractOnLaunch: true,
      ),
    ),
  );
}

class SiegeApp extends StatelessWidget {
  const SiegeApp({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Last Siege',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GameWidget<SiegeGame>(
          game: game,
          initialActiveOverlays: const ['menu'],
          overlayBuilderMap: {
            'menu': (_, game) => MainMenu(game: game),
            'hud': (_, game) => Hud(game: game),
            'result': (_, game) => ResultPanel(game: game),
            'map': (_, game) => WorldMap(game: game),
            'prep': (_, game) => SiegePrep(game: game),
            'camp': (_, game) => SiegeCamp(game: game),
            'cutscene': (_, game) => CutsceneOverlay(game: game),
          },
        ),
      ),
    );
  }
}
