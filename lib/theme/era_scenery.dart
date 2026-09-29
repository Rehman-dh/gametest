import 'dart:math' as math;
import 'dart:ui';

import '../core/era.dart';

/// The landscape behind a siege, painted per era in the game's outlined
/// cartoon style: Egypt's dunes and pyramids, Persia's golden sands and a
/// city of domes, the Medieval west's misty hills and pine forests.
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
    Era.medieval: _Look(
      skyTop: const Color(0xFF7F9CB5),
      skyHorizon: const Color(0xFFD9E1E4),
      layers: [
        (0.9, _medievalFar),
        (0.75, _medievalMid),
        (0.55, _medievalNear),
      ],
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
