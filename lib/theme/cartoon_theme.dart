import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart' show Vector2;
import 'package:flame/particles.dart';
import 'package:flutter/services.dart';

import '../core/materials.dart';
import '../core/weapons.dart';
import '../levels/level_data.dart';
import 'procedural_theme.dart';

/// The game's look: bright, clean, outlined cartoon art in the spirit of
/// Angry Birds. Painted castle towers and walls that crack in stages, a
/// soft sky with drifting clouds over snowy peaks, trees and bushes in
/// parallax, grassy soil, and chunky outlined blocks of wood, stone and
/// glass.
///
/// Castle and scenery art: CraftPix "Free Castle 2D Game Assets" and
/// "Free Cartoon Medieval Guard Post" (CraftPix free license).
class CartoonTheme extends ProceduralTheme {
  CartoonTheme._(this._img);

  static const _names = [
    'backdrop.jpg',
    'tower_0.png', 'tower_1.png', 'tower_2.png', //
    'tower_tall_0.png', 'tower_tall_1.png', 'tower_tall_2.png',
    'wall_0.png', 'wall_1.png', 'wall_2.png',
    'wall_brick_0.png', 'wall_brick_1.png', 'wall_brick_2.png',
    'tree_0.png', 'tree_1.png', 'bush.png', 'tuft_0.png', 'tuft_1.png',
    'rock_0.png', 'rock_1.png', 'rock_2.png', 'rock_3.png', 'rock_4.png',
    'ground_top.png', 'ground_fill.png', 'barrel.png', 'crate.png',
  ];

  static Future<CartoonTheme> load() async {
    final images = <String, ui.Image>{};
    for (final name in _names) {
      final data = await rootBundle.load('assets/images/cartoon/$name');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      images[name.split('.').first] = (await codec.getNextFrame()).image;
    }
    return CartoonTheme._(images);
  }

  final Map<String, ui.Image> _img;

  static const _outline = Color(0xFF2B1A0E);

  /// The sky colour along the top edge of the backdrop painting.
  static const _skyTop = Color(0xFF70E0D5);

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _outline;
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;

  void _draw(Canvas canvas, ui.Image image, Rect dst, {bool flip = false}) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    if (!flip) {
      canvas.drawImageRect(image, src, dst, _image);
      return;
    }
    canvas
      ..save()
      ..translate(dst.center.dx, 0)
      ..scale(-1, 1)
      ..translate(-dst.center.dx, 0)
      ..drawImageRect(image, src, dst, _image)
      ..restore();
  }

  /// A sprite standing on the ground at [x], [height] meters tall.
  void _stand(
    Canvas canvas,
    ui.Image image,
    double x,
    double height, {
    double ground = 0,
    bool flip = false,
  }) {
    final w = height * image.width / image.height;
    _draw(
      canvas,
      image,
      Rect.fromLTRB(x - w / 2, ground - height, x + w / 2, ground),
      flip: flip,
    );
  }

  // ------------------------------------------------------------ backdrop

  @override
  void drawBackground(
    Canvas canvas,
    Rect visible,
    double time, {
    Color? atmosphere,
  }) {
    // Snowy peaks and bushes, far away: mirrored tiles scroll slowly.
    final backdrop = _img['backdrop']!;
    const height = 11.0, parallax = 0.85, top = 0.4 - height;

    // Sky above the painted backdrop, deepening upward from the exact
    // colour at the top of the painting so there is no seam.
    canvas.drawRect(
      visible,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, math.min(visible.top, top - 12)),
          const Offset(0, top + 0.3),
          const [Color(0xFF3FA6DC), _skyTop],
        ),
    );

    final width = height * backdrop.width / backdrop.height;
    final shift = visible.center.dx * parallax;
    var i = ((visible.left - shift) / width).floor();
    for (; i * width + shift < visible.right; i++) {
      final left = i * width + shift;
      _draw(
        canvas,
        backdrop,
        Rect.fromLTWH(left, top, width + 0.05, height),
        flip: i.isOdd,
      );
    }

    _clouds(canvas, visible, time);

    // A row of trees and bushes between the peaks and the battlefield.
    final rowShift = visible.center.dx * 0.6;
    final rng = math.Random(5);
    for (var x = -120.0; x < 240; x += 11 + rng.nextDouble() * 14) {
      final kind = rng.nextInt(5);
      final at = x + rowShift;
      final flip = rng.nextBool();
      final size = rng.nextDouble();
      if (at < visible.left - 8 || at > visible.right + 8) continue;
      if (kind < 2) {
        _stand(
          canvas,
          _img['tree_$kind']!,
          at,
          3.2 + size * 1.5,
          ground: 0.4,
          flip: flip,
        );
      } else {
        _stand(
          canvas,
          _img['bush']!,
          at,
          0.9 + size * 0.6,
          ground: 0.3,
          flip: flip,
        );
      }
    }
  }

  /// Puffy clouds drifting slowly across, a little behind the camera.
  void _clouds(Canvas canvas, Rect visible, double time) {
    const wrap = 180.0;
    final rng = math.Random(21);
    final shift = visible.center.dx * 0.9 + time * 0.6;
    for (var i = 0; i < 7; i++) {
      final base = rng.nextDouble() * wrap;
      final y = visible.top + 1.5 + rng.nextDouble() * visible.height * 0.3;
      final w = 3.5 + rng.nextDouble() * 3.5;
      final x = visible.left - 20 + ((base + shift) % wrap);
      if (x - w > visible.right) continue;
      final puff = Path();
      final lobes = 4 + rng.nextInt(3);
      for (var k = 0; k < lobes; k++) {
        final r = w * (0.16 + rng.nextDouble() * 0.12);
        final cx = x + (k / (lobes - 1) - 0.5) * w * 0.8;
        puff.addOval(
          Rect.fromCircle(
            center: Offset(cx, y - r * 0.5 * rng.nextDouble()),
            radius: r,
          ),
        );
      }
      puff.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, y + w * 0.08),
            width: w,
            height: w * 0.22,
          ),
          Radius.circular(w * 0.11),
        ),
      );
      final b = puff.getBounds();
      canvas.drawPath(
        puff,
        Paint()
          ..shader = Gradient.linear(b.topCenter, b.bottomCenter, const [
            Color(0xFFFFFFFF),
            Color(0xFFDDEFF6),
          ]),
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
          size.longestSide * 0.7,
          const [Color(0x00000000), Color(0x00000000), Color(0x33000000)],
          const [0, 0.7, 1],
        ),
    );
  }

  // ------------------------------------------------------------ ground

  Paint _tiles(ui.Image image, double meters, Offset origin) {
    final k = meters / image.width;
    return Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList([
          k, 0, 0, 0, //
          0, k, 0, 0,
          0, 0, 1, 0,
          origin.dx, origin.dy, 0, 1,
        ]),
      );
  }

  @override
  void drawGround(Canvas canvas, Rect rect) {
    const tile = 2.4;
    // Soil below, then the grassy top row whose lip sits on the surface.
    canvas.drawRect(
      Rect.fromLTRB(rect.left, rect.top + tile * 0.5, rect.right, rect.bottom),
      _tiles(_img['ground_fill']!, tile, Offset(rect.left, rect.top)),
    );
    final lip = tile * 0.12;
    canvas.drawRect(
      Rect.fromLTRB(
        rect.left,
        rect.top - lip,
        rect.right,
        rect.top - lip + tile,
      ),
      _tiles(_img['ground_top']!, tile, Offset(rect.left, rect.top - lip)),
    );
  }

  @override
  void drawGroundDetail(Canvas canvas, Rect visible) {
    final rng = math.Random(9);
    for (var x = -60.0; x < 200; x += 1.5 + rng.nextDouble() * 4) {
      final pick = rng.nextInt(10);
      final flip = rng.nextBool();
      if (x < visible.left - 3 || x > visible.right + 3) continue;
      if (pick < 6) {
        _stand(
          canvas,
          _img['tuft_${pick % 2}']!,
          x,
          0.45 + rng.nextDouble() * 0.2,
          ground: 0.08,
          flip: flip,
        );
      } else if (pick < 8) {
        _stand(
          canvas,
          _img['rock_${2 + pick % 3}']!,
          x,
          0.3 + rng.nextDouble() * 0.2,
          ground: 0.12,
          flip: flip,
        );
      }
    }
  }

  // ------------------------------------------------------------ blocks

  /// The painted art for a fortress piece at a damage stage (0–2).
  ui.Image? _fortArt(String? look, int stage, Size size) {
    if (look == null) return null;
    final s = stage.clamp(0, 2);
    return switch (look) {
      'tower' => _img['tower_$s'],
      'gate' => _img['wall_brick_$s'],
      // Long low pieces (lintels) use the brick-banded wall.
      _ =>
        size.width > size.height * 2 ? _img['wall_brick_$s'] : _img['wall_$s'],
    };
  }

  /// Draws fortress art over a block of [size], tiling wide pieces so their
  /// battlements keep their shape.
  void _drawFort(Canvas canvas, ui.Image image, Size size) {
    final aspect = image.width / image.height;
    final count = math.max(1, (size.width / (size.height * aspect)).round());
    final w = size.width / count;
    for (var i = 0; i < count; i++) {
      _draw(
        canvas,
        image,
        Rect.fromLTWH(
          -size.width / 2 + i * w - 0.02,
          -size.height / 2,
          w + 0.04,
          size.height,
        ),
      );
    }
  }

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
    final art = _fortArt(look, crackStage, size);
    if (art != null) {
      _drawFort(canvas, art, size);
      if (char > 0) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width,
            height: size.height,
          ),
          Paint()
            ..blendMode = BlendMode.multiply
            ..color = Color.lerp(
              const Color(0xFFFFFFFF),
              const Color(0xFF3A2A20),
              char,
            )!,
        );
      }
      return;
    }
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final shape = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(0.12, size.shortestSide * 0.2)),
    );
    final (light, dark) = switch (material) {
      BlockMaterial.wood => (const Color(0xFFE9A24E), const Color(0xFFB8702C)),
      BlockMaterial.stone => (const Color(0xFFB9BDC2), const Color(0xFF858A91)),
      BlockMaterial.glass => (const Color(0xCCBDEFFF), const Color(0xAA7FCDEB)),
    };
    canvas.drawRRect(
      shape,
      _fill
        ..shader = Gradient.linear(rect.topLeft, rect.bottomRight, [
          Color.lerp(light, const Color(0xFF3A2A20), char * 0.8)!,
          Color.lerp(dark, const Color(0xFF241810), char * 0.8)!,
        ]),
    );
    _fill.shader = null;

    final rng = math.Random(seed);
    canvas
      ..save()
      ..clipRRect(shape);
    switch (material) {
      case BlockMaterial.wood:
        // Grain along the long side.
        final grain = Paint()
          ..color = const Color(0x557A4418)
          ..strokeWidth = 0.035
          ..strokeCap = StrokeCap.round;
        final alongX = size.width >= size.height;
        for (var k = 1; k < 4; k++) {
          final t = k / 4 + (rng.nextDouble() - 0.5) * 0.08;
          if (alongX) {
            final y = rect.top + rect.height * t;
            canvas.drawLine(
              Offset(rect.left + 0.1, y),
              Offset(rect.right - 0.1, y),
              grain,
            );
          } else {
            final x = rect.left + rect.width * t;
            canvas.drawLine(
              Offset(x, rect.top + 0.1),
              Offset(x, rect.bottom - 0.1),
              grain,
            );
          }
        }
      case BlockMaterial.stone:
        // Masonry joints.
        final joint = Paint()
          ..color = const Color(0x66505560)
          ..strokeWidth = 0.035;
        const course = 0.5;
        for (var y = rect.top + course; y < rect.bottom; y += course) {
          canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), joint);
        }
        var row = 0;
        for (var y = rect.top; y < rect.bottom; y += course, row++) {
          for (
            var x = rect.left + (row.isOdd ? 0.45 : 0.9);
            x < rect.right;
            x += 0.9
          ) {
            canvas.drawLine(
              Offset(x, y),
              Offset(x, math.min(rect.bottom, y + course)),
              joint,
            );
          }
        }
      case BlockMaterial.glass:
        // A bright glint.
        canvas.drawLine(
          rect.topLeft + Offset(rect.width * 0.25, rect.height * 0.15),
          rect.topLeft + Offset(rect.width * 0.15, rect.height * 0.55),
          Paint()
            ..color = const Color(0xCCFFFFFF)
            ..strokeWidth = math.min(0.12, rect.width * 0.18)
            ..strokeCap = StrokeCap.round,
        );
    }
    // Top highlight for a chunky, lit look.
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        rect.top,
        rect.width,
        math.min(0.12, rect.height * 0.2),
      ),
      _fill..color = const Color(0x33FFFFFF),
    );
    _cracks(canvas, rect, crackStage, rng);
    canvas.restore();
    canvas.drawRRect(
      shape,
      _line
        ..strokeWidth = 0.07
        ..color = material == BlockMaterial.glass
            ? const Color(0xFF3F84A6)
            : _outline,
    );
  }

  void _cracks(Canvas canvas, Rect rect, int stage, math.Random rng) {
    if (stage <= 0) return;
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xCC2B1A0E);
    for (var n = 0; n < stage * 2; n++) {
      var p = Offset(
        rect.left + rect.width * rng.nextDouble(),
        rect.top + rect.height * rng.nextDouble(),
      );
      final path = Path()..moveTo(p.dx, p.dy);
      final dir = rng.nextDouble() * math.pi * 2;
      for (var k = 0; k < 4; k++) {
        final a = dir + (rng.nextDouble() - 0.5) * 1.2;
        p += Offset(math.cos(a), math.sin(a)) * (0.12 + rng.nextDouble() * 0.2);
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
    final size = blockSize;
    final art = size == null ? null : _fortArt(look, crackStage, size);
    if (art != null) {
      // Cut the piece out of the block's own painting.
      canvas
        ..save()
        ..clipPath(path)
        ..translate(-offset.dx, -offset.dy);
      _drawFort(canvas, art, size!);
      canvas.restore();
    } else {
      final (light, dark) = switch (material) {
        BlockMaterial.wood => (
          const Color(0xFFE9A24E),
          const Color(0xFFB8702C),
        ),
        BlockMaterial.stone => (
          const Color(0xFFB9BDC2),
          const Color(0xFF858A91),
        ),
        BlockMaterial.glass => (
          const Color(0xCCBDEFFF),
          const Color(0xAA7FCDEB),
        ),
      };
      final b = path.getBounds();
      canvas.drawPath(
        path,
        _fill
          ..shader = Gradient.linear(b.topLeft, b.bottomRight, [light, dark]),
      );
      _fill.shader = null;
    }
    canvas.drawPath(
      path,
      _line
        ..strokeWidth = 0.05
        ..color = _outline,
    );
  }

  // ------------------------------------------------------------ catapult

  /// A chunky wooden plank from [a] to [b].
  void _plank(Canvas canvas, Offset a, Offset b, double width) {
    final d = b - a;
    final length = d.distance;
    canvas
      ..save()
      ..translate(a.dx, a.dy)
      ..rotate(math.atan2(d.dy, d.dx));
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(-width * 0.3, -width / 2, length + width * 0.6, width),
      Radius.circular(width * 0.3),
    );
    canvas
      ..drawRRect(
        r,
        _fill
          ..shader = Gradient.linear(
            Offset(0, -width / 2),
            Offset(0, width / 2),
            const [Color(0xFFD08A45), Color(0xFF9A5A26)],
          ),
      )
      ..drawLine(
        Offset(0, -width * 0.1),
        Offset(length, -width * 0.1),
        Paint()
          ..color = const Color(0x44FFE0B0)
          ..strokeWidth = width * 0.18,
      )
      ..drawRRect(
        r,
        _line
          ..strokeWidth = 0.08
          ..color = _outline,
      )
      ..restore();
    _fill.shader = null;
  }

  void _wheel(Canvas canvas, Offset c, double r) {
    canvas
      ..drawCircle(c, r, _fill..color = const Color(0xFF8A5226))
      ..drawCircle(c, r * 0.72, _fill..color = const Color(0xFFB57236));
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 4;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.7,
        c - Offset(math.cos(a), math.sin(a)) * r * 0.7,
        _line
          ..strokeWidth = 0.07
          ..color = const Color(0xFF5A3214),
      );
    }
    canvas
      ..drawCircle(
        c,
        r,
        _line
          ..strokeWidth = 0.08
          ..color = _outline,
      )
      ..drawCircle(c, r * 0.18, _fill..color = const Color(0xFF3A3A40));
  }

  @override
  void drawSiegeEngine(
    Canvas canvas,
    WeaponType type, {
    required double armAngle,
    required double aimAngle,
  }) {
    if (type != WeaponType.catapult) {
      super.drawSiegeEngine(
        canvas,
        type,
        armAngle: armAngle,
        aimAngle: aimAngle,
      );
      return;
    }
    const pivot = Offset(0, -2.8);
    // Rear frame first, then the arm, then the near frame and wheels.
    _plank(canvas, const Offset(1.3, -0.9), const Offset(0.1, -3.0), 0.3);
    _plank(canvas, const Offset(0.1, -3.0), const Offset(1.3, -3.9), 0.24);
    final dir = Offset(math.sin(armAngle), -math.cos(armAngle));
    final tip = pivot + dir * 3.3;
    _plank(canvas, pivot - dir * 0.3, tip, 0.26);
    // Bucket.
    canvas
      ..save()
      ..translate(tip.dx, tip.dy)
      ..rotate(armAngle);
    final cup = Path()
      ..addArc(const Rect.fromLTRB(-0.5, -0.45, 0.5, 0.45), 0, math.pi)
      ..close();
    canvas
      ..drawPath(cup, _fill..color = const Color(0xFF9A5A26))
      ..drawPath(
        cup,
        _line
          ..strokeWidth = 0.08
          ..color = _outline,
      )
      ..restore();
    _plank(canvas, const Offset(-2.4, -0.9), const Offset(2.4, -0.9), 0.42);
    _plank(canvas, const Offset(-1.3, -0.9), const Offset(-0.1, -3.0), 0.32);
    canvas
      ..drawCircle(pivot, 0.2, _fill..color = const Color(0xFF3A3A40))
      ..drawCircle(
        pivot,
        0.2,
        _line
          ..strokeWidth = 0.06
          ..color = _outline,
      );
    _wheel(canvas, const Offset(-1.6, -0.55), 0.55);
    _wheel(canvas, const Offset(1.6, -0.55), 0.55);
  }

  // ------------------------------------------------------------ aiming

  @override
  void drawTrajectoryDot(Canvas canvas, Offset center, double opacity) {
    canvas
      ..drawCircle(
        center,
        0.17,
        _fill..color = Color.fromRGBO(43, 26, 14, 0.5 * opacity),
      )
      ..drawCircle(
        center,
        0.13,
        _fill..color = Color.fromRGBO(255, 255, 255, opacity),
      );
  }

  @override
  void drawAimBand(Canvas canvas, Offset from, Offset to, double power) {
    final band = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.22
      ..color = _outline;
    canvas
      ..drawLine(from, to, band)
      ..drawLine(
        from,
        to,
        band
          ..strokeWidth = 0.12
          ..color = Color.lerp(
            const Color(0xFF8A5A2E),
            const Color(0xFFE0493A),
            power,
          )!,
      );
  }

  // ------------------------------------------------------------ particles

  static final _particlePaint = Paint()..isAntiAlias = true;
  static final _particleLine = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  /// A cartoon "poof": a round cloud that swells, then shrinks away.
  Particle _poof(
    math.Random rng, {
    required Size spread,
    double scale = 1,
    Color color = const Color(0xFFF4EEE2),
    double? life,
  }) {
    final lifespan = life ?? 0.55 + rng.nextDouble() * 0.35;
    final r0 = (0.3 + rng.nextDouble() * 0.35) * scale;
    return AcceleratedParticle(
      lifespan: lifespan,
      position: Vector2(
        (rng.nextDouble() - 0.5) * spread.width,
        (rng.nextDouble() - 0.5) * spread.height,
      ),
      speed:
          Vector2((rng.nextDouble() - 0.5) * 3, -0.5 - rng.nextDouble() * 1.5) *
          scale,
      child: ComputedParticle(
        lifespan: lifespan,
        renderer: (canvas, p) {
          final t = p.progress;
          // Swell fast, linger, then shrink to nothing.
          final grow = t < 0.3 ? t / 0.3 : 1 - (t - 0.3) / 0.7 * 0.9;
          final r = r0 * (0.4 + 0.8 * grow);
          canvas
            ..drawCircle(
              Offset.zero,
              r + 0.04,
              _particlePaint..color = const Color(0x552B1A0E),
            )
            ..drawCircle(Offset.zero, r, _particlePaint..color = color)
            ..drawCircle(
              Offset(-r * 0.3, -r * 0.3),
              r * 0.35,
              _particlePaint..color = const Color(0x66FFFFFF),
            );
        },
      ),
    );
  }

  /// A small outlined fragment thrown out by a hit.
  Particle _bit(
    math.Random rng,
    Color color, {
    required Size spread,
    double speed = 6,
  }) {
    final lifespan = 0.8 + rng.nextDouble() * 0.6;
    final size = 0.12 + rng.nextDouble() * 0.2;
    final spin = (rng.nextDouble() - 0.5) * 16;
    final dir = Vector2(rng.nextDouble() - 0.5, -rng.nextDouble() * 0.9 - 0.1)
      ..normalize();
    final shape = Path()
      ..moveTo(-size / 2, -size * 0.3)
      ..lineTo(size * 0.4, -size * 0.45)
      ..lineTo(size / 2, size * 0.35)
      ..lineTo(-size * 0.3, size * 0.4)
      ..close();
    return AcceleratedParticle(
      lifespan: lifespan,
      position: Vector2(
        (rng.nextDouble() - 0.5) * spread.width,
        (rng.nextDouble() - 0.5) * spread.height,
      ),
      speed: dir * (speed * (0.5 + rng.nextDouble())),
      acceleration: Vector2(0, 14),
      child: ComputedParticle(
        lifespan: lifespan,
        renderer: (canvas, p) {
          final t = p.progress;
          final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
          canvas
            ..save()
            ..rotate(spin * t * lifespan)
            ..drawPath(
              shape,
              _particlePaint..color = color.withValues(alpha: color.a * fade),
            )
            ..drawPath(
              shape,
              _particleLine
                ..strokeWidth = 0.035
                ..color = _outline.withValues(alpha: fade),
            )
            ..restore();
        },
      ),
    );
  }

  static Color _materialColor(BlockMaterial m) => switch (m) {
    BlockMaterial.wood => const Color(0xFFD98A3E),
    BlockMaterial.stone => const Color(0xFFB4B8BE),
    BlockMaterial.glass => const Color(0xDDBDEFFF),
  };

  @override
  Particle breakParticles(BlockMaterial material, Size size, math.Random rng) {
    final area = size.width * size.height;
    final poofs = (4 + area * 1.5).clamp(4, 14).round();
    final bits = (8 + area * 4).clamp(8, 24).round();
    return ComposedParticle(
      children: [
        for (var i = 0; i < poofs; i++)
          _poof(
            rng,
            spread: size,
            scale: 1.2,
            color: material == BlockMaterial.glass
                ? const Color(0xFFE6F8FF)
                : const Color(0xFFF4EEE2),
          ),
        for (var i = 0; i < bits; i++)
          _bit(rng, _materialColor(material), spread: size),
      ],
    );
  }

  @override
  Particle impactParticles(double strength, math.Random rng) {
    final s = strength.clamp(0.3, 1.5);
    return ComposedParticle(
      children: [
        for (var i = 0; i < (2 + 3 * s).round(); i++)
          _poof(rng, spread: const Size(0.6, 0.6), scale: 0.7 * s),
        for (var i = 0; i < (2 + 4 * s).round(); i++)
          _bit(
            rng,
            const Color(0xFF8C6A4A),
            spread: const Size(0.4, 0.4),
            speed: 5 * s,
          ),
      ],
    );
  }

  @override
  Particle unitDeathParticles(UnitKind kind, math.Random rng) =>
      ComposedParticle(
        children: [
          for (var i = 0; i < 8; i++)
            _poof(rng, spread: const Size(1.2, 1.4), scale: 1.4),
          if (kind.isRoyal)
            for (var i = 0; i < 8; i++)
              _bit(
                rng,
                const Color(0xFFFFD34D),
                spread: const Size(0.6, 0.6),
                speed: 7,
              ),
        ],
      );

  @override
  Particle trailParticle(math.Random rng) => _poof(
    rng,
    spread: const Size(0.15, 0.15),
    scale: 0.35,
    color: const Color(0xFFFFFFFF),
    life: 0.5,
  );
}
