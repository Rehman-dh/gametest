/// Contact impulses at or below this are treated as resting contact
/// (stacked blocks pressing on each other) and deal no damage.
const double impulseDamageThreshold = 2.5;

/// Projectiles hit harder than falling rubble of the same impulse.
const double projectileDamageMultiplier = 1.2;

/// Number of visible crack stages before a block breaks.
const int crackStages = 3;

/// Damage dealt by a physics contact with the given peak normal impulse.
double damageFromImpulse(double impulse, {double multiplier = 1}) {
  if (impulse <= impulseDamageThreshold) return 0;
  return (impulse - impulseDamageThreshold) * multiplier;
}

/// 0 = pristine, [crackStages] = about to break.
int crackStageFor(double hp, double maxHp) {
  if (maxHp <= 0 || hp >= maxHp) return 0;
  final lost = 1 - (hp.clamp(0, maxHp) / maxHp);
  return (lost * (crackStages + 1)).floor().clamp(0, crackStages);
}
