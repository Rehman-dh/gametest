// Renders every campaign level to a PNG for visual review:
//   flutter test test/tool/render_levels_test.dart --tags tool --run-skipped \
//     --dart-define=out=/some/dir
@Tags(['tool'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/game/siege_game.dart';
import 'package:gametest/theme/cartoon_theme.dart';

void main() {
  const out = String.fromEnvironment('out', defaultValue: 'build/levels');
  // A landscape phone screen, in logical pixels, drawn at 2x.
  final size = Vector2(874, 402);
  const scale = 2.0;

  testWidgets('render levels', (tester) async {
    await tester.runAsync(() async {
      Directory(out).createSync(recursive: true);
      final theme = await CartoonTheme.load();
      for (var i = 0; i < SiegeGame.levelFiles.length; i++) {
        final game = SiegeGame(theme: theme, audioEnabled: false);
        for (final name in ['menu', 'hud', 'result', 'cutscene']) {
          game.overlays.addEntry(name, (_, _) => const SizedBox());
        }
        game.onGameResize(size);
        // ignore: invalid_use_of_internal_member
        await game.load();
        // ignore: invalid_use_of_internal_member
        game.mount();
        await game.startLevel(i);
        // Let bodies load and settle.
        for (var f = 0; f < 90; f++) {
          game.update(1 / 60);
          await game.ready();
        }
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder)..scale(scale);
        game.render(canvas);
        final image = await recorder.endRecording().toImage(
          (size.x * scale).round(),
          (size.y * scale).round(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$out/${SiegeGame.levelFiles[i].split('/').last}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        game.onRemove();
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
