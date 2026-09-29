import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  weakPoint('sfx/weak_point.wav'),
  arrow('sfx/arrow.wav'),
  hammer('sfx/hammer.wav'),
  playerHit('sfx/player_hit.wav'),
  warHorn('sfx/war_horn.wav'),
  poof('sfx/poof.wav'),
  click('sfx/click.wav'),
  star('sfx/star.wav'),
  coin('sfx/coin.wav'),
  score('sfx/score.wav');

  const Sfx(this.file);
  final String file;
}

/// Pooled sound effects plus background music.
///
/// A collapsing castle produces dozens of contacts per second, so each
/// effect is throttled to avoid a wall of identical sounds.
/// Background tracks: a light tune for menus, a stirring one for sieges.
enum MusicTrack {
  menu('music/menu_theme.m4a', 0.45),
  battle('music/battle_theme.m4a', 0.32);

  const MusicTrack(this.file, this.volume);
  final String file;
  final double volume;
}

/// Pooled sound effects plus background music.
///
/// A collapsing castle produces dozens of contacts per second, so each
/// effect is throttled to avoid a wall of identical sounds. Music and
/// effects can each be switched off; the choice is remembered.
class GameAudio {
  static const _minGap = Duration(milliseconds: 70);
  static const _prefsKey = 'audio_v1';

  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};
  MusicTrack? _track;

  /// Scales every effect, e.g. quieter behind the main menu.
  double volumeScale = 1;

  /// Whether music and sound effects are on.
  final ValueNotifier<bool> musicOn = ValueNotifier(true);
  final ValueNotifier<bool> soundOn = ValueNotifier(true);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        musicOn.value = !saved.contains('m0');
        soundOn.value = !saved.contains('s0');
      }
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
    if (pool == null || !soundOn.value || volume <= 0.02) return;
    final now = DateTime.now();
    final last = _lastPlayed[sfx];
    if (last != null && now.difference(last) < _minGap) return;
    _lastPlayed[sfx] = now;
    unawaited(pool.start(volume: (volume * volumeScale).clamp(0, 1)));
  }

  /// Switches to [track] unless it is already playing.
  void playMusic(MusicTrack track) {
    if (_pools.isEmpty || _track == track) return;
    _track = track;
    if (!musicOn.value) return;
    unawaited(FlameAudio.bgm.play(track.file, volume: track.volume));
  }

  Future<void> toggleMusic() async {
    musicOn.value = !musicOn.value;
    final track = _track;
    if (!musicOn.value) {
      await FlameAudio.bgm.stop();
    } else if (track != null) {
      await FlameAudio.bgm.play(track.file, volume: track.volume);
    }
    await _save();
  }

  Future<void> toggleSound() async {
    soundOn.value = !soundOn.value;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      'm${musicOn.value ? 1 : 0}s${soundOn.value ? 1 : 0}',
    );
  }
}
