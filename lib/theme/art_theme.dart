import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/particles.dart';

import '../core/ammo.dart';
import '../core/materials.dart';
import '../core/weapons.dart';
import '../levels/level_data.dart';

/// Every visual in the game is drawn through this interface.
///
/// Components describe *what* to draw (semantic parameters), never *how*
/// or from which file. Swapping the art style (e.g. the planned realistic
/// pass) means adding a new implementation, with no gameplay changes.
///
/// All coordinates are in world meters in the caller's local space
/// (y-down, origin at the body's center unless stated otherwise).
abstract class ArtTheme {
  /// Sky and parallax background layers covering [visible] (world rect).
  /// [time] is real seconds, for ambient motion (clouds, drifting dust).
  void drawBackground(Canvas canvas, Rect visible, double time);

  /// Ground-level detail drawn in front of the battlefield (tufts, stones).
  void drawGroundDetail(Canvas canvas, Rect visible);

  /// Screen-space darkening of the edges; [size] is the viewport size.
  void drawVignette(Canvas canvas, Size size);

  /// Ground slab; [rect] top edge is the ground surface.
  void drawGround(Canvas canvas, Rect rect);

  void drawBlock(
    Canvas canvas,
    Size size,
    BlockMaterial material, {
    required int crackStage,
    required int seed,
    bool weak = false,
    double char = 0,
  });

  /// Flames licking a burning block of [size]; [time] animates flicker.
  void drawFire(Canvas canvas, Size size, double time);

  /// Pulsing outline marking a revealed weak point of [size].
  void drawWeakPointMarker(Canvas canvas, Size size, double time);

  /// Powder barrel prop, centered on the origin.
  void drawBarrel(Canvas canvas, Size size, {required int crackStage});

  /// A fractured piece of a block; [polygon] is centered on the origin.
  void drawShard(Canvas canvas, List<Offset> polygon, BlockMaterial material);

  void drawUnit(
    Canvas canvas,
    double radius,
    UnitKind kind, {
    required bool hurt,
  });

  /// A projectile of [type]; bolts point along +x.
  void drawProjectile(Canvas canvas, AmmoType type, double radius, double time);

  /// Origin is the engine's base center on the ground surface.
  /// [armAngle] 0 = arm straight up, negative = cocked back (throwers).
  /// [aimAngle] is the launch direction in radians (ballista).
  void drawSiegeEngine(
    Canvas canvas,
    WeaponType type, {
    required double armAngle,
    required double aimAngle,
  });

  void drawTrajectoryDot(Canvas canvas, Offset center, double opacity);

  /// Pull-back line from the launch origin to the drag point.
  void drawAimBand(Canvas canvas, Offset from, Offset to, double power);

  // Particle effects, positioned relative to the spawn point (meters).

  Particle breakParticles(BlockMaterial material, Size size, math.Random rng);

  Particle impactParticles(double strength, math.Random rng);

  Particle unitDeathParticles(UnitKind kind, math.Random rng);

  Particle trailParticle(math.Random rng);

  Particle fireParticles(Size size, math.Random rng);

  Particle explosionParticles(double radius, math.Random rng);
}
