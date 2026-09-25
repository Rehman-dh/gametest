/// Star rating for a finished level.
///
/// ★ win, ★★ win within [par] shots, ★★★ also destroy at least
/// [destructionForThreeStars] of the castle. (Hidden weak-point objectives
/// replace the third condition in a later phase.)
int starsFor({
  required bool won,
  required int shotsUsed,
  required int par,
  required double destruction,
  double destructionForThreeStars = 0.6,
}) {
  if (!won) return 0;
  if (shotsUsed > par) return 1;
  if (destruction < destructionForThreeStars) return 2;
  return 3;
}
