import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../game/siege_game.dart';
import '../../story/characters.dart';

/// A character on the cutscene stage; walks, turns and strikes poses.
class StoryActor extends PositionComponent with HasGameReference<SiegeGame> {
  StoryActor({
    required this.look,
    required double x,
    this.facing = 1,
    this.pose = Pose.stand,
  }) : super(position: Vector2(x, 0), priority: 6);

  final CharacterLook look;
  double facing;
  Pose pose;

  double _time = 0;
  double? _fromX, _toX;
  double _moveTime = 0, _moveDuration = 0;
  Completer<void>? _arrived;

  /// Walks to [x] over [duration] seconds, facing the way it goes.
  Future<void> walkTo(double x, double duration) {
    _arrived?.complete();
    _fromX = position.x;
    _toX = x;
    _moveTime = 0;
    _moveDuration = duration <= 0 ? 0.001 : duration;
    facing = x >= position.x ? 1 : -1;
    pose = Pose.walk;
    return (_arrived = Completer<void>()).future;
  }

  /// Ends any walk immediately (when a cutscene is skipped).
  void finishMove() {
    if (_toX != null) position.x = _toX!;
    _toX = null;
    if (pose == Pose.walk) pose = Pose.stand;
    _arrived?.complete();
    _arrived = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final to = _toX;
    if (to == null) return;
    _moveTime += dt;
    final t = (_moveTime / _moveDuration).clamp(0.0, 1.0);
    position.x = _fromX! + (to - _fromX!) * t;
    if (t >= 1) finishMove();
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..save()
      ..scale(facing, 1);
    game.theme.drawCharacter(canvas, look, pose: pose, time: _time);
    canvas.restore();
  }
}

class StoryProp extends PositionComponent with HasGameReference<SiegeGame> {
  StoryProp({required this.prop, required double x})
    : super(position: Vector2(x, 0), priority: 4);

  final SceneProp prop;

  @override
  void render(Canvas canvas) =>
      game.theme.drawSceneProp(canvas, prop, game.realTime);
}
