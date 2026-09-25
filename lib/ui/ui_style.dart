import 'package:flutter/material.dart';

/// The game's cartoon UI kit: cream parchment panels with heavy dark
/// outlines, chunky glossy buttons that squash when pressed, and bold
/// white lettering with a dark stroke. Matches the outlined art in play.
abstract final class UiStyle {
  /// Outline and dark text.
  static const ink = Color(0xFF2B1A0E);

  /// Panel fill.
  static const panel = Color(0xFFFFF3D6);

  /// Deeper parchment for insets and rows.
  static const panelDeep = Color(0xFFF2DDAE);

  static const bronze = Color(0xFFC98A2E);
  static const parchment = Color(0xFFFFF3D6);
  static const blood = Color(0xFFD83B2E);
  static const gold = Color(0xFFFFC933);
  static const leaf = Color(0xFF5DBB3A);
  static const sky = Color(0xFF3FA6DC);

  static const title = TextStyle(
    color: Colors.white,
    fontSize: 44,
    fontWeight: FontWeight.w900,
    letterSpacing: 3,
  );
  static const heading = TextStyle(
    color: ink,
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );
  static const body = TextStyle(
    color: ink,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static BoxDecoration panelDecoration = BoxDecoration(
    color: panel,
    border: Border.all(color: ink, width: 3),
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x55000000), offset: Offset(0, 6), blurRadius: 0),
      BoxShadow(
        color: Color(0x33000000),
        offset: Offset(0, 10),
        blurRadius: 18,
      ),
    ],
  );

  /// A smaller, deeper inset inside panels (rows, cards, chips).
  static BoxDecoration insetDecoration = BoxDecoration(
    color: panelDeep,
    border: Border.all(color: ink.withValues(alpha: 0.5), width: 2),
    borderRadius: BorderRadius.circular(12),
  );
}

/// Bold white text with a dark outline, like the game's title lettering.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.size = 24,
    this.color = Colors.white,
    this.stroke = 5,
    this.letterSpacing = 1.5,
    this.textAlign,
  });

  final String text;
  final double size;
  final Color color;
  final double stroke;
  final double letterSpacing;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    TextStyle style(Paint? foreground) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: 1.05,
      color: foreground == null ? color : null,
      foreground: foreground,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: style(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = UiStyle.ink,
          ),
        ),
        Text(text, textAlign: textAlign, style: style(null)),
      ],
    );
  }
}

/// A ribbon banner carrying a panel's title.
class RibbonTitle extends StatelessWidget {
  const RibbonTitle(this.text, {super.key, this.color = UiStyle.blood});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
        border: Border.all(color: UiStyle.ink, width: 3),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), offset: Offset(0, 4)),
        ],
      ),
      child: OutlinedText(text, size: 22, textAlign: TextAlign.center),
    );
  }
}

/// Colour families for [CartoonButton].
enum ButtonTone {
  green(Color(0xFF8BE06A), Color(0xFF3E9E2C)),
  orange(Color(0xFFFFC266), Color(0xFFE0782A)),
  blue(Color(0xFF7FD3F7), Color(0xFF2E8FCB)),
  red(Color(0xFFFF7A6A), Color(0xFFC2322A)),
  plain(Color(0xFFFFF3D6), Color(0xFFE2C68E));

  const ButtonTone(this.light, this.dark);
  final Color light, dark;
}

/// A chunky, glossy button with a dark outline and a raised bottom edge.
/// It squashes down when pressed and springs back when released.
class CartoonButton extends StatefulWidget {
  const CartoonButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.tone = ButtonTone.green,
    this.size = 1,
    this.width,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonTone tone;

  /// Scales padding, text and icon; 1 is a standard button.
  final double size;

  /// Fixed width, or hug the content when null.
  final double? width;

  @override
  State<CartoonButton> createState() => _CartoonButtonState();
}

class _CartoonButtonState extends State<CartoonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final s = widget.size;
    final tone = enabled ? widget.tone : ButtonTone.plain;
    final textColor = tone == ButtonTone.plain ? UiStyle.ink : Colors.white;
    final label = widget.label;
    const edge = 5.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.93 : 1,
        duration: Duration(milliseconds: _down ? 60 : 220),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: Opacity(
          opacity: enabled ? 1 : 0.6,
          child: Container(
            width: widget.width,
            // The raised edge: a darker slab under the face.
            padding: EdgeInsets.only(bottom: _down ? 1 : edge),
            decoration: BoxDecoration(
              color: Color.lerp(tone.dark, UiStyle.ink, 0.45),
              border: Border.all(color: UiStyle.ink, width: 3),
              borderRadius: BorderRadius.circular(16 * s),
            ),
            margin: EdgeInsets.only(top: _down ? edge - 1 : 0),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: (label == null ? 10 : 18) * s,
                vertical: 9 * s,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [tone.light, tone.dark],
                ),
                borderRadius: BorderRadius.circular(13 * s),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gloss.
                  Positioned(
                    top: 0,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 7 * s,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null)
                        Icon(
                          widget.icon,
                          color: textColor,
                          size: 22 * s,
                          shadows: const [
                            Shadow(color: UiStyle.ink, offset: Offset(0, 2)),
                          ],
                        ),
                      if (widget.icon != null && label != null)
                        SizedBox(width: 8 * s),
                      if (label != null)
                        textColor == Colors.white
                            ? OutlinedText(
                                label.toUpperCase(),
                                size: 17 * s,
                                stroke: 4 * s,
                                letterSpacing: 1,
                              )
                            : Text(
                                label.toUpperCase(),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 17 * s,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The standard action button; kept for existing screens.
class SiegeButton extends StatelessWidget {
  const SiegeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ButtonTone.orange,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final ButtonTone tone;

  @override
  Widget build(BuildContext context) =>
      CartoonButton(label: label, icon: icon, onPressed: onPressed, tone: tone);
}

/// Slides and fades [child] in after [delay], with a springy overshoot.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = const Offset(0, 0.25),
    this.scale = true,
  });

  final Widget child;
  final Duration delay;

  /// Starting offset, as a fraction of the child's size.
  final Offset from;
  final bool scale;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spring = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: fade.value,
        child: FractionalTranslation(
          translation: widget.from * (1 - spring.value),
          child: Transform.scale(
            scale: widget.scale ? 0.6 + 0.4 * spring.value : 1,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
