/// Star rating for a finished level.
///
/// ★ win, ★★ win within [par] shots, ★★★ also meet the hidden objective:
/// break a weak point when the level has one ([weakPointHit] non-null),
/// otherwise destroy at least [destructionForThreeStars] of the castle.
int starsFor({
  required bool won,
  required int shotsUsed,
  required int par,
  required double destruction,
  bool? weakPointHit,
  double destructionForThreeStars = 0.6,
}) {
  if (!won) return 0;
  if (shotsUsed > par) return 1;
  final hidden = weakPointHit ?? destruction >= destructionForThreeStars;
  return hidden ? 3 : 2;
}
