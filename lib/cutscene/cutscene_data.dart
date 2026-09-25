import 'dart:convert';
import 'dart:ui';

import '../story/characters.dart';

/// A scripted in-engine scene: a list of steps played in order. Actors are
/// referred to by a key local to the scene ("hero", "master").
class CutsceneData {
  const CutsceneData({required this.id, required this.steps});

  factory CutsceneData.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return CutsceneData(
      id: json['id'] as String,
      steps: [
        for (final s in json['steps'] as List)
          CutsceneStep.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final List<CutsceneStep> steps;
}

double _d(Map<String, dynamic> j, String key, [double fallback = 0]) =>
    (j[key] as num? ?? fallback).toDouble();

sealed class CutsceneStep {
  const CutsceneStep();

  factory CutsceneStep.fromJson(Map<String, dynamic> j) => switch (j['type']) {
    'spawn' => SpawnStep(
      actor: j['actor'] as String,
      character: CharacterId.values.byName(j['character'] as String),
      x: _d(j, 'x'),
      facing: _d(j, 'facing', 1),
      pose: Pose.values.byName(j['pose'] as String? ?? 'stand'),
    ),
    'prop' => PropStep(
      prop: SceneProp.values.byName(j['prop'] as String),
      x: _d(j, 'x'),
    ),
    'move' => MoveStep(
      actor: j['actor'] as String,
      x: _d(j, 'x'),
      duration: _d(j, 'duration', 1),
    ),
    'pose' => PoseStep(
      actor: j['actor'] as String,
      pose: Pose.values.byName(j['pose'] as String),
      facing: (j['facing'] as num?)?.toDouble(),
    ),
    'remove' => RemoveStep(actor: j['actor'] as String),
    'camera' => CameraStep(
      x: _d(j, 'x'),
      y: _d(j, 'y', -2),
      viewHeight: _d(j, 'viewHeight', 10),
      duration: _d(j, 'duration'),
    ),
    'say' => SayStep(
      speaker: j['speaker'] as String,
      text: j['text'] as String,
    ),
    'wait' => WaitStep(duration: _d(j, 'duration', 1)),
    'fade' => FadeStep(to: _d(j, 'to'), duration: _d(j, 'duration', 1)),
    'title' => TitleStep(
      text: j['text'] as String,
      subtitle: j['subtitle'] as String? ?? '',
      duration: _d(j, 'duration', 3),
    ),
    'tint' => TintStep(
      color: Color(int.parse(j['color'] as String, radix: 16)),
    ),
    'sound' => SoundStep(sound: j['sound'] as String),
    'parallel' => ParallelStep(
      steps: [
        for (final s in j['steps'] as List)
          CutsceneStep.fromJson(s as Map<String, dynamic>),
      ],
    ),
    final other => throw FormatException('Unknown cutscene step "$other"'),
  };
}

class SpawnStep extends CutsceneStep {
  const SpawnStep({
    required this.actor,
    required this.character,
    required this.x,
    required this.facing,
    required this.pose,
  });
  final String actor;
  final CharacterId character;
  final double x, facing;
  final Pose pose;
}

class PropStep extends CutsceneStep {
  const PropStep({required this.prop, required this.x});
  final SceneProp prop;
  final double x;
}

class MoveStep extends CutsceneStep {
  const MoveStep({
    required this.actor,
    required this.x,
    required this.duration,
  });
  final String actor;
  final double x, duration;
}

class PoseStep extends CutsceneStep {
  const PoseStep({required this.actor, required this.pose, this.facing});
  final String actor;
  final Pose pose;
  final double? facing;
}

class RemoveStep extends CutsceneStep {
  const RemoveStep({required this.actor});
  final String actor;
}

/// Frames the world around (x, y) showing [viewHeight] meters vertically.
class CameraStep extends CutsceneStep {
  const CameraStep({
    required this.x,
    required this.y,
    required this.viewHeight,
    required this.duration,
  });
  final double x, y, viewHeight, duration;
}

/// A line of dialogue; waits for the player to tap on.
class SayStep extends CutsceneStep {
  const SayStep({required this.speaker, required this.text});
  final String speaker;
  final String text;
}

class WaitStep extends CutsceneStep {
  const WaitStep({required this.duration});
  final double duration;
}

/// Fades to black ([to] = 1) or back ([to] = 0).
class FadeStep extends CutsceneStep {
  const FadeStep({required this.to, required this.duration});
  final double to, duration;
}

class TitleStep extends CutsceneStep {
  const TitleStep({
    required this.text,
    required this.subtitle,
    required this.duration,
  });
  final String text, subtitle;
  final double duration;
}

/// Colour washed over the scene, e.g. night blue.
class TintStep extends CutsceneStep {
  const TintStep({required this.color});
  final Color color;
}

class SoundStep extends CutsceneStep {
  const SoundStep({required this.sound});
  final String sound;
}

class ParallelStep extends CutsceneStep {
  const ParallelStep({required this.steps});
  final List<CutsceneStep> steps;
}
