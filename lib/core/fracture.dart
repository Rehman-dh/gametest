import 'dart:math' as math;
import 'dart:ui';

/// One piece of a broken block, in the block's local space.
class ShardShape {
  const ShardShape({required this.center, required this.vertices});

  /// Shard center relative to the block center.
  final Offset center;

  /// Convex polygon relative to [center].
  final List<Offset> vertices;
}

/// Splits a [width] × [height] block into 2–8 jagged quadrilateral shards.
///
/// Long blocks break along their length; thick blocks also break across.
/// Corners are nudged inward by up to [jag] of the cell size so the pieces
/// look chipped while staying convex (a Forge2D requirement).
List<ShardShape> fractureRect(
  double width,
  double height,
  math.Random rng, {
  double jag = 0.18,
}) {
  final alongX = width >= height;
  final long = math.max(width, height);
  final short = math.min(width, height);
  // Massive masonry breaks into more, but still hefty, chunks.
  final pieces = (long / 0.9).round().clamp(2, long > 5 ? 7 : 4);
  final across = short > 2.5 ? 3 : (short > 0.9 ? 2 : 1);
  final nx = alongX ? pieces : across;
  final ny = alongX ? across : pieces;
  final cw = width / nx;
  final ch = height / ny;

  double inward(double extent) => rng.nextDouble() * jag * extent;

  return [
    for (var i = 0; i < nx; i++)
      for (var j = 0; j < ny; j++)
        ShardShape(
          center: Offset(
            -width / 2 + (i + 0.5) * cw,
            -height / 2 + (j + 0.5) * ch,
          ),
          vertices: [
            Offset(-cw / 2 + inward(cw), -ch / 2 + inward(ch)),
            Offset(cw / 2 - inward(cw), -ch / 2 + inward(ch)),
            Offset(cw / 2 - inward(cw), ch / 2 - inward(ch)),
            Offset(-cw / 2 + inward(cw), ch / 2 - inward(ch)),
          ],
        ),
  ];
}
