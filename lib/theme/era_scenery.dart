import 'dart:math' as math;
import 'dart:ui';

import '../core/era.dart';

/// The landscape behind a siege, painted per era in the game's outlined
/// cartoon style: Egypt's dunes and pyramids, Persia's golden sands and a
/// city of domes, China's misty karst peaks and bamboo, the Medieval
/// west's misty hills and pine forests, and the Iron King's storm-lit
/// crags and floating rocks.
///
/// Each era is a sky and three parallax layers. A layer is recorded once
/// as a picture a fixed width wide and tiled as the camera moves, so the
/// cost per frame is a few picture draws.
class EraScenery {
  EraScenery._();

  /// Whether [era] has its own painted landscape (others use the default
  /// backdrop).
  static bool paints(Era era) => _looks.containsKey(era);

  static const _wrap = 160.0;
  static const _outline = Color(0xFF2B1A0E);

  static final Map<(Era, int), Picture> _cache = {};

  static final Map<Era, _Look> _looks = {
    Era.egypt: _Look(
      skyTop: const Color(0xFF4AA8E0),
      skyHorizon: const Color(0xFFF6E2AE),
      sun: const Color(0xFFFFF1B8),
      layers: [(0.9, _egyptFar), (0.75, _egyptMid), (0.55, _egyptNear)],
    ),
    Era.persia: _Look(
      skyTop: const Color(0xFF5DB2E3),
      skyHorizon: const Color(0xFFF7C98A),
      sun: const Color(0xFFFFE3A0),
      layers: [(0.9, _persiaFar), (0.75, _persiaMid), (0.55, _persiaNear)],
    ),
    Era.china: _Look(
      skyTop: const Color(0xFF6FB7D8),
      skyHorizon: const Color(0xFFF2E6C8),
      sun: const Color(0xFFFFD8B0),
      layers: [(0.9, _chinaFar), (0.75, _chinaMid), (0.55, _chinaNear)],
    ),
    Era.medieval: _Look(
      skyTop: const Color(0xFF7F9CB5),
      skyHorizon: const Color(0xFFD9E1E4),
      layers: [
        (0.9, _medievalFar),
        (0.75, _medievalMid),
        (0.55, _medievalNear),
      ],
    ),
    Era.mythic: _Look(
      skyTop: const Color(0xFF2A2244),
      skyHorizon: const Color(0xFF9A86B8),
      sun: const Color(0xFFD9C8FF),
      layers: [(0.9, _mythicFar), (0.75, _mythicMid), (0.55, _mythicNear)],
    ),
  };

  /// Draws the era's sky and far layers; [clouds] is called between the
  /// far layer and the nearer ones.
  static void draw(
    Canvas canvas,
    Rect visible,
    double time,
    Era era,
    void Function() clouds,
  ) {
    final look = _looks[era]!;
    canvas.drawRect(
      visible,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, math.min(visible.top, -20)),
          const Offset(0, -1),
          [look.skyTop, look.skyHorizon],
        ),
    );
    final sun = look.sun;
    if (sun != null) {
      final c = Offset(visible.center.dx * 0.97 + 18, -14);
      canvas
        ..drawCircle(
          c,
          5,
          Paint()
            ..shader = Gradient.radial(c, 5, [
              sun.withValues(alpha: 0.6),
              sun.withValues(alpha: 0),
            ]),
        )
        ..drawCircle(c, 1.6, Paint()..color = sun);
    }
    for (final (i, (parallax, build)) in look.layers.indexed) {
      if (i == 1) clouds();
      final picture = _cache[(era, i)] ??= _record(build);
      final shift = visible.center.dx * parallax;
      var k = ((visible.left - shift) / _wrap).floor();
      for (; k * _wrap + shift < visible.right; k++) {
        canvas
          ..save()
          ..translate(k * _wrap + shift, 0)
          ..drawPicture(picture)
          ..restore();
      }
    }
  }

  static Picture _record(void Function(Canvas) build) {
    final recorder = PictureRecorder();
    build(Canvas(recorder));
    return recorder.endRecording();
  }

  // ------------------------------------------------------------ helpers

  static final _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _outline;

  static void _shape(Canvas canvas, Path path, Color fill, {double w = 0.08}) {
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(path, _line..strokeWidth = w);
  }

  /// A rolling ridge across the whole tile, from [base] up to [amp] high,
  /// seamless at the tile's edges.
  static Path _ridge(double base, double amp, int waves, int seed) {
    final rng = math.Random(seed);
    final phases = [for (var i = 0; i < 3; i++) rng.nextDouble() * math.pi * 2];
    final path = Path()..moveTo(0, 4);
    for (var x = 0.0; x <= _wrap; x += 0.5) {
      final u = x / _wrap * math.pi * 2;
      final y =
          base -
          amp *
              (0.55 +
                  0.3 * math.sin(u * waves + phases[0]) +
                  0.15 * math.sin(u * waves * 2 + phases[1]));
      path.lineTo(x, y);
    }
    return path
      ..lineTo(_wrap, 4)
      ..close();
  }

  static void _palm(Canvas canvas, double x, double base, double h) {
    final lean = h * 0.12;
    final trunk = Path()
      ..moveTo(x - 0.15, base)
      ..quadraticBezierTo(x - 0.1, base - h * 0.5, x + lean, base - h)
      ..lineTo(x + lean + 0.18, base - h)
      ..quadraticBezierTo(x + 0.12, base - h * 0.5, x + 0.18, base)
      ..close();
    _shape(canvas, trunk, const Color(0xFF9A6A3A), w: 0.06);
    final top = Offset(x + lean + 0.09, base - h);
    for (var i = 0; i < 6; i++) {
      final a = -math.pi * (0.05 + i * 0.18);
      final tip = top + Offset(math.cos(a) * h * 0.42, math.sin(a) * h * 0.18);
      final droop = Offset(tip.dx, tip.dy + h * 0.14);
      final frond = Path()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(tip.dx, tip.dy - h * 0.05, droop.dx, droop.dy)
        ..quadraticBezierTo(
          (top.dx + droop.dx) / 2,
          (top.dy + droop.dy) / 2 + h * 0.02,
          top.dx,
          top.dy + 0.1,
        )
        ..close();
      _shape(canvas, frond, const Color(0xFF4E9A3C), w: 0.05);
    }
  }

  static void _pine(Canvas canvas, double x, double base, double h, Color c) {
    canvas.drawRect(
      Rect.fromLTRB(x - 0.12, base - h * 0.2, x + 0.12, base),
      Paint()..color = const Color(0xFF5A3A22),
    );
    for (var i = 0; i < 3; i++) {
      final y = base - h * (0.18 + i * 0.26);
      final w = h * (0.34 - i * 0.08);
      final tier = Path()
        ..moveTo(x - w, y)
        ..lineTo(x, y - h * 0.42)
        ..lineTo(x + w, y)
        ..close();
      _shape(canvas, tier, c, w: 0.05);
    }
  }

  // ------------------------------------------------------------ Egypt

  static void _egyptFar(Canvas canvas) {
    final rng = math.Random(11);
    for (var x = 12.0; x < _wrap - 10; x += 26 + rng.nextDouble() * 20) {
      final h = 5 + rng.nextDouble() * 4;
      final lit = Path()
        ..moveTo(x - h, -0.6)
        ..lineTo(x, -0.6 - h)
        ..lineTo(x + h * 0.35, -0.6)
        ..close();
      final shade = Path()
        ..moveTo(x, -0.6 - h)
        ..lineTo(x + h, -0.6)
        ..lineTo(x + h * 0.35, -0.6)
        ..close();
      canvas
        ..drawPath(lit, Paint()..color = const Color(0xFFE9C987))
        ..drawPath(shade, Paint()..color = const Color(0xFFC9A061));
      final outline = Path()
        ..moveTo(x - h, -0.6)
        ..lineTo(x, -0.6 - h)
        ..lineTo(x + h, -0.6);
      canvas.drawPath(outline, _line..strokeWidth = 0.08);
    }
    _shape(canvas, _ridge(-0.2, 2.4, 3, 1), const Color(0xFFEFD39A));
  }

  static void _egyptMid(Canvas canvas) {
    _shape(canvas, _ridge(0.1, 3.0, 4, 2), const Color(0xFFE6BD73));
    final rng = math.Random(12);
    for (var x = 6.0; x < _wrap - 6; x += 14 + rng.nextDouble() * 22) {
      for (var k = 0; k < 1 + rng.nextInt(3); k++) {
        _palm(canvas, x + k * 1.4, -1.0, 3.2 + rng.nextDouble() * 1.4);
      }
    }
  }

  static void _egyptNear(Canvas canvas) {
    _shape(canvas, _ridge(0.4, 1.6, 6, 3), const Color(0xFFDBA95E));
  }

  // ------------------------------------------------------------ Persia

  static void _persiaFar(Canvas canvas) {
    _shape(canvas, _ridge(-0.6, 1.6, 3, 21), const Color(0xFFEBC08E));
    // A far city of domes and minarets on the skyline.
    final rng = math.Random(22);
    for (var x = 14.0; x < _wrap - 12; x += 34 + rng.nextDouble() * 16) {
      const wall = Color(0xFFD9B28A);
      const tile = Color(0xFF6CC2C6);
      _shape(
        canvas,
        Path()..addRect(Rect.fromLTRB(x - 6, -3.2, x + 6, -1.2)),
        wall,
        w: 0.06,
      );
      for (final (dx, r) in [(-3.0, 1.3), (0.0, 2.0), (3.2, 1.1)]) {
        final c = Offset(x + dx, -3.2);
        final dome = Path()
          ..moveTo(c.dx - r, c.dy)
          ..cubicTo(
            c.dx - r * 1.1,
            c.dy - r * 1.2,
            c.dx - r * 0.1,
            c.dy - r * 1.3,
            c.dx,
            c.dy - r * 1.7,
          )
          ..cubicTo(
            c.dx + r * 0.1,
            c.dy - r * 1.3,
            c.dx + r * 1.1,
            c.dy - r * 1.2,
            c.dx + r,
            c.dy,
          )
          ..close();
        _shape(canvas, dome, tile, w: 0.06);
      }
      for (final dx in [-7.5, 7.5]) {
        _shape(
          canvas,
          Path()
            ..addRect(Rect.fromLTRB(x + dx - 0.4, -7.5, x + dx + 0.4, -1.2)),
          wall,
          w: 0.06,
        );
        _shape(
          canvas,
          Path()
            ..moveTo(x + dx - 0.55, -7.5)
            ..lineTo(x + dx, -8.6)
            ..lineTo(x + dx + 0.55, -7.5)
            ..close(),
          tile,
          w: 0.06,
        );
      }
    }
  }

  static void _persiaMid(Canvas canvas) {
    _shape(canvas, _ridge(0.1, 2.8, 4, 23), const Color(0xFFE3A868));
    final rng = math.Random(24);
    for (var x = 10.0; x < _wrap - 6; x += 18 + rng.nextDouble() * 24) {
      for (var k = 0; k < 1 + rng.nextInt(2); k++) {
        _palm(canvas, x + k * 1.5, -0.9, 3.0 + rng.nextDouble() * 1.6);
      }
    }
  }

  static void _persiaNear(Canvas canvas) {
    _shape(canvas, _ridge(0.4, 1.5, 6, 25), const Color(0xFFD38F52));
  }

  // ------------------------------------------------------------ China

  /// Tall rounded karst peaks rising out of the mist.
  static void _karst(
    Canvas canvas,
    double x,
    double base,
    double h,
    double w,
    Color c,
  ) {
    final peak = Path()
      ..moveTo(x - w, base)
      ..cubicTo(x - w * 0.9, base - h * 0.7, x - w * 0.6, base - h, x, base - h)
      ..cubicTo(x + w * 0.6, base - h, x + w * 0.9, base - h * 0.7, x + w, base)
      ..close();
    _shape(canvas, peak, c, w: 0.06);
  }

  static void _chinaFar(Canvas canvas) {
    final rng = math.Random(41);
    for (var x = 4.0; x < _wrap - 4; x += 7 + rng.nextDouble() * 9) {
      _karst(
        canvas,
        x,
        0,
        8 + rng.nextDouble() * 7,
        2.5 + rng.nextDouble() * 1.5,
        const Color(0xFFA9C2B6),
      );
    }
    // A pagoda on a far peak.
    for (final x in [40.0, 120.0]) {
      const red = Color(0xFFB0453A), roof = Color(0xFF4E7A62);
      for (var i = 0; i < 4; i++) {
        final y = -6.0 - i * 1.6;
        final w = 1.8 - i * 0.3;
        _shape(
          canvas,
          Path()..addRect(Rect.fromLTRB(x - w * 0.5, y, x + w * 0.5, y + 1.0)),
          red,
          w: 0.05,
        );
        _shape(
          canvas,
          Path()
            ..moveTo(x - w - 0.4, y + 0.1)
            ..quadraticBezierTo(x - w * 0.4, y - 0.1, x, y - 0.6)
            ..quadraticBezierTo(x + w * 0.4, y - 0.1, x + w + 0.4, y + 0.1)
            ..close(),
          roof,
          w: 0.05,
        );
      }
    }
    // Mist over the far peaks' feet.
    canvas.drawRect(
      const Rect.fromLTRB(0, -3.5, _wrap, 1),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, -3.5),
          const Offset(0, 0),
          const [Color(0x00F2E6C8), Color(0xCCF2E6C8)],
        ),
    );
  }

  static void _bamboo(Canvas canvas, double x, double base, double h) {
    final cane = Paint()
      ..color = const Color(0xFF6FA54A)
      ..strokeWidth = 0.22
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, base), Offset(x + h * 0.06, base - h), cane);
    final node = Paint()
      ..color = const Color(0xFF3E6E2A)
      ..strokeWidth = 0.05;
    for (var y = 0.8; y < h; y += 0.8) {
      final px = x + h * 0.06 * (y / h);
      canvas.drawLine(
        Offset(px - 0.12, base - y),
        Offset(px + 0.12, base - y),
        node,
      );
    }
    final leaf = Paint()..color = const Color(0xFF4E9A3C);
    for (var i = 0; i < 4; i++) {
      final at = Offset(
        x + h * 0.06 * (1 - i * 0.15),
        base - h * (1 - i * 0.15),
      );
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..quadraticBezierTo(
            at.dx + 0.9 * (i.isEven ? 1 : -1),
            at.dy - 0.3,
            at.dx + 1.4 * (i.isEven ? 1 : -1),
            at.dy + 0.3,
          )
          ..quadraticBezierTo(
            at.dx + 0.6 * (i.isEven ? 1 : -1),
            at.dy + 0.1,
            at.dx,
            at.dy,
          )
          ..close(),
        leaf,
      );
    }
  }

  static void _chinaMid(Canvas canvas) {
    _shape(canvas, _ridge(0.0, 2.6, 3, 42), const Color(0xFF7FB27A));
    final rng = math.Random(43);
    for (var x = 3.0; x < _wrap - 3; x += 9 + rng.nextDouble() * 12) {
      for (var k = 0; k < 3 + rng.nextInt(4); k++) {
        _bamboo(canvas, x + k * 0.55, -1.2, 4 + rng.nextDouble() * 2.5);
      }
    }
  }

  static void _chinaNear(Canvas canvas) {
    _shape(canvas, _ridge(0.4, 1.3, 5, 44), const Color(0xFF5E9E5A));
  }

  // ------------------------------------------------------------ Medieval

  static void _medievalFar(Canvas canvas) {
    _shape(canvas, _ridge(-1.0, 5.0, 2, 31), const Color(0xFFA9BAC2), w: 0.05);
    // A distant castle on a hill, grey in the mist.
    const grey = Color(0xFF8C9DA8);
    for (final x in [18.0, 58.0, 98.0, 138.0]) {
      final base = -6.0;
      _shape(
        canvas,
        Path()..addRect(Rect.fromLTRB(x - 4, base - 2.2, x + 4, base + 1)),
        grey,
        w: 0.05,
      );
      for (final dx in [-4.6, 0.0, 4.6]) {
        final h = dx == 0 ? 5.0 : 3.6;
        _shape(
          canvas,
          Path()..addRect(
            Rect.fromLTRB(x + dx - 0.9, base - h, x + dx + 0.9, base),
          ),
          grey,
          w: 0.05,
        );
        _shape(
          canvas,
          Path()
            ..moveTo(x + dx - 1.1, base - h)
            ..lineTo(x + dx, base - h - 1.6)
            ..lineTo(x + dx + 1.1, base - h)
            ..close(),
          const Color(0xFF6E7F8A),
          w: 0.05,
        );
      }
    }
  }

  static void _medievalMid(Canvas canvas) {
    _shape(canvas, _ridge(0.0, 3.2, 3, 32), const Color(0xFF6F9A5E));
    final rng = math.Random(33);
    for (var x = 2.0; x < _wrap - 2; x += 1.6 + rng.nextDouble() * 3) {
      _pine(
        canvas,
        x,
        -1.6 - rng.nextDouble() * 1.2,
        3 + rng.nextDouble() * 2,
        const Color(0xFF4B7A4E),
      );
    }
  }

  static void _medievalNear(Canvas canvas) {
    _shape(canvas, _ridge(0.5, 1.2, 5, 34), const Color(0xFF4F7F44));
    final rng = math.Random(35);
    for (var x = 4.0; x < _wrap - 4; x += 5 + rng.nextDouble() * 9) {
      _pine(
        canvas,
        x,
        0.2,
        3.8 + rng.nextDouble() * 2.2,
        const Color(0xFF2F6040),
      );
    }
  }

  // ------------------------------------------------------------ Mythic

  /// Jagged crags: a saw-toothed ridge, seamless at the tile's edges.
  static Path _crags(double base, double amp, int teeth, int seed) {
    final rng = math.Random(seed);
    final path = Path()..moveTo(0, 4);
    final step = _wrap / teeth;
    path.lineTo(0, base - amp * 0.4);
    for (var i = 0; i < teeth; i++) {
      final x = i * step;
      path
        ..lineTo(
          x + step * (0.3 + rng.nextDouble() * 0.4),
          base - amp * (0.6 + rng.nextDouble() * 0.4),
        )
        ..lineTo(x + step, base - amp * (0.2 + rng.nextDouble() * 0.2));
    }
    return path
      ..lineTo(_wrap, base - amp * 0.4)
      ..lineTo(_wrap, 4)
      ..close();
  }

  /// A rock floating in the storm, its underside tapering to a point.
  static void _floatingRock(
    Canvas canvas,
    double x,
    double y,
    double w,
    Color c,
  ) {
    final rock = Path()
      ..moveTo(x - w, y)
      ..lineTo(x - w * 0.7, y - w * 0.35)
      ..lineTo(x + w * 0.5, y - w * 0.4)
      ..lineTo(x + w, y - w * 0.05)
      ..lineTo(x + w * 0.3, y + w * 0.5)
      ..lineTo(x, y + w * 1.1)
      ..lineTo(x - w * 0.4, y + w * 0.45)
      ..close();
    _shape(canvas, rock, c, w: 0.06);
    // A cap of grass and a glowing crystal.
    _shape(
      canvas,
      Path()
        ..moveTo(x - w * 0.75, y - w * 0.3)
        ..lineTo(x + w * 0.5, y - w * 0.38)
        ..lineTo(x + w * 0.4, y - w * 0.2)
        ..lineTo(x - w * 0.6, y - w * 0.15)
        ..close(),
      const Color(0xFF5E7A5A),
      w: 0.04,
    );
    _shape(
      canvas,
      Path()
        ..moveTo(x + w * 0.1, y - w * 0.35)
        ..lineTo(x + w * 0.2, y - w * 0.8)
        ..lineTo(x + w * 0.3, y - w * 0.35)
        ..close(),
      const Color(0xFFC9A2FF),
      w: 0.04,
    );
  }

  static void _mythicFar(Canvas canvas) {
    _shape(canvas, _crags(0, 9, 14, 61), const Color(0xFF6E6290));
    // The Titan Tower on the horizon, wreathed in storm.
    const tower = Color(0xFF4A4068);
    for (final x in [50.0, 130.0]) {
      _shape(
        canvas,
        Path()
          ..moveTo(x - 2.2, 0)
          ..lineTo(x - 1.4, -22)
          ..lineTo(x - 2.0, -22.5)
          ..lineTo(x, -26)
          ..lineTo(x + 2.0, -22.5)
          ..lineTo(x + 1.4, -22)
          ..lineTo(x + 2.2, 0)
          ..close(),
        tower,
        w: 0.06,
      );
      canvas.drawCircle(
        Offset(x, -24.2),
        0.5,
        Paint()
          ..color = const Color(0xFFE2CCFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
      );
    }
    final rng = math.Random(62);
    for (var i = 0; i < 6; i++) {
      _floatingRock(
        canvas,
        8 + i * 26 + rng.nextDouble() * 10,
        -14 - rng.nextDouble() * 6,
        1.0 + rng.nextDouble() * 0.8,
        const Color(0xFF7A6E9A),
      );
    }
  }

  static void _mythicMid(Canvas canvas) {
    _shape(canvas, _crags(0.2, 5.5, 18, 63), const Color(0xFF4E5A62));
    final rng = math.Random(64);
    for (var i = 0; i < 4; i++) {
      final x = 20 + i * 40 + rng.nextDouble() * 12;
      final y = -10 - rng.nextDouble() * 4;
      // Chains hold the nearer rocks to the ground.
      canvas.drawLine(
        Offset(x, y + 1.6),
        Offset(x + 1.5, -2),
        _line..strokeWidth = 0.08,
      );
      _floatingRock(
        canvas,
        x,
        y,
        1.6 + rng.nextDouble(),
        const Color(0xFF6A6280),
      );
    }
  }

  static void _mythicNear(Canvas canvas) {
    _shape(canvas, _ridge(0.4, 1.8, 7, 65), const Color(0xFF4F6A4A));
    final rng = math.Random(66);
    for (var x = 5.0; x < _wrap - 3; x += 9 + rng.nextDouble() * 12) {
      // Dead, twisted trees.
      final h = 2.5 + rng.nextDouble() * 1.5;
      final b = Path()
        ..moveTo(x, 0.2)
        ..lineTo(x + 0.1, 0.2 - h)
        ..moveTo(x + 0.05, 0.2 - h * 0.6)
        ..lineTo(x + 0.8, 0.2 - h * 0.9)
        ..moveTo(x + 0.07, 0.2 - h * 0.75)
        ..lineTo(x - 0.6, 0.2 - h * 1.05);
      canvas.drawPath(
        b,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.22
          ..color = const Color(0xFF2E2A26),
      );
    }
  }
}

class _Look {
  _Look({
    required this.skyTop,
    required this.skyHorizon,
    this.sun,
    required this.layers,
  });

  final Color skyTop, skyHorizon;
  final Color? sun;

  /// (parallax, painter) from farthest to nearest.
  final List<(double, void Function(Canvas))> layers;
}
