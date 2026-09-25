import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/materials.dart';
import '../../levels/level_data.dart';

/// A scout's sketch of the enemy position: blocks as coloured ink outlines
/// on cream paper, defenders as bright dots, weak points circled when known.
class BlueprintPainter extends CustomPainter {
  BlueprintPainter({required this.level, required this.showWeakPoints});

  final LevelData level;
  final bool showWeakPoints;

  static const _paper = Color(0xFFFFF8E6);
  static const _grid = Color(0x1F2B1A0E);
  static const _ink = Color(0xFF2B1A0E);
  static const _weak = Color(0xFFD83B2E);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas
      ..save()
      ..clipRRect(bg)
      ..drawRRect(bg, Paint()..color = _paper);
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    _drawCastle(canvas, size);
    canvas
      ..restore()
      ..drawRRect(
        bg.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _ink,
      );
  }

  void _drawCastle(Canvas canvas, Size size) {
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
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    // A strip of grass for the castle to stand on.
    canvas
      ..drawRect(
        Rect.fromLTRB(0, groundY, size.width, size.height),
        Paint()..color = const Color(0xFFA6DB7E),
      )
      ..drawLine(Offset(0, groundY), Offset(size.width, groundY), ink);

    for (final b in level.blocks) {
      final rect = Rect.fromPoints(
        toCanvas(b.x - b.width / 2, b.y),
        toCanvas(b.x + b.width / 2, b.y + b.height),
      );
      final fill = switch (b.material) {
        BlockMaterial.stone => const Color(0xFFC9CED6),
        BlockMaterial.wood => const Color(0xFFF0C27E),
        BlockMaterial.glass => const Color(0xFFBDE8F7),
      };
      canvas
        ..drawRect(rect, Paint()..color = fill)
        ..drawRect(rect, ink);
      if (b.weak && showWeakPoints) _markWeak(canvas, rect.center, scale);
    }

    for (final p in level.props) {
      final at = toCanvas(p.x, p.y + 0.5);
      switch (p.kind) {
        case PropKind.powderBarrel:
          canvas
            ..drawCircle(
              at,
              scale * 0.45,
              Paint()..color = const Color(0xFF8A5A2B),
            )
            ..drawCircle(at, scale * 0.45, ink);
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
      final radius = u.kind.isRoyal ? 0.6 : 0.45;
      final at = toCanvas(u.x, u.y + radius);
      final color = switch (u.kind) {
        UnitKind.king || UnitKind.pharaoh => const Color(0xFFFFC933),
        UnitKind.soldier => const Color(0xFFD83B2E),
        UnitKind.archer => const Color(0xFF5DBB3A),
        UnitKind.engineer => const Color(0xFFE0782A),
      };
      final r = math.max(4.0, radius * scale);
      canvas
        ..drawCircle(at, r, Paint()..color = color)
        ..drawCircle(
          at,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = _ink,
        );
    }
  }

  void _markWeak(Canvas canvas, Offset at, double scale) {
    canvas.drawCircle(
      at,
      math.max(8, scale * 0.9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _weak,
    );
  }

  @override
  bool shouldRepaint(BlueprintPainter old) =>
      old.level != level || old.showWeakPoints != showWeakPoints;
}
