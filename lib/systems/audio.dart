import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

enum Sfx {
  launch('sfx/launch.wav'),
  impactWood('sfx/impact_wood.wav'),
  impactStone('sfx/impact_stone.wav'),
  impactGlass('sfx/impact_glass.wav'),
  breakWood('sfx/break_wood.wav'),
  breakStone('sfx/break_stone.wav'),
  breakGlass('sfx/break_glass.wav'),
  unitDown('sfx/unit_down.wav'),
  victory('sfx/victory.wav'),
  defeat('sfx/defeat.wav'),
  explosion('sfx/explosion.wav'),
  ignite('sfx/ignite.wav'),
  fireCrackle('sfx/fire_crackle.wav'),
  split('sfx/split.wav'),
  ballista('sfx/ballista.wav'),
  weakPoint('sfx/weak_point.wav');

  const Sfx(this.file);
  final String file;
}

/// Pooled sound effects plus background music.
///
/// A collapsing castle produces dozens of contacts per second, so each
/// effect is throttled to avoid a wall of identical sounds.
class GameAudio {
  static const _music = 'music/siege_ambient.wav';
  static const _minGap = Duration(milliseconds: 70);

  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};
  bool _musicStarted = false;

  Future<void> load() async {
    try {
      FlameAudio.bgm.initialize();
      for (final sfx in Sfx.values) {
        _pools[sfx] = await FlameAudio.createPool(sfx.file, maxPlayers: 4);
      }
    } catch (e) {
      // Audio is optional; a device without output must still run the game.
      debugPrint('Audio disabled: $e');
    }
  }

  void play(Sfx sfx, {double volume = 1}) {
    final pool = _pools[sfx];
    if (pool == null || volume <= 0.02) return;
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last) < _minGap) return;
    _lastPlayed[sfx] = now;
    unawaited(pool.start(volume: volume.clamp(0, 1)));
  }

  void startMusic() {
    if (_musicStarted) return;
    _musicStarted = true;
    unawaited(FlameAudio.bgm.play(_music, volume: 0.35));
  }
}
