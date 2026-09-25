import 'dart:math' as math;

import 'package:flame_forge2d/flame_forge2d.dart';

import '../core/damage.dart';
import '../game/siege_game.dart';
import 'projectiles/stone_projectile.dart';

/// Gives a physics body hit points that drain from contact impulses.
mixin Damageable on BodyComponent<SiegeGame>, ContactCallbacks {
  double get maxHp;

  late double hp = maxHp;
  bool isDestroyed = false;

  /// Seconds left of the red "just got hit" tint.
  double hurtFlash = 0;

  /// Called once when hp reaches zero, before removal.
  void onDestroyed();

  @override
  void postSolve(Object other, Contact contact, ContactImpulse impulse) {
    super.postSolve(other, contact, impulse);
    if (isDestroyed || !game.damageEnabled) return;
    var peak = 0.0;
    for (var i = 0; i < impulse.count; i++) {
      peak = math.max(peak, impulse.normalImpulses[i]);
    }
    final damage = damageFromImpulse(
      peak,
      multiplier: other is StoneProjectile ? projectileDamageMultiplier : 1,
    );
    if (damage > 0) takeDamage(damage);
  }

  void takeDamage(double amount) {
    if (isDestroyed) return;
    hp -= amount;
    hurtFlash = 0.15;
    if (hp <= 0) destroy();
  }

  void destroy() {
    if (isDestroyed) return;
    isDestroyed = true;
    hp = 0;
    onDestroyed();
    // Removal is deferred to the next lifecycle pass, so it is safe to call
    // from inside a physics callback.
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (hurtFlash > 0) hurtFlash -= dt;
  }
}
