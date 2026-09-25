import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/siege_game.dart';
import 'ui/overlays/hud.dart';
import 'ui/overlays/main_menu.dart';
import 'ui/overlays/result_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const SiegeApp());
}

class SiegeApp extends StatefulWidget {
  const SiegeApp({super.key});

  @override
  State<SiegeApp> createState() => _SiegeAppState();
}

class _SiegeAppState extends State<SiegeApp> {
  final _game = SiegeGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Last Siege',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GameWidget<SiegeGame>(
          game: _game,
          initialActiveOverlays: const ['menu'],
          overlayBuilderMap: {
            'menu': (_, game) => MainMenu(game: game),
            'hud': (_, game) => Hud(game: game),
            'result': (_, game) => ResultPanel(game: game),
          },
        ),
      ),
    );
  }
}
