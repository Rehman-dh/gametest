import 'dart:ui';

import '../core/materials.dart';
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
  void drawBackground(Canvas canvas, Rect visible);

  /// Ground slab; [rect] top edge is the ground surface.
  void drawGround(Canvas canvas, Rect rect);

  void drawBlock(
    Canvas canvas,
    Size size,
    BlockMaterial material, {
    required int crackStage,
    required int seed,
  });

  void drawUnit(
    Canvas canvas,
    double radius,
    UnitKind kind, {
    required bool hurt,
  });

  void drawStone(Canvas canvas, double radius);

  /// Origin is the catapult's base center on the ground surface.
  /// [armAngle] 0 = arm pointing straight up, negative = cocked back.
  void drawCatapult(Canvas canvas, {required double armAngle});

  void drawTrajectoryDot(Canvas canvas, Offset center, double opacity);

  /// Pull-back line from the launch origin to the drag point.
  void drawAimBand(Canvas canvas, Offset from, Offset to, double power);
}
