import 'package:flutter_test/flutter_test.dart';
import 'package:gametest/core/damage.dart';
import 'package:gametest/core/scoring.dart';

void main() {
  group('damageFromImpulse', () {
    test('resting contact deals no damage', () {
      expect(damageFromImpulse(impulseDamageThreshold), 0);
      expect(damageFromImpulse(0.5), 0);
    });

    test('scales with impulse above threshold and multiplier', () {
      expect(damageFromImpulse(impulseDamageThreshold + 10), 10);
      expect(damageFromImpulse(impulseDamageThreshold + 10, multiplier: 2), 20);
    });
  });

  group('crackStageFor', () {
    test('pristine at full hp, max stage near death', () {
      expect(crackStageFor(100, 100), 0);
      expect(crackStageFor(1, 100), crackStages);
      expect(crackStageFor(0, 100), crackStages);
    });

    test('increases monotonically as hp drops', () {
      var last = 0;
      for (var hp = 100.0; hp >= 0; hp -= 5) {
        final stage = crackStageFor(hp, 100);
        expect(stage, greaterThanOrEqualTo(last));
        last = stage;
      }
    });
  });

  group('starsFor', () {
    test('loss gives zero stars', () {
      expect(starsFor(won: false, shotsUsed: 1, par: 2, destruction: 1), 0);
    });

    test('over par gives one star', () {
      expect(starsFor(won: true, shotsUsed: 3, par: 2, destruction: 1), 1);
    });

    test('par with low destruction gives two, high gives three', () {
      expect(starsFor(won: true, shotsUsed: 2, par: 2, destruction: 0.3), 2);
      expect(starsFor(won: true, shotsUsed: 2, par: 2, destruction: 0.8), 3);
    });
  });
}
