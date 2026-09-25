import 'dart:async';

import 'package:flutter/material.dart';

import '../../cutscene/cutscene_player.dart';
import '../../game/siege_game.dart';
import '../ui_style.dart';
import '../widgets/portrait.dart';

/// Letterbox, dialogue, titles and fades for the playing cutscene.
class CutsceneOverlay extends StatelessWidget {
  const CutsceneOverlay({super.key, required this.game});

  final SiegeGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CutscenePlayer?>(
      valueListenable: game.cutscene,
      builder: (context, player, _) {
        if (player == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: player.advance,
          child: Stack(
            children: [
              ValueListenableBuilder<Color>(
                valueListenable: player.tint,
                builder: (_, tint, _) => Positioned.fill(
                  child: IgnorePointer(child: ColoredBox(color: tint)),
                ),
              ),
              // Letterbox bars.
              const Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.black),
                ),
              ),
              const Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.black),
                ),
              ),
              ValueListenableBuilder<(String, String)?>(
                valueListenable: player.title,
                builder: (_, title, _) => title == null
                    ? const SizedBox.shrink()
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title.$1,
                              style: UiStyle.title,
                              textAlign: TextAlign.center,
                            ),
                            if (title.$2.isNotEmpty)
                              Text(
                                title.$2,
                                style: UiStyle.heading.copyWith(
                                  color: UiStyle.bronze,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              ValueListenableBuilder<SpokenLine?>(
                valueListenable: player.line,
                builder: (_, line, _) => line == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(60, 0, 60, 54),
                          child: _DialogueBox(
                            key: ValueKey(line),
                            line: line,
                            game: game,
                            onFinishedTap: player.advance,
                          ),
                        ),
                      ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: player.fade,
                builder: (_, fade, _) => IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: fade.clamp(0, 1)),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned(
                top: 52,
                right: 60,
                child: TextButton(
                  onPressed: player.skip,
                  child: Text(
                    'SKIP ›',
                    style: UiStyle.body.copyWith(
                      color: UiStyle.bronze,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Speaker portrait and a line typed out letter by letter. The first tap
/// completes the line; the next one moves on.
class _DialogueBox extends StatefulWidget {
  const _DialogueBox({
    super.key,
    required this.line,
    required this.game,
    required this.onFinishedTap,
  });

  final SpokenLine line;
  final SiegeGame game;
  final VoidCallback onFinishedTap;

  @override
  State<_DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<_DialogueBox> {
  static const _charsPerTick = 1;
  late final Timer _timer;
  int _shown = 0;

  bool get _complete => _shown >= widget.line.text.length;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      if (_complete) return;
      setState(() => _shown += _charsPerTick);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.line.text;
    return GestureDetector(
      onTap: () {
        if (_complete) {
          widget.onFinishedTap();
        } else {
          setState(() => _shown = text.length);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: UiStyle.panelDecoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Portrait(
              look: widget.line.look,
              theme: widget.game.theme,
              size: 68,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.line.look.name.toUpperCase(),
                    style: UiStyle.body.copyWith(
                      color: UiStyle.bronze,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.substring(0, _shown.clamp(0, text.length)),
                    style: UiStyle.body.copyWith(fontSize: 16, height: 1.35),
                  ),
                ],
              ),
            ),
            if (_complete)
              const Icon(
                Icons.keyboard_double_arrow_right,
                color: UiStyle.bronze,
              ),
          ],
        ),
      ),
    );
  }
}
