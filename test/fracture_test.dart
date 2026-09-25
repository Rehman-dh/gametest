import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/fracture.dart';

/// Signed area via the shoelace formula (positive for clockwise in y-down).
double _area(List<Offset> poly) {
  var sum = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2;
}

bool _isConvex(List<Offset> poly) {
  int? sign;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i],
        b = poly[(i + 1) % poly.length],
        c = poly[(i + 2) % poly.length];
    final cross = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    final s = cross.sign.toInt();
    if (s == 0) continue;
    sign ??= s;
    if (s != sign) return false;
  }
  return true;
}

void main() {
  test('long thin blocks break along their length', () {
    final shards = fractureRect(4, 0.5, math.Random(1));
    expect(shards, hasLength(4));
    expect(shards.map((s) => s.center.dy).toSet(), {0.0});
  });

  test('thick blocks also break across', () {
    expect(fractureRect(2, 1.5, math.Random(1)), hasLength(4));
    expect(fractureRect(1, 1, math.Random(1)), hasLength(4));
  });

  test('shards are convex and never exceed the original area', () {
    for (var seed = 0; seed < 50; seed++) {
      final shards = fractureRect(3, 1.2, math.Random(seed));
      var total = 0.0;
      for (final s in shards) {
        expect(_isConvex(s.vertices), isTrue, reason: 'seed $seed');
        final area = _area(s.vertices).abs();
        expect(area, greaterThan(0));
        total += area;
      }
      expect(total, lessThanOrEqualTo(3 * 1.2 + 1e-9));
      expect(total, greaterThan(3 * 1.2 * 0.5));
    }
  });
}
