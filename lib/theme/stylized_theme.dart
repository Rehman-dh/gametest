import 'dart:math' as math;
import 'dart:ui';

import '../core/materials.dart';
import '../levels/level_data.dart';
import 'art_theme.dart';

/// Procedurally drawn stylized look with a serious dusk mood:
/// muted palette, strong silhouettes, dark outlines. No image assets yet.
class StylizedTheme implements ArtTheme {
  static const _outline = Color(0xFF1A140F);
  static const _stroke = 0.07;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _stroke
    ..strokeJoin = StrokeJoin.round
    ..color = _outline;

  // ---------------------------------------------------------------- scenery

  @override
  void drawBackground(Canvas canvas, Rect visible) {
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset(0, visible.top),
        Offset(0, 2),
        const [Color(0xFF16202C), Color(0xFF4A3B45), Color(0xFFB8704A)],
        const [0, 0.6, 1],
      );
    canvas.drawRect(visible, sky);

    // Low setting sun behind the castle.
    final sunCenter = Offset(visible.center.dx + 14, -7);
    canvas.drawCircle(
      sunCenter,
      9,
      Paint()
        ..shader = Gradient.radial(sunCenter, 9, const [
          Color(0x66F2B279),
          Color(0x00F2B279),
        ]),
    );
    canvas.drawCircle(sunCenter, 2.2, Paint()..color = const Color(0xFFE8A06A));

    // Parallax silhouettes: the farther the layer, the less it scrolls.
    _ridge(canvas, visible, 0.15, -9, 5, 0.07, const Color(0xFF3A3A48), 11);
    _ridge(canvas, visible, 0.35, -5, 3.5, 0.13, const Color(0xFF2C2C34), 23);
    _ridge(canvas, visible, 0.6, -2, 2, 0.21, const Color(0xFF201F22), 37);
  }

  void _ridge(
    Canvas canvas,
    Rect visible,
    double parallax,
    double baseY,
    double amp,
    double freq,
    Color color,
    int seed,
  ) {
    final shift = visible.center.dx * parallax;
    final path = Path()..moveTo(visible.left, 1);
    for (var x = visible.left; x <= visible.right + 1; x += 0.8) {
      final u = (x - shift) * freq + seed;
      final y =
          baseY -
          amp *
              (0.6 * math.sin(u) +
                  0.3 * math.sin(u * 2.3 + 1.7) +
                  0.1 * math.sin(u * 5.1));
      path.lineTo(x, y);
    }
    path
      ..lineTo(visible.right + 1, 1)
      ..close();
    canvas.drawPath(path, _fill..color = color);
  }

  @override
  void drawGround(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, _fill..color = const Color(0xFF3B2E22));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width, 0.45),
      _fill..color = const Color(0xFF6E5A3E),
    );
    canvas.drawLine(rect.topLeft, rect.topRight, _line);
  }

  // ---------------------------------------------------------------- blocks

  @override
  void drawBlock(
    Canvas canvas,
    Size size,
    BlockMaterial material, {
    required int crackStage,
    required int seed,
  }) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(0.08));

    switch (material) {
      case BlockMaterial.wood:
        canvas.drawRRect(rrect, _fill..color = const Color(0xFF7A4E2D));
        final grain = Paint()
          ..color = const Color(0xFF5A3620)
          ..strokeWidth = 0.05;
        final horizontal = size.width >= size.height;
        const spacing = 0.33;
        final extent = horizontal ? size.height : size.width;
        for (var d = -extent / 2 + spacing; d < extent / 2; d += spacing) {
          if (horizontal) {
            canvas.drawLine(
              Offset(rect.left + 0.1, d),
              Offset(rect.right - 0.1, d),
              grain,
            );
          } else {
            canvas.drawLine(
              Offset(d, rect.top + 0.1),
              Offset(d, rect.bottom - 0.1),
              grain,
            );
          }
        }
      case BlockMaterial.stone:
        canvas.drawRRect(rrect, _fill..color = const Color(0xFF7D7A72));
        final mortar = Paint()
          ..color = const Color(0xFF55524C)
          ..strokeWidth = 0.05;
        const course = 0.5;
        var row = 0;
        for (var y = rect.top + course; y < rect.bottom - 0.05; y += course) {
          canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), mortar);
        }
        for (var y = rect.top; y < rect.bottom - 0.05; y += course, row++) {
          final offset = row.isEven ? 0.0 : 0.5;
          for (var x = rect.left + 0.5 + offset; x < rect.right; x += 1.0) {
            canvas.drawLine(
              Offset(x, y),
              Offset(x, math.min(y + course, rect.bottom)),
              mortar,
            );
          }
        }
      case BlockMaterial.glass:
        canvas.drawRRect(rrect, _fill..color = const Color(0x8C8FC3CF));
        canvas.drawLine(
          Offset(rect.left + 0.15, rect.bottom - 0.15),
          Offset(
            rect.left + math.min(size.width, size.height) * 0.6,
            rect.top + 0.15,
          ),
          Paint()
            ..color = const Color(0x99FFFFFF)
            ..strokeWidth = 0.06,
        );
    }

    if (crackStage > 0) _drawCracks(canvas, rect, crackStage, seed);
    canvas.drawRRect(rrect, _line);
  }

  void _drawCracks(Canvas canvas, Rect rect, int stage, int seed) {
    final rng = math.Random(seed);
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05
      ..color = const Color(0xDD120D0A);
    for (var i = 0; i < stage * 2; i++) {
      var p = Offset(
        rect.left + rng.nextDouble() * rect.width,
        rect.top + rng.nextDouble() * rect.height,
      );
      final path = Path()..moveTo(p.dx, p.dy);
      for (var s = 0; s < 3 + stage; s++) {
        p += Offset(rng.nextDouble() - 0.5, rng.nextDouble() - 0.5) * 0.6;
        p = Offset(
          p.dx.clamp(rect.left, rect.right),
          p.dy.clamp(rect.top, rect.bottom),
        );
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, crack);
    }
  }

  // ----------------------------------------------------------------- units

  @override
  void drawUnit(
    Canvas canvas,
    double radius,
    UnitKind kind, {
    required bool hurt,
  }) {
    final isKing = kind == UnitKind.king;
    final body = hurt
        ? const Color(0xFFA33A2E)
        : (isKing ? const Color(0xFF4B2A55) : const Color(0xFF7B6A4A));

    canvas.drawCircle(Offset.zero, radius, _fill..color = body);
    // Cloak/armor band.
    canvas.drawRect(
      Rect.fromLTWH(-radius, radius * 0.1, radius * 2, radius * 0.25),
      _fill..color = isKing ? const Color(0xFFB08A2E) : const Color(0xFF4F4636),
    );
    // Helmet visor / face shadow: a dark slit, no cartoon faces.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -radius * 0.55,
          -radius * 0.35,
          radius * 1.1,
          radius * 0.22,
        ),
        Radius.circular(radius * 0.1),
      ),
      _fill..color = const Color(0xFF15100C),
    );
    canvas.drawCircle(Offset.zero, radius, _line);

    if (isKing) {
      final top = -radius * 0.85;
      final crown = Path()
        ..moveTo(-radius * 0.6, top)
        ..lineTo(-radius * 0.6, top - radius * 0.55)
        ..lineTo(-radius * 0.3, top - radius * 0.25)
        ..lineTo(0, top - radius * 0.7)
        ..lineTo(radius * 0.3, top - radius * 0.25)
        ..lineTo(radius * 0.6, top - radius * 0.55)
        ..lineTo(radius * 0.6, top)
        ..close();
      canvas
        ..drawPath(crown, _fill..color = const Color(0xFFD4A437))
        ..drawPath(crown, _line);
    } else {
      // Spear tip over the shoulder.
      canvas.drawLine(
        Offset(radius * 0.7, radius * 0.4),
        Offset(radius * 1.1, -radius * 1.4),
        _line,
      );
    }
  }

  @override
  void drawStone(Canvas canvas, double radius) {
    final path = Path();
    const sides = 9;
    for (var i = 0; i < sides; i++) {
      final a = i / sides * math.pi * 2;
      final r = radius * (0.9 + 0.1 * math.sin(i * 2.7));
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas
      ..drawPath(path, _fill..color = const Color(0xFF6B6760))
      ..drawCircle(
        Offset(-radius * 0.3, -radius * 0.3),
        radius * 0.25,
        _fill..color = const Color(0xFF8E8A81),
      )
      ..drawPath(path, _line);
  }

  // -------------------------------------------------------------- catapult

  @override
  void drawCatapult(Canvas canvas, {required double armAngle}) {
    final wood = _fill..color = const Color(0xFF5E3D24);
    const beam = Color(0xFF4A2F1B);

    // Base frame and wheels.
    final base = Rect.fromLTWH(-2.2, -1.2, 4.4, 0.6);
    canvas
      ..drawRect(base, wood)
      ..drawRect(base, _line);
    for (final x in [-1.5, 1.5]) {
      canvas
        ..drawCircle(Offset(x, -0.55), 0.55, _fill..color = beam)
        ..drawCircle(Offset(x, -0.55), 0.55, _line)
        ..drawCircle(Offset(x, -0.55), 0.12, _fill..color = _outline);
    }

    // A-frame uprights.
    final upright = Path()
      ..moveTo(-1.2, -1.2)
      ..lineTo(0, -3.0)
      ..lineTo(1.2, -1.2);
    canvas.drawPath(
      upright,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35
        ..color = beam,
    );

    // Throwing arm rotating around the pivot.
    canvas
      ..save()
      ..translate(0, -2.8)
      ..rotate(armAngle);
    final arm = Rect.fromLTWH(-0.15, -3.2, 0.3, 3.8);
    canvas
      ..drawRect(arm, _fill..color = const Color(0xFF6E4A2C))
      ..drawRect(arm, _line);
    // Bucket at the arm's tip.
    final bucket = Rect.fromCenter(
      center: const Offset(0, -3.3),
      width: 0.9,
      height: 0.45,
    );
    canvas
      ..drawRect(bucket, _fill..color = beam)
      ..drawRect(bucket, _line)
      ..restore();

    // Pivot pin.
    canvas.drawCircle(const Offset(0, -2.8), 0.18, _fill..color = _outline);
  }

  @override
  void drawTrajectoryDot(Canvas canvas, Offset center, double opacity) {
    canvas.drawCircle(
      center,
      0.14,
      _fill..color = Color.fromRGBO(240, 220, 180, opacity),
    );
  }

  @override
  void drawAimBand(Canvas canvas, Offset from, Offset to, double power) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFD9C29A),
          const Color(0xFFC0392B),
          power,
        )!
        ..strokeWidth = 0.12
        ..strokeCap = StrokeCap.round,
    );
  }
}
