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
                        child: PopIn(
                          key: ValueKey(title),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedText(
                                title.$1,
                                size: 44,
                                stroke: 8,
                                letterSpacing: 3,
                                textAlign: TextAlign.center,
                              ),
                              if (title.$2.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                OutlinedText(
                                  title.$2,
                                  size: 22,
                                  color: UiStyle.gold,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
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
                top: 54,
                right: 60,
                child: PopIn(
                  delay: const Duration(milliseconds: 400),
                  from: const Offset(0.3, 0),
                  child: CartoonButton(
                    label: 'Skip',
                    icon: Icons.fast_forward_rounded,
                    tone: ButtonTone.plain,
                    size: 0.7,
                    onPressed: player.skip,
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
      child: PopIn(
        from: const Offset(0, 0.3),
        scale: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: UiStyle.panelDecoration,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Portrait(
                look: widget.line.look,
                theme: widget.game.theme,
                size: 72,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The speaker's name on a tag in their own colours.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.line.look.cloth,
                        border: Border.all(color: UiStyle.ink, width: 2.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: OutlinedText(
                        widget.line.look.name.toUpperCase(),
                        size: 13,
                        stroke: 3.5,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.substring(0, _shown.clamp(0, text.length)),
                      style: UiStyle.body.copyWith(fontSize: 16, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (_complete)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: UiStyle.blood,
                    size: 28,
                    shadows: [Shadow(color: UiStyle.ink, offset: Offset(0, 2))],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
