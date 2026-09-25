import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../core/ammo.dart';
import '../core/materials.dart';
import '../core/weapons.dart';
import '../levels/level_data.dart';
import '../story/characters.dart';
import 'art_theme.dart';

/// Everything drawn in code: the foundation the realistic theme builds on
/// (particles, fire, characters, siege engines and anything without a
/// texture yet), and a light theme for headless tests that need no image
/// assets. It is not offered to players as a style of its own.
class ProceduralTheme implements ArtTheme {
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
  void drawBackground(
    Canvas canvas,
    Rect visible,
    double time, {
    Color? atmosphere,
  }) {
    final sky = Paint()
      ..shader = Gradient.linear(
        Offset(0, visible.top),
        Offset(0, 2),
        const [Color(0xFF111A26), Color(0xFF473845), Color(0xFFB8704A)],
        const [0, 0.62, 1],
      );
    canvas.drawRect(visible, sky);

    _stars(canvas, visible);

    // Low setting sun behind the castle.
    final sunCenter = Offset(visible.center.dx * 0.9 + 18, -7);
    canvas.drawCircle(
      sunCenter,
      11,
      Paint()
        ..shader = Gradient.radial(sunCenter, 11, const [
          Color(0x70F2B279),
          Color(0x00F2B279),
        ]),
    );
    canvas.drawCircle(sunCenter, 2.2, _fill..color = const Color(0xFFE8A06A));

    _clouds(canvas, visible, time);

    // Parallax layers, far to near: the farther, the less it scrolls.
    _pyramids(canvas, visible, 0.1);
    _ridge(canvas, visible, 0.15, -6, 3, 0.07, const Color(0xFF3A3645), 11);
    _ridge(canvas, visible, 0.35, -3.5, 2.2, 0.13, const Color(0xFF2B2830), 23);
    _ridge(canvas, visible, 0.6, -1.2, 1.2, 0.21, const Color(0xFF1F1C1E), 37);
    _dustMotes(canvas, visible, time);
  }

  void _stars(Canvas canvas, Rect visible) {
    final rng = math.Random(99);
    final paint = Paint();
    for (var i = 0; i < 40; i++) {
      final x = visible.left + rng.nextDouble() * visible.width;
      final y = visible.top + rng.nextDouble() * visible.height * 0.35;
      paint.color = Color.fromRGBO(
        230,
        220,
        200,
        0.15 + rng.nextDouble() * 0.35,
      );
      canvas.drawCircle(Offset(x, y), 0.04 + rng.nextDouble() * 0.05, paint);
    }
  }

  final Paint _cloudBody = Paint()
    ..color = const Color(0x4A2A2433)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);
  final Paint _cloudLit = Paint()
    ..color = const Color(0x2EC98A64)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5);

  void _clouds(Canvas canvas, Rect visible, double time) {
    const parallax = 0.08, drift = 0.35, wrap = 150.0;
    final shift = visible.center.dx * parallax + time * drift;
    final rng = math.Random(5);
    for (var i = 0; i < 6; i++) {
      final baseX = rng.nextDouble() * wrap;
      final y = visible.top + 3 + rng.nextDouble() * visible.height * 0.28;
      final w = 9 + rng.nextDouble() * 10;
      // Wrap clouds around so they drift forever.
      final x = visible.left - 30 + ((baseX + shift) % wrap);
      // One merged path per cloud so overlapping lobes don't stack alpha.
      final path = Path();
      for (var k = 0; k < 5; k++) {
        final lobeW = w * (0.3 + rng.nextDouble() * 0.25);
        final lobeH = 0.9 + rng.nextDouble() * 1.1;
        path.addOval(
          Rect.fromCenter(
            center: Offset(x + (k / 4 - 0.5) * w * 0.7, y - lobeH * 0.3),
            width: lobeW,
            height: lobeH,
          ),
        );
      }
      canvas
        ..drawPath(path.shift(const Offset(0, 0.35)), _cloudLit)
        ..drawPath(path, _cloudBody);
    }
  }

  void _pyramids(Canvas canvas, Rect visible, double parallax) {
    final shift = visible.center.dx * parallax;
    final paint = Paint()..color = const Color(0xFF4A3F4A);
    final shade = Paint()..color = const Color(0xFF3D3440);
    for (final (x, h) in const [
      (8.0, 9.0),
      (19.0, 6.0),
      (27.0, 4.0),
      (70.0, 7.0),
    ]) {
      final cx = x + shift;
      const base = -3.0;
      final path = Path()
        ..moveTo(cx - h * 1.1, base)
        ..lineTo(cx, base - h)
        ..lineTo(cx + h * 1.1, base)
        ..close();
      final shadowSide = Path()
        ..moveTo(cx, base - h)
        ..lineTo(cx + h * 1.1, base)
        ..lineTo(cx + h * 0.2, base)
        ..close();
      canvas
        ..drawPath(path, paint)
        ..drawPath(shadowSide, shade);
    }
  }

  void _dustMotes(Canvas canvas, Rect visible, double time) {
    final rng = math.Random(17);
    final paint = Paint();
    for (var i = 0; i < 36; i++) {
      final speed = 0.3 + rng.nextDouble() * 0.6;
      final x =
          visible.left +
          ((rng.nextDouble() * visible.width + time * speed) % visible.width);
      final y =
          visible.bottom -
          2 -
          rng.nextDouble() * visible.height * 0.7 +
          math.sin(time * 0.8 + i) * 0.4;
      paint.color = Color.fromRGBO(235, 190, 140, 0.1 + rng.nextDouble() * 0.2);
      canvas.drawCircle(Offset(x, y), 0.05 + rng.nextDouble() * 0.06, paint);
    }
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

  @override
  void drawGroundDetail(Canvas canvas, Rect visible) {
    // World-fixed pebbles and tufts sitting on the surface.
    final rng = math.Random(3);
    final pebble = Paint()..color = const Color(0xFF524230);
    final tuft = Paint()
      ..color = const Color(0xFF5E5236)
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round;
    for (
      var x = visible.left.floorToDouble() - 1;
      x < visible.right + 1;
      x += 1
    ) {
      // Deterministic per-meter scatter so details don't swim on scroll.
      final cell = math.Random(x.toInt() * 7919 + 13);
      if (cell.nextDouble() < 0.5) {
        final px = x + cell.nextDouble();
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, 0.05),
            width: 0.2 + cell.nextDouble() * 0.3,
            height: 0.12 + cell.nextDouble() * 0.1,
          ),
          pebble,
        );
      }
      if (cell.nextDouble() < 0.35) {
        final px = x + cell.nextDouble();
        for (var k = -1; k <= 1; k++) {
          canvas.drawLine(
            Offset(px, 0.02),
            Offset(px + k * 0.12, -0.18 - cell.nextDouble() * 0.12),
            tuft,
          );
        }
      }
    }
    // Faster-scrolling strata inside the ground slab for depth.
    final strata = Paint()..color = const Color(0x332A1F16);
    final shift = visible.center.dx * -0.12;
    for (var i = 0; i < 12; i++) {
      final x =
          visible.left +
          ((rng.nextDouble() * 90 + shift) % (visible.width + 20)) -
          10;
      final y = 1.2 + rng.nextDouble() * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 3 + rng.nextDouble() * 5,
          height: 0.35,
        ),
        strata,
      );
    }
  }

  @override
  void drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          rect.center,
          size.longestSide * 0.62,
          const [Color(0x00000000), Color(0x00000000), Color(0x8C05030A)],
          const [0, 0.55, 1],
        ),
    );
  }

  // ---------------------------------------------------------------- blocks

  @override
  void drawBlock(
    Canvas canvas,
    Size size,
    BlockMaterial material, {
    required int crackStage,
    required int seed,
    bool weak = false,
    double char = 0,
    String? look,
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

    if (weak) drawRot(canvas, rrect, seed);
    if (char > 0) drawChar(canvas, rrect, char);
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

  @override
  void drawShard(
    Canvas canvas,
    List<Offset> polygon,
    BlockMaterial material, {
    String? look,
    int crackStage = 0,
    Offset offset = Offset.zero,
    Size? blockSize,
  }) {
    final path = Path()..addPolygon(polygon, true);
    canvas
      ..drawPath(path, _fill..color = _materialColor(material))
      ..drawPath(path, _line);
  }

  static Color _materialColor(BlockMaterial material) => switch (material) {
    BlockMaterial.wood => const Color(0xFF7A4E2D),
    BlockMaterial.stone => const Color(0xFF7D7A72),
    BlockMaterial.glass => const Color(0x8C8FC3CF),
  };

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
        : switch (kind) {
            UnitKind.king || UnitKind.pharaoh => const Color(0xFF4B2A55),
            UnitKind.soldier => const Color(0xFF7B6A4A),
            UnitKind.archer => const Color(0xFF55603A),
            UnitKind.engineer => const Color(0xFF6B4A2E),
          };

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
    } else if (kind == UnitKind.archer) {
      // Bow held out toward the player.
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(-radius * 0.9, 0),
          width: radius * 0.9,
          height: radius * 2.4,
        ),
        math.pi / 2,
        math.pi,
        false,
        _line,
      );
    } else if (kind == UnitKind.engineer) {
      // Hammer over the shoulder.
      canvas
        ..drawLine(
          Offset(radius * 0.6, radius * 0.3),
          Offset(radius * 0.9, -radius * 1.2),
          _line,
        )
        ..drawRect(
          Rect.fromCenter(
            center: Offset(radius * 0.92, -radius * 1.25),
            width: radius * 0.6,
            height: radius * 0.28,
          ),
          _fill..color = const Color(0xFF55595E),
        );
    } else {
      // Spear tip over the shoulder.
      canvas.drawLine(
        Offset(radius * 0.7, radius * 0.4),
        Offset(radius * 1.1, -radius * 1.4),
        _line,
      );
    }
  }

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

  // ---------------------------------------------------- phase 3 visuals

  /// Rotten patches marking a weak point: subtle, so sharp eyes spot it.
  void drawRot(Canvas canvas, RRect rrect, int seed) {
    final rng = math.Random(seed * 31 + 7);
    final r = rrect.outerRect;
    final rot = Paint()
      ..color = const Color(0x5A2E3A1A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.12);
    canvas
      ..save()
      ..clipRRect(rrect);
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            r.left + rng.nextDouble() * r.width,
            r.top + rng.nextDouble() * r.height,
          ),
          width: 0.3 + rng.nextDouble() * 0.5,
          height: 0.2 + rng.nextDouble() * 0.4,
        ),
        rot,
      );
    }
    canvas.restore();
  }

  /// Scorching from fire; [amount] 0–1.
  void drawChar(Canvas canvas, RRect rrect, double amount) {
    canvas.drawRRect(
      rrect,
      Paint()..color = Color.fromRGBO(20, 12, 8, 0.75 * amount.clamp(0, 1)),
    );
  }

  @override
  void drawFire(Canvas canvas, Size size, double time) {
    final w = size.width, h = size.height;
    final glowR = math.max(w, h) * 0.9 + 0.6;
    canvas.drawCircle(
      Offset.zero,
      glowR,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(Offset.zero, glowR, const [
          Color(0x55FF8A2A),
          Color(0x00FF8A2A),
        ]),
    );
    // Tongues of flame along the block, flickering out of phase.
    final tongues = math.max(2, (w / 0.45).round());
    for (var i = 0; i < tongues; i++) {
      final x = -w / 2 + (i + 0.5) * w / tongues;
      final phase = time * 9 + i * 1.7;
      final height =
          (0.5 + 0.3 * math.sin(phase) + 0.15 * math.sin(phase * 2.3)) *
          (0.6 + 0.4 * math.min(1.0, h));
      final base = h / 2 * 0.2;
      final sway = 0.08 * math.sin(phase * 0.7);
      final flame = Path()
        ..moveTo(x - 0.2, base)
        ..quadraticBezierTo(
          x - 0.22,
          base - height * 0.6,
          x + sway,
          base - height,
        )
        ..quadraticBezierTo(x + 0.22, base - height * 0.6, x + 0.2, base)
        ..close();
      canvas.drawPath(
        flame,
        Paint()
          ..shader = Gradient.linear(
            Offset(x, base),
            Offset(x, base - height),
            const [Color(0xEEFFD36B), Color(0xCCFF7A1F), Color(0x00C0301A)],
            const [0, 0.5, 1],
          ),
      );
    }
  }

  @override
  void drawWeakPointMarker(Canvas canvas, Size size, double time) {
    final pulse = 0.5 + 0.5 * math.sin(time * 5);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width + 0.3,
      height: size.height + 0.3,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(0.15));
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.35
          ..color = Color.fromRGBO(255, 200, 90, 0.25 + 0.25 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.2),
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.07
          ..color = Color.fromRGBO(255, 220, 130, 0.6 + 0.4 * pulse),
      );
  }

  @override
  void drawBarrel(Canvas canvas, Size size, {required int crackStage}) {
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final body = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.width * 0.3),
    );
    canvas.drawRRect(body, _fill..color = const Color(0xFF6B4527));
    final hoop = Paint()
      ..color = const Color(0xFF2E2A26)
      ..strokeWidth = 0.08;
    for (final y in [-0.32, 0.32]) {
      canvas.drawLine(
        Offset(rect.left + 0.05, y * size.height),
        Offset(rect.right - 0.05, y * size.height),
        hoop,
      );
    }
    // Stencilled warning mark.
    canvas.drawCircle(
      Offset.zero,
      size.width * 0.18,
      _fill..color = const Color(0xFF8E1F18),
    );
    if (crackStage > 0) _drawCracks(canvas, rect, crackStage, 5);
    canvas.drawRRect(body, _line);
  }

  @override
  void drawProjectile(
    Canvas canvas,
    AmmoType type,
    double radius,
    double time,
  ) {
    switch (type) {
      case AmmoType.stone:
        drawStone(canvas, radius);
      case AmmoType.fireball:
        _drawFireball(canvas, radius, time);
      case AmmoType.cluster:
        for (final (dx, dy) in const [
          (-0.35, -0.2),
          (0.35, -0.2),
          (0.0, 0.35),
        ]) {
          canvas
            ..save()
            ..translate(dx * radius, dy * radius);
          drawStone(canvas, radius * 0.55);
          canvas.restore();
        }
        canvas.drawCircle(
          Offset.zero,
          radius * 0.75,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.05
            ..color = const Color(0xFF8A7250),
        );
      case AmmoType.powderKeg:
        drawBarrel(canvas, Size(radius * 1.8, radius * 2), crackStage: 0);
        _drawFuse(canvas, Offset(0, -radius * 1.05), time);
      case AmmoType.bolt:
        _drawBolt(canvas, radius);
    }
  }

  void _drawFireball(Canvas canvas, double radius, double time) {
    canvas.drawCircle(
      Offset.zero,
      radius * 2.2,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(Offset.zero, radius * 2.2, const [
          Color(0x88FF9A3A),
          Color(0x00FF9A3A),
        ]),
    );
    drawStone(canvas, radius);
    final flicker = 0.85 + 0.15 * math.sin(time * 30);
    canvas.drawCircle(
      Offset.zero,
      radius * flicker,
      Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          radius,
          const [Color(0xCCFFE08A), Color(0x99FF6A1A), Color(0x00FF6A1A)],
          const [0, 0.6, 1],
        ),
    );
  }

  void _drawFuse(Canvas canvas, Offset tip, double time) {
    canvas.drawCircle(
      tip,
      0.12 + 0.05 * math.sin(time * 40),
      Paint()
        ..blendMode = BlendMode.plus
        ..color = const Color(0xFFFFD26B),
    );
  }

  void _drawBolt(Canvas canvas, double radius) {
    final len = radius * 8;
    final shaft = Rect.fromLTWH(-len / 2, -0.05, len, 0.1);
    canvas
      ..drawRect(shaft, _fill..color = const Color(0xFF6E4A2C))
      ..drawPath(
        Path()
          ..moveTo(len / 2, -0.14)
          ..lineTo(len / 2 + 0.35, 0)
          ..lineTo(len / 2, 0.14)
          ..close(),
        _fill..color = const Color(0xFF55595E),
      );
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(-len / 2, 0)
          ..lineTo(-len / 2 + 0.35, 0)
          ..lineTo(-len / 2 - 0.05, s * 0.2)
          ..close(),
        _fill..color = const Color(0xFF8C8272),
      );
    }
  }

  @override
  void drawSiegeEngine(
    Canvas canvas,
    WeaponType type, {
    required double armAngle,
    required double aimAngle,
  }) {
    switch (type) {
      case WeaponType.catapult:
      case WeaponType.trebuchet:
        drawCatapult(canvas, armAngle: armAngle);
      case WeaponType.ballista:
        drawBallista(canvas, aimAngle: aimAngle, beam: _plainBeam);
    }
  }

  void _plainBeam(Canvas canvas, Offset a, Offset b, double width) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF5E3D24)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Shared ballista geometry; [beam] draws one timber in the theme's look.
  /// The pivot sits at (0, -1.6) and the stock points along [aimAngle].
  void drawBallista(
    Canvas canvas, {
    required double aimAngle,
    required void Function(Canvas, Offset, Offset, double) beam,
  }) {
    const pivot = Offset(0, -1.6);
    // Trestle: skid, splayed legs and a centre post.
    beam(canvas, const Offset(-1.7, -0.12), const Offset(1.5, -0.12), 0.24);
    beam(canvas, const Offset(-1.3, -0.1), pivot, 0.2);
    beam(canvas, const Offset(1.1, -0.1), pivot, 0.2);
    beam(canvas, const Offset(0, -0.1), pivot, 0.26);

    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..rotate(aimAngle);
    // Stock with a slider rail on top.
    beam(canvas, const Offset(-1.7, 0.05), const Offset(1.9, 0.05), 0.34);
    beam(canvas, const Offset(-1.3, -0.2), const Offset(1.7, -0.2), 0.1);
    // Torsion frame holding the bow arms.
    final frame = Rect.fromCenter(
      center: const Offset(1.2, 0),
      width: 0.45,
      height: 1.0,
    );
    canvas
      ..drawRect(frame, _fill..color = const Color(0xFF4A2F1B))
      ..drawRect(frame, _line);
    // Arms sweep back in two segments to suggest their curve.
    for (final s in const [-1.0, 1.0]) {
      final root = Offset(1.2, 0.45 * s);
      final elbow = Offset(0.95, 0.95 * s);
      final tip = Offset(0.5, 1.35 * s);
      beam(canvas, root, elbow, 0.14);
      beam(canvas, elbow, tip, 0.11);
    }
    // Drawn string, and the winch that spans it.
    final string = Paint()
      ..color = const Color(0xFFD9CBA8)
      ..strokeWidth = 0.045;
    canvas
      ..drawLine(const Offset(0.5, -1.35), const Offset(-1.0, -0.2), string)
      ..drawLine(const Offset(0.5, 1.35), const Offset(-1.0, -0.2), string)
      ..drawCircle(
        const Offset(-1.45, 0.3),
        0.22,
        _fill..color = const Color(0xFF4A2F1B),
      )
      ..drawCircle(const Offset(-1.45, 0.3), 0.22, _line)
      ..restore();
    canvas.drawCircle(pivot, 0.14, _fill..color = const Color(0xFF2E2E30));
  }

  @override
  Particle fireParticles(Size size, math.Random rng) {
    return ComposedParticle(
      children: [
        for (var i = 0; i < 2; i++) _ember(rng, size),
        _smoke(rng, size),
      ],
    );
  }

  Particle _ember(math.Random rng, Size size) {
    final life = 0.6 + rng.nextDouble() * 0.6;
    return AcceleratedParticle(
      lifespan: life,
      position: Vector2(
        (rng.nextDouble() - 0.5) * size.width,
        -size.height / 2 * rng.nextDouble(),
      ),
      speed: Vector2(
        (rng.nextDouble() - 0.5) * 0.8,
        -1.5 - rng.nextDouble() * 1.5,
      ),
      acceleration: Vector2(0, -0.8),
      child: ComputedParticle(
        lifespan: life,
        renderer: (canvas, p) {
          final t = p.progress;
          canvas.drawCircle(
            Offset.zero,
            0.06 * (1 - t) + 0.02,
            _particlePaint
              ..color = Color.lerp(
                const Color(0xFFFFE08A),
                const Color(0x00C0301A),
                t,
              )!,
          );
        },
      ),
    );
  }

  Particle _smoke(math.Random rng, Size size, {double scale = 1}) {
    final life = 1.4 + rng.nextDouble() * 0.8;
    final r0 = (0.25 + rng.nextDouble() * 0.2) * scale;
    return AcceleratedParticle(
      lifespan: life,
      position: Vector2(
        (rng.nextDouble() - 0.5) * size.width,
        -size.height / 2,
      ),
      speed: Vector2((rng.nextDouble() - 0.3) * 0.6, -1.2 - rng.nextDouble()),
      acceleration: Vector2(0.3, -0.2),
      child: ComputedParticle(
        lifespan: life,
        renderer: (canvas, p) {
          final t = p.progress;
          final r = r0 * (1 + 2.5 * t);
          final alpha = 0.4 * (1 - t) * math.min(1, t * 6);
          // Soft-edged puff: dense centre fading to nothing.
          canvas.drawCircle(
            Offset.zero,
            r,
            Paint()
              ..shader = Gradient.radial(
                Offset.zero,
                r,
                [
                  Color.fromRGBO(46, 42, 40, alpha),
                  Color.fromRGBO(46, 42, 40, alpha * 0.5),
                  const Color(0x002E2A28),
                ],
                const [0, 0.55, 1],
              ),
          );
        },
      ),
    );
  }

  @override
  Particle explosionParticles(double radius, math.Random rng) {
    return ComposedParticle(
      children: [
        // Flash.
        ComputedParticle(
          lifespan: 0.25,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(
              Offset.zero,
              radius * (0.3 + 0.7 * t),
              _particlePaint
                ..blendMode = BlendMode.plus
                ..color = Color.fromRGBO(255, 230, 170, 0.9 * (1 - t)),
            );
            _particlePaint.blendMode = BlendMode.srcOver;
          },
        ),
        for (var i = 0; i < 14; i++) _fireball(rng, radius),
        for (var i = 0; i < 10; i++)
          _smoke(rng, Size(radius, radius * 0.5), scale: 2),
        for (var i = 0; i < 18; i++)
          _chip(
            rng,
            const Color(0xFF3A2A1C),
            spread: const Size(1, 1),
            speed: 12,
          ),
      ],
    );
  }

  Particle _fireball(math.Random rng, double radius) {
    final life = 0.4 + rng.nextDouble() * 0.4;
    final dir = Vector2(rng.nextDouble() - 0.5, rng.nextDouble() - 0.7)
      ..normalize();
    final r0 = 0.3 + rng.nextDouble() * 0.4;
    return AcceleratedParticle(
      lifespan: life,
      speed: dir * (radius * (1.5 + rng.nextDouble() * 2)),
      acceleration: Vector2(0, -2),
      child: ComputedParticle(
        lifespan: life,
        renderer: (canvas, p) {
          final t = p.progress;
          canvas.drawCircle(
            Offset.zero,
            r0 * (1 + t),
            _particlePaint
              ..color = Color.lerp(
                const Color(0xEEFFC56B),
                const Color(0x00401A0A),
                t,
              )!,
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------- characters

  @override
  void drawCharacter(
    Canvas canvas,
    CharacterLook look, {
    required Pose pose,
    required double time,
  }) {
    final s = look.height / 1.8;
    canvas
      ..save()
      ..scale(s);
    if (pose == Pose.fallen) {
      // Lying on the ground, head toward -x.
      canvas
        ..translate(-0.9, -0.16)
        ..rotate(-math.pi / 2);
    }
    final kneel = pose == Pose.kneel;
    final lift = kneel ? 0.42 : 0.0;
    final stride = pose == Pose.walk ? math.sin(time * 8) * 0.35 : 0.0;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025
      ..color = const Color(0xCC15100C);

    // Cloak falls behind the body.
    if (look.cloak != null) {
      final sway = pose == Pose.walk ? math.sin(time * 4) * 0.05 : 0.0;
      final cloak = Path()
        ..moveTo(0.12, -1.44 + lift)
        ..quadraticBezierTo(
          -0.35 + sway,
          -0.9 + lift,
          -0.3 + sway,
          -0.25 + lift,
        )
        ..lineTo(0.02, -0.3 + lift)
        ..lineTo(0.05, -1.44 + lift)
        ..close();
      canvas.drawPath(
        cloak,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, -1.44 + lift),
            Offset(0, -0.25 + lift),
            [
              look.cloak!,
              Color.lerp(look.cloak!, const Color(0xFF000000), 0.45)!,
            ],
          ),
      );
    }

    // Legs.
    final leg = Paint()
      ..color = look.clothDark
      ..strokeWidth = 0.13
      ..strokeCap = StrokeCap.round;
    if (kneel) {
      canvas
        ..drawLine(const Offset(0, -0.4), const Offset(0.28, -0.4), leg)
        ..drawLine(const Offset(0.28, -0.4), const Offset(0.28, -0.05), leg)
        ..drawLine(const Offset(-0.02, -0.4), const Offset(-0.25, -0.05), leg)
        ..drawLine(const Offset(-0.25, -0.05), const Offset(0.1, -0.03), leg);
    } else {
      for (final phase in [1.0, -1.0]) {
        final a = stride * phase;
        final foot = Offset(math.sin(a) * 0.85, -0.85 + math.cos(a) * 0.85);
        canvas.drawLine(const Offset(0, -0.85), foot, leg);
      }
    }

    // Tunic.
    final torso = RRect.fromRectAndCorners(
      Rect.fromLTRB(-0.2, -1.46 + lift, 0.22, -0.72 + lift),
      topLeft: const Radius.circular(0.08),
      topRight: const Radius.circular(0.08),
      bottomLeft: const Radius.circular(0.03),
      bottomRight: const Radius.circular(0.03),
    );
    canvas
      ..drawRRect(
        torso,
        Paint()
          ..shader = Gradient.linear(Offset(0.22, 0), const Offset(-0.2, 0), [
            look.cloth,
            look.clothDark,
          ]),
      )
      ..drawRect(
        Rect.fromLTRB(-0.2, -0.98 + lift, 0.22, -0.92 + lift),
        _fill..color = const Color(0xFF2A1E14),
      )
      ..drawRRect(torso, edge);

    // Carried item in the front hand.
    final shoulder = Offset(0.05, -1.36 + lift);
    final Offset hand;
    if (pose == Pose.point) {
      hand = shoulder + const Offset(0.55, -0.2);
    } else if (pose == Pose.talk) {
      hand = shoulder + Offset(0.32, 0.28 - 0.08 * math.sin(time * 5));
    } else if (pose == Pose.fallen) {
      hand = shoulder + const Offset(0.3, 0.45);
    } else {
      hand = shoulder + Offset(0.12 - stride * 0.4, 0.55);
    }
    final wood = Paint()
      ..color = const Color(0xFF5A3E26)
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round;
    switch (look.carried) {
      case Carried.sword:
        // Sheathed at the hip unless pointing.
        if (pose == Pose.point) {
          canvas.drawLine(
            hand,
            hand + const Offset(0.7, -0.25),
            Paint()
              ..color = const Color(0xFFB8BCC0)
              ..strokeWidth = 0.04,
          );
        } else {
          canvas.drawLine(
            Offset(-0.05, -0.92 + lift),
            Offset(-0.32, -0.3 + lift),
            Paint()
              ..color = const Color(0xFF3A2A1C)
              ..strokeWidth = 0.06,
          );
        }
      case Carried.staff:
        canvas.drawLine(
          hand + const Offset(0, -0.9),
          hand + const Offset(0, 0.55),
          wood,
        );
      case Carried.spear:
        canvas
          ..drawLine(
            hand + const Offset(0, -1.0),
            hand + const Offset(0, 0.5),
            wood,
          )
          ..drawPath(
            Path()
              ..moveTo(hand.dx - 0.05, hand.dy - 1.0)
              ..lineTo(hand.dx, hand.dy - 1.22)
              ..lineTo(hand.dx + 0.05, hand.dy - 1.0)
              ..close(),
            _fill..color = const Color(0xFF8E9296),
          );
      case Carried.hammer:
        canvas
          ..drawLine(hand, hand + const Offset(0.1, -0.5), wood)
          ..drawRect(
            Rect.fromCenter(
              center: hand + const Offset(0.11, -0.52),
              width: 0.22,
              height: 0.09,
            ),
            _fill..color = const Color(0xFF6E7276),
          );
      case Carried.none:
        break;
    }
    // Arm over the item.
    canvas.drawLine(
      shoulder,
      hand,
      Paint()
        ..color = look.cloth
        ..strokeWidth = 0.1
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(hand, 0.05, _fill..color = look.skin);

    // Head.
    final head = Offset(0.03, -1.62 + lift);
    canvas.drawCircle(head, 0.14, _fill..color = look.skin);
    if (look.headgear == Headgear.none || look.headgear == Headgear.crown) {
      canvas.drawPath(
        Path()
          ..addArc(
            Rect.fromCircle(center: head, radius: 0.145),
            math.pi * 0.9,
            math.pi * 1.25,
          )
          ..close(),
        _fill..color = look.hair,
      );
    }
    if (look.beard != null) {
      canvas.drawPath(
        Path()
          ..moveTo(head.dx - 0.08, head.dy + 0.03)
          ..quadraticBezierTo(
            head.dx + 0.02,
            head.dy + 0.26,
            head.dx + 0.13,
            head.dy + 0.04,
          )
          ..close(),
        _fill..color = look.beard!,
      );
    }
    // A shadowed brow and eye line: stern, no cartoon eyes.
    canvas.drawLine(
      head + const Offset(0.06, -0.03),
      head + const Offset(0.12, -0.02),
      Paint()
        ..color = const Color(0xCC1A120C)
        ..strokeWidth = 0.022,
    );
    switch (look.headgear) {
      case Headgear.hood:
        canvas.drawPath(
          Path()
            ..addArc(
              Rect.fromCircle(center: head, radius: 0.19),
              math.pi * 0.72,
              math.pi * 1.45,
            )
            ..lineTo(head.dx - 0.2, head.dy + 0.22)
            ..close(),
          _fill..color = look.clothDark,
        );
      case Headgear.helmet:
        canvas.drawPath(
          Path()
            ..addArc(
              Rect.fromCircle(center: head, radius: 0.16),
              math.pi,
              math.pi,
            )
            ..close(),
          _fill..color = const Color(0xFF8E9296),
        );
      case Headgear.cap:
        canvas.drawPath(
          Path()
            ..addArc(
              Rect.fromCircle(
                center: head - const Offset(0, 0.02),
                radius: 0.15,
              ),
              math.pi,
              math.pi,
            )
            ..close(),
          _fill..color = const Color(0xFF5A3E26),
        );
      case Headgear.nemes:
        final nemes = Path()
          ..moveTo(head.dx - 0.2, head.dy + 0.34)
          ..lineTo(head.dx - 0.16, head.dy - 0.08)
          ..quadraticBezierTo(
            head.dx,
            head.dy - 0.26,
            head.dx + 0.16,
            head.dy - 0.08,
          )
          ..lineTo(head.dx + 0.1, head.dy + 0.06)
          ..lineTo(head.dx - 0.04, head.dy + 0.06)
          ..lineTo(head.dx - 0.06, head.dy + 0.34)
          ..close();
        canvas.drawPath(nemes, _fill..color = const Color(0xFFC9A13E));
        final stripe = Paint()
          ..color = const Color(0xFF1F3F7A)
          ..strokeWidth = 0.025;
        for (var i = 0; i < 4; i++) {
          final y = head.dy - 0.1 + i * 0.1;
          canvas.drawLine(
            Offset(head.dx - 0.18, y),
            Offset(head.dx - 0.07, y),
            stripe,
          );
        }
        // Uraeus.
        canvas.drawCircle(
          head + const Offset(0.1, -0.16),
          0.03,
          _fill..color = const Color(0xFFE8C45A),
        );
      case Headgear.crown:
        canvas.drawPath(
          Path()
            ..moveTo(head.dx - 0.13, head.dy - 0.1)
            ..lineTo(head.dx - 0.13, head.dy - 0.26)
            ..lineTo(head.dx - 0.05, head.dy - 0.18)
            ..lineTo(head.dx + 0.03, head.dy - 0.3)
            ..lineTo(head.dx + 0.1, head.dy - 0.18)
            ..lineTo(head.dx + 0.16, head.dy - 0.26)
            ..lineTo(head.dx + 0.16, head.dy - 0.1)
            ..close(),
          _fill..color = const Color(0xFFD4A437),
        );
      case Headgear.none:
        break;
    }
    canvas
      ..drawCircle(head, 0.14, edge)
      ..restore();
  }

  @override
  void drawSceneProp(Canvas canvas, SceneProp prop, double time) {
    switch (prop) {
      case SceneProp.tent:
        final tent = Path()
          ..moveTo(-1.8, 0)
          ..lineTo(0, -2.4)
          ..lineTo(1.8, 0)
          ..close();
        canvas
          ..drawPath(
            tent,
            Paint()
              ..shader = Gradient.linear(
                const Offset(-1.8, 0),
                const Offset(1.8, 0),
                const [Color(0xFF8C7A5A), Color(0xFF5E4E36)],
              ),
          )
          ..drawPath(
            Path()
              ..moveTo(-0.45, 0)
              ..lineTo(0, -1.3)
              ..lineTo(0.45, 0)
              ..close(),
            _fill..color = const Color(0xFF1E1812),
          )
          ..drawPath(tent, _line);
      case SceneProp.campfire:
        final log = Paint()
          ..color = const Color(0xFF3E2A1A)
          ..strokeWidth = 0.14
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(const Offset(-0.45, -0.05), const Offset(0.4, -0.2), log)
          ..drawLine(const Offset(-0.4, -0.2), const Offset(0.45, -0.05), log);
        canvas
          ..save()
          ..translate(0, -0.3);
        drawFire(canvas, const Size(0.9, 0.5), time);
        canvas
          ..restore()
          ..drawCircle(
            const Offset(0, -0.4),
            4,
            Paint()
              ..blendMode = BlendMode.plus
              ..shader = Gradient.radial(const Offset(0, -0.4), 4, [
                Color.fromRGBO(255, 150, 60, 0.18 + 0.04 * math.sin(time * 13)),
                const Color(0x00FF9640),
              ]),
          );
      case SceneProp.shard:
        final pulse = 0.5 + 0.5 * math.sin(time * 3);
        canvas.drawCircle(
          const Offset(0, -0.3),
          0.6,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = Gradient.radial(const Offset(0, -0.3), 0.6, [
              Color.fromRGBO(150, 190, 230, 0.3 + 0.2 * pulse),
              const Color(0x0096BEE6),
            ]),
        );
        final shard = Path()
          ..moveTo(0, -0.62)
          ..lineTo(0.12, -0.3)
          ..lineTo(0.04, 0)
          ..lineTo(-0.1, -0.22)
          ..close();
        canvas
          ..drawPath(shard, _fill..color = const Color(0xFF3C4148))
          ..drawPath(shard, _line);
      case SceneProp.banner:
        canvas.drawLine(
          Offset.zero,
          const Offset(0, -3.2),
          Paint()
            ..color = const Color(0xFF4A2F1B)
            ..strokeWidth = 0.08,
        );
        final wave = 0.1 * math.sin(time * 2);
        canvas.drawPath(
          Path()
            ..moveTo(0, -3.1)
            ..quadraticBezierTo(0.5, -3.1 + wave, 1.0, -3.0)
            ..lineTo(1.0, -2.1)
            ..quadraticBezierTo(0.5, -2.2 - wave, 0, -2.2)
            ..close(),
          _fill..color = const Color(0xFF7A1E1A),
        );
    }
  }

  // ------------------------------------------------------------- particles

  static const _dust = Color(0xFF8C7A64);
  final Paint _particlePaint = Paint();

  @override
  Particle breakParticles(BlockMaterial material, Size size, math.Random rng) {
    final area = size.width * size.height;
    final chipColor = switch (material) {
      BlockMaterial.wood => const Color(0xFF5E3A20),
      BlockMaterial.stone => const Color(0xFF6E6B64),
      BlockMaterial.glass => const Color(0xDDCBEFF5),
    };
    final puffs = (4 + area * 2).clamp(4, 12).round();
    final chips = (8 + area * 6).clamp(8, 26).round();
    return ComposedParticle(
      children: [
        for (var i = 0; i < puffs; i++)
          _puff(
            rng,
            spread: size,
            color: material == BlockMaterial.glass
                ? const Color(0xFFB9C7C9)
                : _dust,
          ),
        for (var i = 0; i < chips; i++) _chip(rng, chipColor, spread: size),
      ],
    );
  }

  @override
  Particle impactParticles(double strength, math.Random rng) {
    final s = strength.clamp(0.3, 1.5);
    return ComposedParticle(
      children: [
        for (var i = 0; i < (3 + 4 * s).round(); i++)
          _puff(rng, spread: const Size(0.6, 0.6), scale: s),
        for (var i = 0; i < (3 + 5 * s).round(); i++)
          _chip(
            rng,
            const Color(0xFF4A3B2B),
            spread: const Size(0.4, 0.4),
            speed: 5 * s,
          ),
      ],
    );
  }

  @override
  Particle unitDeathParticles(UnitKind kind, math.Random rng) {
    final cloth = kind == UnitKind.king
        ? const Color(0xFF4B2A55)
        : const Color(0xFF4F4636);
    return ComposedParticle(
      children: [
        for (var i = 0; i < 6; i++)
          _puff(
            rng,
            spread: const Size(0.8, 0.8),
            color: const Color(0xFF3A332C),
          ),
        for (var i = 0; i < 8; i++)
          _chip(rng, cloth, spread: const Size(0.6, 0.6)),
        if (kind == UnitKind.king)
          for (var i = 0; i < 6; i++)
            _chip(
              rng,
              const Color(0xFFD4A437),
              spread: const Size(0.5, 0.5),
              speed: 7,
            ),
      ],
    );
  }

  @override
  Particle trailParticle(math.Random rng) => _puff(
    rng,
    spread: const Size(0.2, 0.2),
    scale: 0.45,
    color: const Color(0xFFB8A68E),
    life: 0.45,
    drift: false,
  );

  Particle _puff(
    math.Random rng, {
    required Size spread,
    double scale = 1,
    Color color = _dust,
    double? life,
    bool drift = true,
  }) {
    final lifespan = life ?? 0.9 + rng.nextDouble() * 0.7;
    final r0 = (0.25 + rng.nextDouble() * 0.3) * scale;
    return AcceleratedParticle(
      lifespan: lifespan,
      position: Vector2(
        (rng.nextDouble() - 0.5) * spread.width,
        (rng.nextDouble() - 0.5) * spread.height,
      ),
      speed: drift
          ? Vector2((rng.nextDouble() - 0.5) * 3, -rng.nextDouble() * 2) * scale
          : Vector2.zero(),
      acceleration: Vector2(0, -0.6),
      child: ComputedParticle(
        lifespan: lifespan,
        renderer: (canvas, p) {
          final t = p.progress;
          canvas.drawCircle(
            Offset.zero,
            r0 * (1 + 1.8 * t),
            _particlePaint..color = color.withValues(alpha: 0.45 * (1 - t)),
          );
        },
      ),
    );
  }

  Particle _chip(
    math.Random rng,
    Color color, {
    required Size spread,
    double speed = 6,
  }) {
    final lifespan = 0.7 + rng.nextDouble() * 0.6;
    final size = 0.08 + rng.nextDouble() * 0.16;
    final spin = (rng.nextDouble() - 0.5) * 20;
    final angle0 = rng.nextDouble() * math.pi;
    final dir = Vector2(rng.nextDouble() - 0.5, -rng.nextDouble() * 0.9 - 0.1)
      ..normalize();
    return AcceleratedParticle(
      lifespan: lifespan,
      position: Vector2(
        (rng.nextDouble() - 0.5) * spread.width,
        (rng.nextDouble() - 0.5) * spread.height,
      ),
      speed: dir * (speed * (0.5 + rng.nextDouble())),
      acceleration: Vector2(0, 12),
      child: ComputedParticle(
        lifespan: lifespan,
        renderer: (canvas, p) {
          final t = p.progress;
          final fade = t > 0.7 ? (1 - t) / 0.3 : 1.0;
          canvas
            ..save()
            ..rotate(angle0 + spin * t * lifespan)
            ..drawRect(
              Rect.fromCenter(
                center: Offset.zero,
                width: size,
                height: size * 0.6,
              ),
              _particlePaint..color = color.withValues(alpha: color.a * fade),
            )
            ..restore();
        },
      ),
    );
  }
}
