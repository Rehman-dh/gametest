import 'dart:math' as math;

/// Launch velocity (vx, vy) that carries a projectile fired at [speed]
/// from (fromX, fromY) through (toX, toY) under downward [gravity],
/// in y-down world space. Returns null when the target is out of range.
///
/// Picks the flat arc unless [highArc] is set (lobbed catapult stones).
({double vx, double vy})? launchVelocityToHit({
  required double fromX,
  required double fromY,
  required double toX,
  required double toY,
  required double speed,
  required double gravity,
  bool highArc = false,
}) {
  final dx = toX - fromX;
  // Work y-up for the textbook formula.
  final dy = fromY - toY;
  final v2 = speed * speed;
  final disc = v2 * v2 - gravity * (gravity * dx * dx + 2 * dy * v2);
  if (disc < 0 || dx == 0) return null;
  final root = math.sqrt(disc);
  final tanTheta = (v2 + (highArc ? root : -root)) / (gravity * dx.abs());
  final theta = math.atan(tanTheta);
  final dir = dx.sign;
  return (vx: dir * speed * math.cos(theta), vy: -speed * math.sin(theta));
}
