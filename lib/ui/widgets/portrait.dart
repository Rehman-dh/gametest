import 'package:flutter/material.dart';

import '../../story/characters.dart';
import '../../theme/art_theme.dart';
import '../ui_style.dart';

/// Head-and-shoulders portrait of a story character, drawn by the theme.
class Portrait extends StatelessWidget {
  const Portrait({
    super.key,
    required this.look,
    required this.theme,
    this.size = 64,
  });

  final CharacterLook look;
  final ArtTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.2;
    // The ink frame is painted over the picture, so the portrait keeps its
    // stated size.
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: UiStyle.ink, width: size >= 56 ? 3 : 2.5),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CustomPaint(painter: _PortraitPainter(look, theme)),
        ),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.look, this.theme);

  final CharacterLook look;
  final ArtTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 0.9,
          colors: [Color(0xFFD9F1FC), Color(0xFF7FC6EC)],
        ).createShader(Offset.zero & size),
    );
    // Frame head and shoulders: about 0.6 m of the figure fills the square,
    // with the head a little above centre.
    final scale = size.height / 0.6;
    final headY = 1.62 * look.height / 1.8;
    canvas
      ..save()
      ..translate(size.width * 0.5, size.height * 0.4)
      ..scale(scale)
      ..translate(-0.03, headY);
    theme.drawCharacter(canvas, look, pose: Pose.stand, time: 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.look != look || old.theme != theme;
}
