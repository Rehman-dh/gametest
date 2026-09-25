import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../levels/level_data.dart';

/// A scout's sketch of the enemy position: blocks as ink outlines on
/// blueprint paper, defenders as marks, weak points circled when known.
class BlueprintPainter extends CustomPainter {
  BlueprintPainter({required this.level, required this.showWeakPoints});

  final LevelData level;
  final bool showWeakPoints;

  static const _paper = Color(0xFF1C2B3A);
  static const _grid = Color(0x223E6A8F);
  static const _ink = Color(0xFFD6E4EE);
  static const _weak = Color(0xFFFFC75A);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(6)),
      Paint()..color = _paper,
    );
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Fit the castle (not the empty field before it) into the sheet.
    final xs = [
      for (final b in level.blocks) ...[b.x - b.width / 2, b.x + b.width / 2],
      for (final u in level.units) u.x,
      for (final p in level.props) p.x,
    ];
    if (xs.isEmpty) return;
    final top = [
      for (final b in level.blocks) b.y + b.height,
      for (final u in level.units) u.y + 1.2,
      4.0,
    ].reduce(math.max);
    final left = xs.reduce(math.min) - 1.5;
    final right = xs.reduce(math.max) + 1.5;
    const pad = 14.0;
    final scale = math.min(
      (size.width - 2 * pad) / (right - left),
      (size.height - 2 * pad) / (top + 0.5),
    );
    final groundY = size.height - pad;
    Offset toCanvas(double x, double y) =>
        Offset(pad + (x - left) * scale, groundY - y * scale);

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _ink;
    canvas.drawLine(
      Offset(pad * 0.5, groundY),
      Offset(size.width - pad * 0.5, groundY),
      ink,
    );

    for (final b in level.blocks) {
      final rect = Rect.fromPoints(
        toCanvas(b.x - b.width / 2, b.y),
        toCanvas(b.x + b.width / 2, b.y + b.height),
      );
      final hatch = switch (b.material.name) {
        'stone' => 0x33,
        'wood' => 0x1A,
        _ => 0x0A,
      };
      canvas
        ..drawRect(rect, Paint()..color = _ink.withAlpha(hatch))
        ..drawRect(rect, ink);
      if (b.weak && showWeakPoints) _markWeak(canvas, rect.center, scale);
    }

    for (final p in level.props) {
      final at = toCanvas(p.x, p.y + 0.5);
      switch (p.kind) {
        case PropKind.powderBarrel:
          canvas.drawCircle(at, scale * 0.45, ink);
          if (showWeakPoints) _markWeak(canvas, at, scale);
        case PropKind.enemyCatapult:
          final r = Rect.fromCenter(
            center: at,
            width: scale * 2.6,
            height: scale * 1.2,
          );
          canvas
            ..drawRect(r, ink)
            ..drawLine(r.topLeft, r.bottomRight, ink)
            ..drawLine(r.bottomLeft, r.topRight, ink);
      }
    }

    for (final u in level.units) {
      final radius = u.kind == UnitKind.king ? 0.6 : 0.45;
      final at = toCanvas(u.x, u.y + radius);
      final color = switch (u.kind) {
        UnitKind.king => const Color(0xFFFFD36B),
        UnitKind.soldier => const Color(0xFFE07A6A),
        UnitKind.archer => const Color(0xFF9FD08A),
        UnitKind.engineer => const Color(0xFFD9A86A),
      };
      canvas.drawCircle(
        at,
        math.max(3, radius * scale),
        Paint()..color = color,
      );
    }
  }

  void _markWeak(Canvas canvas, Offset at, double scale) {
    canvas.drawCircle(
      at,
      math.max(8, scale * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _weak,
    );
  }

  @override
  bool shouldRepaint(BlueprintPainter old) =>
      old.level != level || old.showWeakPoints != showWeakPoints;
}
