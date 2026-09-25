import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/services.dart';

import '../core/materials.dart';
import '../levels/level_data.dart';
import 'stylized_theme.dart';

enum _Tex {
  wood('rough_wood.jpg'),
  planks('medieval_wood.jpg'),
  stone('large_sandstone_blocks_01.jpg'),
  grass('grass_ground.jpg'),
  mud('brown_mud_dry.jpg');

  const _Tex(this.file);
  final String file;
}

/// Painted-realistic look: photo textures (CC0, Poly Haven) on every
/// block and beam, soft top-down lighting, an overcast sky and misty
/// layered hills. Particles and aiming visuals are inherited from
/// [StylizedTheme].
class RealisticTheme extends StylizedTheme {
  RealisticTheme._(this._images);

  static Future<RealisticTheme> load() async {
    final images = <_Tex, ui.Image>{};
    for (final tex in _Tex.values) {
      final data = await rootBundle.load('assets/images/textures/${tex.file}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      images[tex] = (await codec.getNextFrame()).image;
    }
    return RealisticTheme._(images);
  }

  final Map<_Tex, ui.Image> _images;
  final Map<int, Paint> _paintCache = {};

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.035
    ..color = const Color(0xAA1B150F);

  /// Makes the sandstone read as weathered grey castle stone.
  static const _greyStone = ColorFilter.matrix([
    0.55, 0.35, 0.10, 0, 0, //
    0.45, 0.45, 0.10, 0, 0, //
    0.40, 0.35, 0.25, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  /// A repeating texture fill in world meters.
  /// [metersPerImage] sets how much of the world one texture tile covers.
  Paint _texture(
    _Tex tex, {
    required double metersPerImage,
    double rotation = 0,
    Offset offset = Offset.zero,
    ColorFilter? filter,
  }) {
    final key = Object.hash(tex, metersPerImage, rotation, offset, filter);
    return _paintCache.putIfAbsent(key, () {
      final image = _images[tex]!;
      final s = metersPerImage / image.width;
      final c = math.cos(rotation) * s, n = math.sin(rotation) * s;
      final matrix = Float64List.fromList([
        c, n, 0, 0, //
        -n, c, 0, 0, //
        0, 0, 1, 0, //
        offset.dx, offset.dy, 0, 1,
      ]);
      return Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.medium
        ..colorFilter = filter
        ..shader = ImageShader(
          image,
          TileMode.repeated,
          TileMode.repeated,
          matrix,
        );
    });
  }

  Paint _materialPaint(
    BlockMaterial material, {
    bool horizontal = true,
    int seed = 0,
  }) {
    // A few texture offsets per material so neighbours don't look cloned.
    final variant = Offset((seed % 5) * 0.37, (seed % 3) * 0.53);
    return switch (material) {
      BlockMaterial.wood => _texture(
        _Tex.wood,
        metersPerImage: 1.8,
        rotation: horizontal ? math.pi / 2 : 0,
        offset: variant,
      ),
      BlockMaterial.stone => _texture(
        _Tex.stone,
        metersPerImage: 2.6,
        offset: variant,
        filter: _greyStone,
      ),
      BlockMaterial.glass => _fill..color = const Color(0x668FB8C4),
    };
  }

  /// Soft light from above: brighter top, darker bottom, shaded rim.
  void _shade(Canvas canvas, RRect rrect) {
    final r = rrect.outerRect;
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..shader = Gradient.linear(
            r.topCenter,
            r.bottomCenter,
            const [Color(0x26FFF4DC), Color(0x00000000), Color(0x59000000)],
            const [0, 0.45, 1],
          ),
      )
      ..drawRRect(
        rrect.deflate(0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08
          ..color = const Color(0x33000000),
      )
      ..drawRRect(rrect, _edge);
  }

  // ------------------------------------------------------------- scenery

  final Paint _cloud = Paint()
    ..color = const Color(0x66F2EEE4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
  final Paint _cloudShadow = Paint()
    ..color = const Color(0x40767C80)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

  @override
  void drawBackground(Canvas canvas, Rect visible, double time) {
    canvas.drawRect(
      visible,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, visible.top),
          const Offset(0, 1),
          const [Color(0xFF8E9A9E), Color(0xFFC9CCC4), Color(0xFFE6E1D0)],
          const [0, 0.55, 1],
        ),
    );

    // Diffuse bright patch where the sun hides behind the overcast.
    final glow = Offset(visible.center.dx * 0.9 + 12, visible.top + 6);
    canvas.drawCircle(
      glow,
      16,
      Paint()
        ..shader = Gradient.radial(glow, 16, const [
          Color(0x55FFF8E6),
          Color(0x00FFF8E6),
        ]),
    );

    _overcast(canvas, visible, time);

    // Hills recede into mist: farther layers are paler and scroll less.
    _hills(canvas, visible, 0.08, -5, 4, 0.05, const Color(0xFFB4B8AE), 3, 0);
    _haze(canvas, visible, -2.5, 0x40);
    _hills(
      canvas,
      visible,
      0.2,
      -3,
      2.6,
      0.08,
      const Color(0xFF97A08F),
      11,
      0.35,
    );
    _haze(canvas, visible, -1.5, 0x38);
    _hills(
      canvas,
      visible,
      0.4,
      -1.6,
      1.4,
      0.12,
      const Color(0xFF6F7C64),
      29,
      0.7,
    );
    _haze(canvas, visible, -0.6, 0x28);
    _hills(
      canvas,
      visible,
      0.65,
      -0.5,
      0.6,
      0.2,
      const Color(0xFF55633F),
      41,
      0,
    );
  }

  void _overcast(Canvas canvas, Rect visible, double time) {
    const parallax = 0.06, drift = 0.25, wrap = 160.0;
    final shift = visible.center.dx * parallax + time * drift;
    final rng = math.Random(8);
    for (var i = 0; i < 7; i++) {
      final baseX = rng.nextDouble() * wrap;
      final y = visible.top + 2 + rng.nextDouble() * visible.height * 0.3;
      final w = 12 + rng.nextDouble() * 14;
      final x = visible.left - 35 + ((baseX + shift) % wrap);
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final lobeH = 1.4 + rng.nextDouble() * 1.8;
        path.addOval(
          Rect.fromCenter(
            center: Offset(x + (k / 5 - 0.5) * w * 0.75, y - lobeH * 0.25),
            width: w * (0.3 + rng.nextDouble() * 0.2),
            height: lobeH,
          ),
        );
      }
      canvas
        ..drawPath(path.shift(const Offset(0.4, 0.7)), _cloudShadow)
        ..drawPath(path, _cloud);
    }
  }

  /// A rolling hill silhouette. [trees] (0–1) adds a bumpy treeline.
  void _hills(
    Canvas canvas,
    Rect visible,
    double parallax,
    double baseY,
    double amp,
    double freq,
    Color color,
    int seed,
    double trees,
  ) {
    final shift = visible.center.dx * parallax;
    final path = Path()..moveTo(visible.left, 1);
    for (var x = visible.left; x <= visible.right + 0.5; x += 0.35) {
      final u = (x - shift) * freq + seed;
      var y =
          baseY -
          amp *
              (0.6 * math.sin(u) +
                  0.3 * math.sin(u * 2.1 + 1.3) +
                  0.1 * math.sin(u * 4.7));
      if (trees > 0) {
        // Clumps of tree crowns riding the ridge.
        final v = (x - shift) * 1.7 + seed;
        final clump = math.max(0.0, math.sin(v * 0.23 + seed));
        y -= trees * clump * (0.6 + 0.4 * math.sin(v * 3.1).abs());
      }
      path.lineTo(x, y);
    }
    path
      ..lineTo(visible.right + 0.5, 1)
      ..close();
    canvas.drawPath(path, _fill..color = color);
  }

  void _haze(Canvas canvas, Rect visible, double y, int alpha) {
    final band = Rect.fromLTRB(visible.left, y - 4, visible.right, y + 1.5);
    canvas.drawRect(
      band,
      Paint()
        ..shader = Gradient.linear(band.topCenter, band.bottomCenter, [
          const Color(0x00E6E1D0),
          Color.fromARGB(alpha, 0xE6, 0xE1, 0xD0),
        ]),
    );
  }

  @override
  void drawGround(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, _texture(_Tex.mud, metersPerImage: 3.5));
    // Soil darkens with depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.linear(
          rect.topCenter,
          rect.topCenter + const Offset(0, 5),
          const [Color(0x00000000), Color(0x8C000000)],
        ),
    );
    final turf = Rect.fromLTWH(rect.left, rect.top, rect.width, 0.55);
    canvas
      ..drawRect(turf, _texture(_Tex.grass, metersPerImage: 3.0))
      ..drawRect(
        turf,
        Paint()
          ..shader = Gradient.linear(turf.topCenter, turf.bottomCenter, const [
            Color(0x1AFFFFE0),
            Color(0x66000000),
          ]),
      );
  }

  @override
  void drawGroundDetail(Canvas canvas, Rect visible) {
    for (final (x, h, lean) in const [
      (5.0, 1.5, 0.12),
      (5.8, 1.1, -0.08),
      (6.7, 1.7, 0.2),
      (11.5, 1.3, -0.15),
      (12.3, 1.6, 0.05),
      (17.0, 1.2, 0.18),
    ]) {
      if (x < visible.left - 2 || x > visible.right + 2) continue;
      _stake(canvas, x, h, lean);
    }

    final bladeColors = [
      const Color(0xFF4E5B2E),
      const Color(0xFF6B7440),
      const Color(0xFF3E4A26),
      const Color(0xFF8A8455),
    ];
    final blade = Paint()
      ..strokeWidth = 0.045
      ..strokeCap = StrokeCap.round;
    for (
      var x = visible.left.floorToDouble() - 1;
      x < visible.right + 1;
      x += 0.5
    ) {
      final cell = math.Random(x.toInt() * 7919 + (x * 2).toInt() + 17);
      if (cell.nextDouble() < 0.35) continue;
      final base = x + cell.nextDouble() * 0.5;
      final blades = 3 + cell.nextInt(5);
      for (var k = 0; k < blades; k++) {
        blade.color = bladeColors[cell.nextInt(bladeColors.length)];
        final h = 0.2 + cell.nextDouble() * 0.45;
        final lean = (cell.nextDouble() - 0.5) * 0.35;
        canvas.drawLine(
          Offset(base + k * 0.04, 0.05),
          Offset(base + k * 0.04 + lean, -h),
          blade,
        );
      }
      if (cell.nextDouble() < 0.12) {
        final r = Rect.fromCenter(
          center: Offset(base, -0.02),
          width: 0.35 + cell.nextDouble() * 0.3,
          height: 0.2 + cell.nextDouble() * 0.12,
        );
        canvas
          ..drawOval(
            r,
            _texture(_Tex.stone, metersPerImage: 1.5, filter: _greyStone),
          )
          ..drawOval(r, _edge);
      }
    }
  }

  /// A sharpened wooden stake driven into the ground.
  void _stake(Canvas canvas, double x, double h, double lean) {
    canvas
      ..save()
      ..translate(x, 0.2)
      ..rotate(lean);
    const w = 0.22;
    final path = Path()
      ..moveTo(-w / 2, 0)
      ..lineTo(-w / 2, -h + 0.3)
      ..lineTo(0, -h)
      ..lineTo(w / 2, -h + 0.3)
      ..lineTo(w / 2, 0)
      ..close();
    canvas
      ..drawPath(path, _texture(_Tex.wood, metersPerImage: 1.2))
      ..drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            const Offset(-w / 2, 0),
            const Offset(w / 2, 0),
            const [Color(0x22FFFFFF), Color(0x66000000)],
          ),
      )
      ..drawPath(path, _edge)
      ..restore();
  }

  @override
  void drawVignette(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          rect.center,
          size.longestSide * 0.65,
          const [Color(0x00000000), Color(0x00000000), Color(0x55100C08)],
          const [0, 0.6, 1],
        ),
    );
  }

  // --------------------------------------------------------------- blocks

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
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(0.04));

    if (material == BlockMaterial.glass) {
      _drawGlass(canvas, rrect);
    } else {
      canvas.drawRRect(
        rrect,
        _materialPaint(
          material,
          horizontal: size.width >= size.height,
          seed: seed,
        ),
      );
      _shade(canvas, rrect);
    }
    if (crackStage > 0) _cracks(canvas, rect, crackStage, seed);
  }

  void _drawGlass(Canvas canvas, RRect rrect) {
    final r = rrect.outerRect;
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..shader = Gradient.linear(r.topLeft, r.bottomRight, const [
            Color(0x88B9D8E0),
            Color(0x55708F99),
          ]),
      )
      ..drawLine(
        Offset(r.left + 0.12, r.bottom - 0.12),
        Offset(r.left + math.min(r.width, r.height) * 0.55, r.top + 0.12),
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..strokeWidth = 0.05,
      )
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = const Color(0xCC4A5A60),
      );
  }

  void _cracks(Canvas canvas, Rect rect, int stage, int seed) {
    final rng = math.Random(seed);
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xE0140E0A);
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025
      ..color = const Color(0x40FFF0D8);
    for (var i = 0; i < stage * 2; i++) {
      var p = Offset(
        rect.left + rng.nextDouble() * rect.width,
        rect.top + rng.nextDouble() * rect.height,
      );
      final path = Path()..moveTo(p.dx, p.dy);
      for (var s = 0; s < 3 + stage; s++) {
        p += Offset(rng.nextDouble() - 0.5, rng.nextDouble() - 0.5) * 0.55;
        p = Offset(
          p.dx.clamp(rect.left, rect.right),
          p.dy.clamp(rect.top, rect.bottom),
        );
        path.lineTo(p.dx, p.dy);
      }
      // A faint lit lip below each crack sells the depth.
      canvas
        ..drawPath(path.shift(const Offset(0.02, 0.03)), light)
        ..drawPath(path, dark);
    }
  }

  @override
  void drawShard(Canvas canvas, List<Offset> polygon, BlockMaterial material) {
    final path = Path()..addPolygon(polygon, true);
    canvas.drawPath(path, _materialPaint(material));
    final bounds = path.getBounds();
    canvas
      ..drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            bounds.topCenter,
            bounds.bottomCenter,
            const [Color(0x1AFFFFFF), Color(0x66000000)],
          ),
      )
      ..drawPath(path, _edge);
  }

  // ---------------------------------------------------------------- units

  @override
  void drawUnit(
    Canvas canvas,
    double radius,
    UnitKind kind, {
    required bool hurt,
  }) {
    // Figures are drawn larger than their physics circle so they read at
    // phone size; the circle stays small so they fit inside castle rooms.
    final r = radius * 1.35;
    // Lift the enlarged figure so its feet rest where the circle touches down.
    canvas
      ..save()
      ..translate(0, radius - r * 0.95);
    final isKing = kind == UnitKind.king;
    final cloth = isKing ? const Color(0xFF2F4C8E) : const Color(0xFF8C2A20);
    final clothDark = isKing
        ? const Color(0xFF1C2E57)
        : const Color(0xFF561812);
    const skin = Color(0xFFD1A27E);
    const steel = Color(0xFF8E9296);

    // Soft contact shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.95),
        width: r * 1.6,
        height: r * 0.25,
      ),
      _fill..color = const Color(0x40000000),
    );

    if (!isKing) {
      // Spear held upright behind the body.
      canvas
        ..drawLine(
          Offset(r * 0.55, r * 0.9),
          Offset(r * 0.55, -r * 1.9),
          Paint()
            ..color = const Color(0xFF5A3E26)
            ..strokeWidth = r * 0.1,
        )
        ..drawPath(
          Path()
            ..moveTo(r * 0.47, -r * 1.85)
            ..lineTo(r * 0.55, -r * 2.25)
            ..lineTo(r * 0.63, -r * 1.85)
            ..close(),
          _fill..color = steel,
        );
    }

    // Legs.
    final legs = _fill..color = const Color(0xFF2D261F);
    canvas
      ..drawRect(Rect.fromLTRB(-r * 0.3, r * 0.3, -r * 0.08, r * 0.95), legs)
      ..drawRect(Rect.fromLTRB(r * 0.08, r * 0.3, r * 0.3, r * 0.95), legs);

    // Torso: tunic, or a long robe for the king.
    final torso = isKing
        ? (Path()
            ..moveTo(-r * 0.4, -r * 0.3)
            ..lineTo(r * 0.4, -r * 0.3)
            ..lineTo(r * 0.6, r * 0.95)
            ..lineTo(-r * 0.6, r * 0.95)
            ..close())
        : (Path()..addRRect(
            RRect.fromLTRBR(
              -r * 0.42,
              -r * 0.3,
              r * 0.42,
              r * 0.45,
              Radius.circular(r * 0.15),
            ),
          ));
    final tb = torso.getBounds();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = Gradient.linear(tb.centerLeft, tb.centerRight, [
          cloth,
          clothDark,
        ]),
    );
    if (isKing) {
      canvas.drawLine(
        Offset(0, -r * 0.3),
        Offset(0, r * 0.95),
        Paint()
          ..color = const Color(0xFFC9A13E)
          ..strokeWidth = r * 0.1,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTRB(-r * 0.42, r * 0.12, r * 0.42, r * 0.22),
        _fill..color = const Color(0xFF3A2A1C),
      );
    }
    canvas.drawPath(torso, _edge);

    // Head.
    final head = Offset(0, -r * 0.6);
    canvas
      ..drawCircle(head, r * 0.28, _fill..color = skin)
      ..drawCircle(head, r * 0.28, _edge);

    if (isKing) {
      final top = head.dy - r * 0.22;
      final crown = Path()
        ..moveTo(-r * 0.3, top)
        ..lineTo(-r * 0.32, top - r * 0.35)
        ..lineTo(-r * 0.15, top - r * 0.18)
        ..lineTo(0, top - r * 0.42)
        ..lineTo(r * 0.15, top - r * 0.18)
        ..lineTo(r * 0.32, top - r * 0.35)
        ..lineTo(r * 0.3, top)
        ..close();
      canvas
        ..drawPath(
          crown,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, top - r * 0.42),
              Offset(0, top),
              const [Color(0xFFF2D27A), Color(0xFFA67C1F)],
            ),
        )
        ..drawPath(crown, _edge);
    } else {
      // Kettle helmet with a brim.
      final helmet = Path()
        ..addArc(
          Rect.fromCircle(center: head, radius: r * 0.31),
          math.pi,
          math.pi,
        )
        ..close();
      canvas
        ..drawPath(
          helmet,
          Paint()
            ..shader = Gradient.linear(
              head - Offset(r * 0.3, r * 0.3),
              head + Offset(r * 0.3, 0),
              const [Color(0xFFC4C8CC), steel],
            ),
        )
        ..drawRect(
          Rect.fromLTRB(
            head.dx - r * 0.42,
            head.dy - r * 0.04,
            head.dx + r * 0.42,
            head.dy + r * 0.03,
          ),
          _fill..color = const Color(0xFF6E7276),
        )
        ..drawPath(helmet, _edge);
    }

    if (hurt) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.05,
        _fill..color = const Color(0x66B0281C),
      );
    }
    canvas.restore();
  }

  @override
  void drawStone(Canvas canvas, double radius) {
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas
      ..drawCircle(
        Offset.zero,
        radius,
        _texture(_Tex.stone, metersPerImage: 1.4, filter: _greyStone),
      )
      ..drawCircle(
        Offset.zero,
        radius,
        Paint()
          ..shader = Gradient.radial(
            Offset(-radius * 0.35, -radius * 0.35),
            radius * 1.4,
            const [Color(0x22FFFFFF), Color(0x00000000), Color(0x88000000)],
            const [0, 0.5, 1],
          ),
      )
      ..drawOval(rect, _edge);
  }

  // ------------------------------------------------------------ trebuchet

  /// A textured timber beam from [a] to [b].
  void _beam(Canvas canvas, Offset a, Offset b, double width) {
    final d = b - a;
    final len = d.distance;
    canvas
      ..save()
      ..translate(a.dx, a.dy)
      ..rotate(math.atan2(d.dy, d.dx));
    final rect = Rect.fromLTWH(0, -width / 2, len, width);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(0.03));
    canvas.drawRRect(
      rrect,
      _texture(_Tex.wood, metersPerImage: 1.6, rotation: math.pi / 2),
    );
    canvas
      ..drawRRect(
        rrect,
        Paint()
          ..shader = Gradient.linear(rect.topCenter, rect.bottomCenter, const [
            Color(0x26FFF4DC),
            Color(0x66000000),
          ]),
      )
      ..drawRRect(rrect, _edge)
      ..restore();
  }

  void _rope(Canvas canvas, Offset a, Offset b) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF6B5A3E)
        ..strokeWidth = 0.05,
    );
  }

  @override
  void drawCatapult(Canvas canvas, {required double armAngle}) {
    const pivot = Offset(0, -2.8);

    // Ground skids and frame.
    _beam(canvas, const Offset(-2.8, -0.2), const Offset(2.8, -0.2), 0.4);
    _beam(canvas, const Offset(-2.0, -0.35), const Offset(0.05, -3.05), 0.3);
    _beam(canvas, const Offset(2.0, -0.35), const Offset(-0.05, -3.05), 0.3);
    _beam(canvas, const Offset(-1.1, -1.5), const Offset(1.1, -1.5), 0.2);
    _beam(canvas, const Offset(-2.6, -0.35), const Offset(-0.9, -1.55), 0.18);

    // Throwing arm: long end carries the sling, short end the counterweight.
    final dir = Offset(math.sin(armAngle), -math.cos(armAngle));
    final tip = pivot + dir * 3.3;
    final heel = pivot - dir * 1.1;
    _beam(canvas, heel, tip, 0.2);

    // Counterweight box hangs straight down from the heel.
    final boxTop = heel + const Offset(0, 0.25);
    _rope(canvas, heel, boxTop);
    final box = Rect.fromCenter(
      center: boxTop + const Offset(0, 0.45),
      width: 0.95,
      height: 0.9,
    );
    final boxR = RRect.fromRectAndRadius(box, const Radius.circular(0.04));
    canvas.drawRRect(boxR, _texture(_Tex.planks, metersPerImage: 1.6));
    _shade(canvas, boxR);

    // Sling pouch at the tip.
    final pouch = Rect.fromCenter(center: tip, width: 0.75, height: 0.4);
    canvas.drawArc(
      pouch,
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.08
        ..color = const Color(0xFF4A3A28),
    );

    // Iron axle.
    canvas
      ..drawCircle(pivot, 0.16, _fill..color = const Color(0xFF3A3A3C))
      ..drawCircle(pivot, 0.07, _fill..color = const Color(0xFF8A8A8E));
  }

  @override
  void drawTrajectoryDot(Canvas canvas, Offset center, double opacity) {
    canvas.drawCircle(
      center,
      0.12,
      _fill..color = Color.fromRGBO(255, 250, 235, opacity * 0.9),
    );
  }

  @override
  void drawAimBand(Canvas canvas, Offset from, Offset to, double power) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF6B5A3E),
          const Color(0xFFA33A2E),
          power,
        )!
        ..strokeWidth = 0.09
        ..strokeCap = StrokeCap.round,
    );
  }
}
