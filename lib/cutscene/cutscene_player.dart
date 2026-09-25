import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../components/env/background.dart';
import '../components/env/ground.dart';
import '../components/env/ground_detail.dart';
import '../components/story/story_actor.dart';
import '../game/siege_game.dart';
import '../story/characters.dart';
import '../systems/audio.dart';
import 'cutscene_data.dart';

/// A line currently on screen.
class SpokenLine {
  const SpokenLine({required this.look, required this.text});
  final CharacterLook look;
  final String text;
}

/// Plays a [CutsceneData] on a stage built in the game world, exposing
/// what the Flutter overlay should show (dialogue, letterbox, fades,
/// titles) as notifiers.
class CutscenePlayer extends Component with HasGameReference<SiegeGame> {
  CutscenePlayer(this.data, {required this.onDone});

  final CutsceneData data;
  final VoidCallback onDone;

  final ValueNotifier<SpokenLine?> line = ValueNotifier(null);
  final ValueNotifier<double> fade = ValueNotifier(0);
  final ValueNotifier<(String, String)?> title = ValueNotifier(null);
  final ValueNotifier<Color> tint = ValueNotifier(const Color(0x00000000));

  final Map<String, StoryActor> _actors = {};
  final List<_Timer> _timers = [];
  Completer<void>? _awaitingTap;
  bool _skipping = false;
  bool _done = false;

  // Camera tween.
  Vector2 _camFrom = Vector2.zero(), _camTo = Vector2.zero();
  double _viewFrom = 10, _viewTo = 10, _camTime = 0, _camDuration = 0;

  bool get isDone => _done;

  @override
  Future<void> onLoad() async {
    await game.world.addAll([
      Background(),
      Ground(left: -60, right: 120),
      GroundDetail(),
    ]);
    _camFrom = _camTo = Vector2(0, -2);
    _applyCamera(0, -2, 10);
    unawaited(_run());
  }

  Future<void> _run() async {
    for (final step in data.steps) {
      if (_skipping) break;
      await _play(step);
    }
    _finish();
  }

  /// Advances past the current line of dialogue.
  void advance() {
    _awaitingTap?.complete();
    _awaitingTap = null;
  }

  void skip() {
    _skipping = true;
    for (final t in _timers) {
      t.done.complete();
    }
    _timers.clear();
    for (final actor in _actors.values) {
      actor.finishMove();
    }
    advance();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    line.value = null;
    title.value = null;
    onDone();
  }

  Future<void> _play(CutsceneStep step) async {
    switch (step) {
      case SpawnStep():
        final actor = StoryActor(
          look: characterLooks[step.character]!,
          x: step.x,
          facing: step.facing,
          pose: step.pose,
        );
        _actors[step.actor] = actor;
        await game.world.add(actor);
      case PropStep():
        await game.world.add(StoryProp(prop: step.prop, x: step.x));
      case MoveStep():
        await _actors[step.actor]!.walkTo(step.x, step.duration);
      case PoseStep():
        final actor = _actors[step.actor]!;
        actor.pose = step.pose;
        if (step.facing != null) actor.facing = step.facing!;
      case RemoveStep():
        _actors.remove(step.actor)?.removeFromParent();
      case CameraStep():
        _camFrom = _camTo.clone();
        _viewFrom = _viewTo;
        _camTo = Vector2(step.x, step.y);
        _viewTo = step.viewHeight;
        _camTime = 0;
        _camDuration = step.duration;
        if (step.duration <= 0) _applyCamera(step.x, step.y, step.viewHeight);
        await _wait(step.duration);
      case SayStep():
        final look =
            _actors[step.speaker]?.look ??
            characterLooks[CharacterId.values.byName(step.speaker)]!;
        line.value = SpokenLine(look: look, text: step.text);
        if (_skipping) break;
        await (_awaitingTap = Completer<void>()).future;
        line.value = null;
      case WaitStep():
        await _wait(step.duration);
      case FadeStep():
        await _tween(step.duration, fade.value, step.to, (v) => fade.value = v);
      case TitleStep():
        title.value = (step.text, step.subtitle);
        await _wait(step.duration);
        title.value = null;
      case TintStep():
        tint.value = step.color;
      case SoundStep():
        final sfx = Sfx.values.where((s) => s.name == step.sound).firstOrNull;
        if (sfx != null) game.effects.audio.play(sfx);
      case ParallelStep():
        await Future.wait([for (final s in step.steps) _play(s)]);
    }
  }

  Future<void> _wait(double seconds) {
    if (_skipping || seconds <= 0) return Future.value();
    final timer = _Timer(seconds);
    _timers.add(timer);
    return timer.done.future;
  }

  Future<void> _tween(
    double seconds,
    double from,
    double to,
    void Function(double) apply,
  ) {
    if (_skipping || seconds <= 0) {
      apply(to);
      return Future.value();
    }
    final timer = _Timer(seconds, onTick: (t) => apply(from + (to - from) * t));
    _timers.add(timer);
    return timer.done.future.then((_) => apply(to));
  }

  /// Scripts frame the action as if the whole screen were free; the
  /// camera drops a little so subjects clear the dialogue box below.
  static const _dialogueClearance = 0.24;

  void _applyCamera(double x, double y, double viewHeight) {
    game.camera.viewfinder
      ..zoom = game.size.y / viewHeight
      ..position = Vector2(x, y + viewHeight * _dialogueClearance)
      ..angle = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_camDuration > 0 && _camTime < _camDuration) {
      _camTime += dt;
      final t = (_camTime / _camDuration).clamp(0.0, 1.0);
      // Smoothstep for a gentle, filmic pan.
      final e = t * t * (3 - 2 * t);
      final pos = _camFrom + (_camTo - _camFrom) * e;
      _applyCamera(pos.x, pos.y, _viewFrom + (_viewTo - _viewFrom) * e);
      if (t >= 1) _viewFrom = _viewTo;
    }
    for (final timer in List.of(_timers)) {
      timer.elapsed += dt;
      timer.onTick?.call(math.min(1, timer.elapsed / timer.duration));
      if (timer.elapsed >= timer.duration) {
        _timers.remove(timer);
        timer.done.complete();
      }
    }
  }
}

class _Timer {
  _Timer(this.duration, {this.onTick});
  final double duration;
  final void Function(double t)? onTick;
  final Completer<void> done = Completer<void>();
  double elapsed = 0;
}
