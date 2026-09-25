import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/levels/level_data.dart';
import 'package:gametest/procgen/castle_generator.dart';

const _eps = 1e-6;

Rect _rect(BlockData b) =>
    Rect.fromLTWH(b.x - b.width / 2, b.y, b.width, b.height);

double _unitRadius(UnitKind k) => k.isRoyal ? 0.6 : 0.45;

Rect _propRect(PropData p) => switch (p.kind) {
  PropKind.powderBarrel => Rect.fromLTWH(p.x - 0.45, p.y, 0.9, 1.1),
  PropKind.enemyCatapult => Rect.fromLTWH(p.x - 1.3, p.y, 2.6, 1.2),
};

bool _overlaps(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 0.01 && i.height > 0.01;
}

/// Problems with [level]'s geometry, empty when it is buildable.
List<String> _problems(LevelData level) {
  final issues = <String>[];
  final rects = [for (final b in level.blocks) _rect(b)];

  for (var i = 0; i < rects.length; i++) {
    for (var j = i + 1; j < rects.length; j++) {
      if (_overlaps(rects[i], rects[j])) issues.add('blocks $i and $j overlap');
    }
    final b = level.blocks[i];
    if (b.y < _eps) continue;
    // Resting on something, with its centre above its supports.
    final contacts = [
      for (final r in rects)
        if ((r.bottom - b.y).abs() < _eps &&
            r.right > rects[i].left + _eps &&
            r.left < rects[i].right - _eps)
          (math.max(r.left, rects[i].left), math.min(r.right, rects[i].right)),
    ];
    if (contacts.isEmpty) {
      issues.add('block $i floats');
    } else {
      final lo = contacts.map((c) => c.$1).reduce(math.min);
      final hi = contacts.map((c) => c.$2).reduce(math.max);
      if (b.x < lo - _eps || b.x > hi + _eps) issues.add('block $i overhangs');
    }
  }

  for (final (i, u) in level.units.indexed) {
    final r = _unitRadius(u.kind);
    final circle = Rect.fromCircle(
      center: Offset(u.x, u.y + r),
      radius: r * 0.95,
    );
    for (final (j, b) in rects.indexed) {
      if (_overlaps(circle, b)) issues.add('unit $i inside block $j');
    }
    if (u.y > _eps &&
        !rects.any(
          (b) =>
              (b.bottom - u.y).abs() < _eps && u.x >= b.left && u.x <= b.right,
        )) {
      issues.add('unit $i floats');
    }
  }

  for (final (i, p) in level.props.indexed) {
    final pr = _propRect(p);
    for (final (j, b) in rects.indexed) {
      if (_overlaps(pr, b)) issues.add('prop $i inside block $j');
    }
    for (final (j, u) in level.units.indexed) {
      final r = _unitRadius(u.kind);
      if (_overlaps(
        pr,
        Rect.fromCircle(center: Offset(u.x, u.y + r), radius: r),
      )) {
        issues.add('prop $i overlaps unit $j');
      }
    }
  }
  return issues;
}

void main() {
  const depths = [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 30];

  test('generated castles are buildable across seeds and depths', () {
    final failures = <String>[];
    for (var seed = 0; seed < 200; seed++) {
      for (final depth in depths) {
        final level = CastleGenerator(seed).generate(depth);
        final issues = _problems(level);
        if (issues.isNotEmpty) {
          failures.add('seed $seed depth $depth: ${issues.join(', ')}');
        }
        expect(level.units, isNotEmpty);
        expect(
          level.blocks.map((b) => b.x + b.width / 2).reduce(math.max),
          lessThan(level.worldWidth),
        );
      }
    }
    expect(failures, isEmpty, reason: failures.take(10).join('\n'));
  });

  test('the same seed and depth always build the same castle', () {
    String fingerprint(LevelData l) => [
      for (final b in l.blocks)
        '${b.material.name}${b.x}${b.y}${b.width}${b.height}${b.weak}',
      for (final u in l.units) '${u.kind.name}${u.x}${u.y}',
    ].join('|');
    for (final depth in depths) {
      expect(
        fingerprint(const CastleGenerator(42).generate(depth)),
        fingerprint(const CastleGenerator(42).generate(depth)),
      );
    }
    expect(
      fingerprint(const CastleGenerator(1).generate(3)),
      isNot(fingerprint(const CastleGenerator(2).generate(3))),
    );
  });

  test(
    'difficulty grows: bosses every fifth castle, archers and engineers later',
    () {
      for (var seed = 0; seed < 30; seed++) {
        final gen = CastleGenerator(seed);
        final boss = gen.generate(5);
        expect(boss.objective, Objective.killKing);
        expect(boss.units.where((u) => u.kind == UnitKind.king), hasLength(1));
        expect(
          gen.generate(1).units.where((u) => u.kind == UnitKind.archer),
          isEmpty,
        );
        expect(gen.generate(1).wind, 0);
        expect(
          gen.generate(7).units.any((u) => u.kind == UnitKind.engineer),
          isTrue,
        );
        expect(
          gen.generate(10).props.any((p) => p.kind == PropKind.enemyCatapult),
          isTrue,
        );
      }
    },
  );
}
