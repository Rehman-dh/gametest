import 'package:flutter/material.dart';

import '../../core/ammo.dart';
import '../../theme/art_theme.dart';

/// Draws a round of [type] with the active art theme, so icons match the
/// world.
class AmmoIcon extends StatelessWidget {
  const AmmoIcon({
    super.key,
    required this.type,
    required this.theme,
    this.size = 40,
  });

  final AmmoType type;
  final ArtTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _AmmoIconPainter(theme: theme, type: type),
    ),
  );
}

class _AmmoIconPainter extends CustomPainter {
  _AmmoIconPainter({required this.theme, required this.type});

  final ArtTheme theme;
  final AmmoType type;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = type.spec.radius;
    // Bolts are long and thin; everything else is round.
    final extent = type == AmmoType.bolt ? radius * 10 : radius * 2.6;
    final scale = size.shortestSide / extent;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale);
    if (type == AmmoType.bolt) canvas.rotate(-0.6);
    theme.drawProjectile(canvas, type, radius, 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AmmoIconPainter old) =>
      old.theme != theme || old.type != type;
}
