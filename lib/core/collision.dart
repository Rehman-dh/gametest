/// Forge2D collision category bits. Each fixture belongs to one category
/// and lists which categories it collides with in its mask.
abstract final class CollisionCategory {
  static const ground = 0x0001;
  static const structure = 0x0002;
  static const unit = 0x0004;
  static const projectile = 0x0008;
  static const debris = 0x0010;
  static const enemyProjectile = 0x0020;

  /// The player's barricade: enemy fire hits it, the player's shots don't.
  static const playerStructure = 0x0040;

  /// Sensor around the player's siege engine.
  static const playerEngine = 0x0080;

  static const all = 0xFFFF;

  /// Debris settles on the ground and on castle pieces but never blocks
  /// shots or pushes units around.
  static const debrisMask = ground | structure | debris | playerStructure;
  static const projectileMask = ground | structure | unit;
  static const enemyProjectileMask = ground | playerStructure | playerEngine;
}
