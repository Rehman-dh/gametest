import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/ballistics.dart';

/// Integrates the flight and returns the height where it crosses [x].
double _heightAt(
  double x,
  double fromX,
  double fromY,
  double vx,
  double vy,
  double g,
) {
  final t = (x - fromX) / vx;
  return fromY + vy * t + 0.5 * g * t * t;
}

void main() {
  const g = 12.0;

  for (final high in [false, true]) {
    test('hits the target leftwards (${high ? 'high' : 'flat'} arc)', () {
      final v = launchVelocityToHit(
        fromX: 40,
        fromY: -6,
        toX: 2,
        toY: -2,
        speed: 26,
        gravity: g,
        highArc: high,
      )!;
      expect(v.vx, lessThan(0));
      expect(_heightAt(2, 40, -6, v.vx, v.vy, g), closeTo(-2, 1e-6));
    });
  }

  test('high arc climbs steeper than the flat one', () {
    final flat = launchVelocityToHit(
      fromX: 0,
      fromY: 0,
      toX: 30,
      toY: 0,
      speed: 25,
      gravity: g,
    )!;
    final high = launchVelocityToHit(
      fromX: 0,
      fromY: 0,
      toX: 30,
      toY: 0,
      speed: 25,
      gravity: g,
      highArc: true,
    )!;
    expect(high.vy, lessThan(flat.vy));
  });

  test('out of range returns null', () {
    expect(
      launchVelocityToHit(
        fromX: 0,
        fromY: 0,
        toX: 500,
        toY: 0,
        speed: 20,
        gravity: g,
      ),
      isNull,
    );
  });
}
