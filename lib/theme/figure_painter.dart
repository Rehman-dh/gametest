import 'dart:math' as math;
import 'dart:ui';

import '../core/era.dart';
import '../levels/level_data.dart';

/// How a figure is standing at this moment. All values are blended, so a
/// soldier eases from idle into alarm rather than snapping.
class FigurePose {
  const FigurePose({
    required this.time,
    this.seed = 0,
    this.alert = 0,
    this.panic = 0,
    this.limp = 0,
    this.era = Era.egypt,
  });

  /// Seconds, for breathing and idle motion.
  final double time;

  /// Varies timing between figures so a garrison doesn't move in step.
  final int seed;

  /// 0–1: bracing behind the shield, eyes on the incoming shot.
  final double alert;

  /// 0–1: arms flung up, legs buckling (hit, or thrown about).
  final double panic;

  /// 0–1: knocked out, every joint slack.
  final double limp;

  /// Whose army: Egyptian linen and bronze, or Roman iron and red.
  final Era era;
}

/// Draws the enemy garrison as shaded, jointed figures in Egyptian kit:
/// bronze-capped spearmen with tall hide shields, archers, engineers with
/// mallets, and the king in a striped headdress. Figures are drawn facing
/// right with their feet at the origin, [height] meters tall; callers flip
/// the canvas to face them the other way.
class FigurePainter {
  const FigurePainter._();

  static final _fill = Paint();
  static final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF2B1A0E);

  static const _skin = Color(0xFFE0A878);
  static const _skinShade = Color(0xFFB57A50);
  static const _linen = Color(0xFFFFF8E6);
  static const _linenShade = Color(0xFFD9CBA8);
  static const _bronze = Color(0xFFE0A63E);
  static const _bronzeDark = Color(0xFF6E4A1C);
  static const _leather = Color(0xFF5C3A22);
  static const _wood = Color(0xFF6B4A2E);

  static double heightOf(UnitKind kind) => switch (kind) {
    UnitKind.king || UnitKind.pharaoh => 2.2,
    _ => 2.0,
  };

  /// Set for the figure being painted: Roman kit instead of Egyptian.
  static bool _roman = false;

  /// Set for the figure being painted: Persian kit.
  static bool _persian = false;

  /// Set for the figure being painted: the Black Baron's men-at-arms.
  static bool _medieval = false;

  static void paint(Canvas canvas, UnitKind kind, FigurePose pose) {
    _roman = pose.era == Era.rome || kind == UnitKind.legionary;
    _persian = !_roman && pose.era == Era.persia;
    _medieval = !_roman && pose.era == Era.medieval;
    final spearman = kind == UnitKind.soldier || kind == UnitKind.legionary;
    final h = heightOf(kind);
    final u = h / 1.8; // body unit: 1 at soldier height
    final t = pose.time + pose.seed * 1.37;
    final alert = pose.alert.clamp(0.0, 1.0);
    final panic = pose.panic.clamp(0.0, 1.0);
    final limp = pose.limp.clamp(0.0, 1.0);

    // Idle life: breathing, a slow shift of weight, a glance now and then.
    final breathe = math.sin(t * 2.1) * 0.012 * (1 - panic);
    final sway = math.sin(t * 0.7) * 0.03 * (1 - alert) * (1 - panic);
    final crouch = 0.06 * alert + 0.1 * panic + 0.25 * limp;

    _edge.strokeWidth = 0.05;
    canvas
      ..save()
      ..scale(u);

    final hip = Offset(sway, -0.92 + crouch);
    final neck = hip + Offset(0.03 * alert - 0.05 * panic, -0.55 - breathe);
    final head = neck + const Offset(0.02, -0.22);

    // Legs: stance widens when braced or buckling.
    final spread = 0.13 + 0.06 * alert + 0.1 * panic;
    final bend = 0.05 + 0.12 * (alert + panic + limp);
    final backFoot = Offset(-spread, 0);
    final frontFoot = Offset(spread * 1.1, 0);

    // Far limbs first, in shadow.
    _leg(canvas, hip + const Offset(-0.04, 0), backFoot, bend, shade: true);
    final royal = kind == UnitKind.king || kind == UnitKind.pharaoh;

    // Far arm: holds the spear, bow or mallet.
    final farShoulder = neck + const Offset(-0.07, 0.07);
    final wave = math.sin(t * 14) * panic;
    final farHand = Offset.lerp(
      farShoulder + Offset(0.12, 0.42 - 0.08 * alert),
      farShoulder + Offset(-0.2 + 0.1 * wave, -0.45),
      panic,
    )!;
    if (spearman) {
      // Spear, leaning forward as he braces.
      final tilt = 0.1 + 0.35 * alert - 0.3 * panic;
      final dir = Offset(math.sin(tilt), -math.cos(tilt));
      _spear(canvas, farHand - dir * 0.75, farHand + dir * 1.35);
    } else if (kind == UnitKind.engineer) {
      _mallet(canvas, farHand, 0.4 + 0.8 * alert);
    }
    _arm(canvas, farShoulder, farHand, shade: true);

    _leg(canvas, hip + const Offset(0.04, 0), frontFoot, bend);

    // Torso and dress.
    if (royal) {
      _robe(canvas, hip, neck);
    } else {
      _kilt(canvas, hip, kind);
      _chest(canvas, hip, neck, kind);
      if (_roman && spearman) _lorica(canvas, hip, neck);
    }

    _head(canvas, head, kind, t, alert, panic);

    // Near arm: shield for spearmen, bow for archers, crook for the king.
    final nearShoulder = neck + const Offset(0.06, 0.08);
    final nearHand = Offset.lerp(
      Offset.lerp(
        nearShoulder + const Offset(0.16, 0.4),
        nearShoulder + const Offset(0.3, 0.02),
        alert,
      )!,
      nearShoulder + Offset(0.12 - 0.1 * wave, -0.5),
      panic,
    )!;
    _arm(canvas, nearShoulder, nearHand);
    switch (kind) {
      case UnitKind.soldier || UnitKind.legionary:
        final at = nearHand + Offset(0.08, 0.05 - 0.1 * alert);
        if (_roman) {
          _scutum(canvas, at, big: kind == UnitKind.legionary);
        } else if (_persian) {
          _spara(canvas, at);
        } else if (_medieval) {
          _heater(canvas, at);
        } else {
          _shield(canvas, at);
        }
      case UnitKind.archer:
        _bow(canvas, nearHand, alert);
      case UnitKind.king || UnitKind.pharaoh:
        _crook(canvas, nearHand);
      case UnitKind.engineer:
        break;
    }
    canvas.restore();
  }

  // ------------------------------------------------------------ limbs

  static void _limb(
    Canvas canvas,
    Offset a,
    Offset joint,
    Offset b,
    double width,
    Color color,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..color = color;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(joint.dx, joint.dy)
      ..lineTo(b.dx, b.dy);
    canvas
      ..drawPath(
        path,
        Paint.from(paint)
          ..color = const Color(0xFF2B1A0E)
          ..strokeWidth = width + 0.06,
      )
      ..drawPath(path, paint);
  }

  static void _leg(
    Canvas canvas,
    Offset hip,
    Offset foot,
    double bend, {
    bool shade = false,
  }) {
    final knee = Offset.lerp(hip, foot, 0.5)! + Offset(bend, 0);
    _limb(
      canvas,
      hip,
      knee,
      foot + const Offset(0, -0.04),
      0.1,
      shade ? _skinShade : _skin,
    );
    // Sandal.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(foot.dx - 0.05, foot.dy - 0.05, foot.dx + 0.12, foot.dy),
        const Radius.circular(0.02),
      ),
      _fill..color = shade ? const Color(0xFF3A2616) : _leather,
    );
  }

  static void _arm(
    Canvas canvas,
    Offset shoulder,
    Offset hand, {
    bool shade = false,
  }) {
    final mid = Offset.lerp(shoulder, hand, 0.5)!;
    final elbow = mid + Offset(-(hand.dy - shoulder.dy) * 0.18, 0.04);
    _limb(canvas, shoulder, elbow, hand, 0.075, shade ? _skinShade : _skin);
    canvas.drawCircle(hand, 0.045, _fill..color = shade ? _skinShade : _skin);
  }

  // ------------------------------------------------------------ body

  static void _kilt(Canvas canvas, Offset hip, UnitKind kind) {
    final kilt = Path()
      ..moveTo(hip.dx - 0.19, hip.dy - 0.08)
      ..lineTo(hip.dx + 0.19, hip.dy - 0.08)
      ..lineTo(hip.dx + 0.25, hip.dy + 0.3)
      ..quadraticBezierTo(hip.dx, hip.dy + 0.34, hip.dx - 0.23, hip.dy + 0.28)
      ..close();
    final b = kilt.getBounds();
    canvas
      ..drawPath(
        kilt,
        _fill
          ..shader = Gradient.linear(b.topLeft, b.bottomRight, switch (kind) {
            // The Baron's men wear black.
            _ when _medieval => const [Color(0xFF2A2A34), Color(0xFF14141A)],
            // The garrison wears red, so they stand out on pale stone.
            UnitKind.soldier ||
            UnitKind.legionary => const [Color(0xFFE5483A), Color(0xFFA82A1F)],
            UnitKind.archer => const [Color(0xFF6FB443), Color(0xFF3F7A22)],
            _ => const [Color(0xFFC08A52), Color(0xFF8A5A2E)],
          }),
      )
      ..drawPath(kilt, _edge);
    _fill.shader = null;
    // Pleats.
    final pleat = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 0.015;
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        Offset(hip.dx + i * 0.07, hip.dy - 0.02),
        Offset(hip.dx + i * 0.085, hip.dy + 0.28),
        pleat,
      );
    }
    // Belt.
    canvas.drawRect(
      Rect.fromLTRB(hip.dx - 0.2, hip.dy - 0.1, hip.dx + 0.2, hip.dy - 0.04),
      _fill..color = kind == UnitKind.engineer ? _leather : _bronzeDark,
    );
  }

  static void _chest(Canvas canvas, Offset hip, Offset neck, UnitKind kind) {
    final chest = Path()
      ..moveTo(hip.dx - 0.17, hip.dy - 0.08)
      ..quadraticBezierTo(
        hip.dx - 0.22,
        neck.dy + 0.25,
        neck.dx - 0.16,
        neck.dy + 0.04,
      )
      ..lineTo(neck.dx + 0.14, neck.dy + 0.04)
      ..quadraticBezierTo(
        hip.dx + 0.24,
        neck.dy + 0.25,
        hip.dx + 0.17,
        hip.dy - 0.08,
      )
      ..close();
    final b = chest.getBounds();
    canvas
      ..drawPath(
        chest,
        _fill
          ..shader = Gradient.linear(
            b.centerLeft,
            b.centerRight,
            const [_skinShade, _skin, Color(0xFF9A6644)],
            [0, 0.6, 1],
          ),
      )
      ..drawPath(chest, _edge);
    _fill.shader = null;
    // Leather harness (spearmen, archers) or apron (engineers).
    if (kind == UnitKind.engineer) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          b.left + 0.04,
          b.top + 0.12,
          b.right - 0.04,
          hip.dy + 0.25,
          const Radius.circular(0.04),
        ),
        _fill..color = _leather,
      );
    } else {
      final strap = Paint()
        ..color = _leather
        ..strokeWidth = 0.05;
      canvas
        ..drawLine(
          b.topLeft + const Offset(0.05, 0.02),
          Offset(b.right - 0.04, hip.dy - 0.1),
          strap,
        )
        ..drawCircle(
          Offset(b.center.dx, b.center.dy - 0.02),
          0.045,
          _fill..color = _bronze,
        );
    }
  }

  static void _robe(Canvas canvas, Offset hip, Offset neck) {
    final robe = Path()
      ..moveTo(neck.dx - 0.18, neck.dy + 0.04)
      ..lineTo(neck.dx + 0.18, neck.dy + 0.04)
      ..quadraticBezierTo(hip.dx + 0.26, hip.dy, hip.dx + 0.3, -0.05)
      ..lineTo(hip.dx - 0.28, -0.05)
      ..quadraticBezierTo(hip.dx - 0.24, hip.dy, neck.dx - 0.18, neck.dy + 0.04)
      ..close();
    final b = robe.getBounds();
    canvas
      ..drawPath(
        robe,
        _fill
          ..shader = Gradient.linear(
            b.centerLeft,
            b.centerRight,
            _roman
                ? const [
                    Color(0xFF4A1E5E),
                    Color(0xFF7B3A93),
                    Color(0xFF4A1E5E),
                  ]
                : _medieval
                ? const [
                    Color(0xFF1E1E26),
                    Color(0xFF3A3A48),
                    Color(0xFF1E1E26),
                  ]
                : _persian
                ? const [
                    Color(0xFF8C1F2E),
                    Color(0xFFC23A4A),
                    Color(0xFF8C1F2E),
                  ]
                : const [_linenShade, Color(0xFFF4EEDD), _linenShade],
            const [0, 0.5, 1],
          ),
      )
      ..drawPath(robe, _edge);
    _fill.shader = null;
    // Gold sash and broad collar of lapis and gold.
    canvas.drawLine(
      Offset(hip.dx, hip.dy - 0.1),
      Offset(hip.dx + 0.02, -0.08),
      Paint()
        ..color = const Color(0xFFC9A13E)
        ..strokeWidth = 0.06,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: neck + const Offset(0, 0.02),
          width: 0.36 + i * 0.07,
          height: 0.2 + i * 0.06,
        ),
        0.2,
        math.pi - 0.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035
          ..color = i.isEven
              ? const Color(0xFFD9B04A)
              : const Color(0xFF2A4C8E),
      );
    }
  }

  static void _head(
    Canvas canvas,
    Offset head,
    UnitKind kind,
    double t,
    double alert,
    double panic,
  ) {
    // Neck.
    canvas.drawRect(
      Rect.fromCenter(
        center: head + const Offset(-0.01, 0.12),
        width: 0.09,
        height: 0.1,
      ),
      _fill..color = _skinShade,
    );
    const r = 0.16;
    final face = Paint()
      ..shader = Gradient.radial(
        head + const Offset(0.04, -0.03),
        r * 1.4,
        const [_skin, _skinShade],
      );
    canvas
      ..drawOval(
        Rect.fromCenter(center: head, width: r * 1.9, height: r * 2.15),
        face,
      )
      ..drawOval(
        Rect.fromCenter(center: head, width: r * 1.9, height: r * 2.15),
        _edge,
      );
    // Profile: nose, eye with kohl, a mouth that opens in fear.
    canvas
      ..drawPath(
        Path()
          ..moveTo(head.dx + r * 0.85, head.dy - 0.01)
          ..lineTo(head.dx + r * 1.12, head.dy + 0.03)
          ..lineTo(head.dx + r * 0.85, head.dy + 0.045)
          ..close(),
        _fill..color = _skinShade,
      )
      ..drawLine(
        head + Offset(r * 0.35, -0.015),
        head + Offset(r * 0.75, -0.02),
        Paint()
          ..color = const Color(0xFF1A1410)
          ..strokeWidth = 0.02
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(
        head + Offset(r * 0.62, -0.018),
        0.014 + 0.008 * panic,
        _fill..color = const Color(0xFF0E0A08),
      )
      ..drawOval(
        Rect.fromCenter(
          center: head + Offset(r * 0.66, 0.065),
          width: 0.05,
          height: 0.012 + 0.035 * panic,
        ),
        _fill..color = const Color(0xFF3A1E14),
      );

    switch (kind) {
      case UnitKind.king || UnitKind.pharaoh:
        if (_roman) {
          _laurel(canvas, head, r);
        } else if (_persian || _medieval) {
          _tiara(canvas, head, r);
        } else {
          _nemes(canvas, head, r);
        }
      case UnitKind.soldier || UnitKind.archer || UnitKind.engineer
          when _medieval:
        _kettleHat(canvas, head, r);
      case UnitKind.soldier || UnitKind.archer || UnitKind.engineer
          when _persian:
        _turban(canvas, head, r, kind);
      case UnitKind.archer:
        // Striped linen headcloth.
        _headcloth(canvas, head, r, const Color(0xFF6E7A48), _linen);
      case UnitKind.engineer:
        _headcloth(
          canvas,
          head,
          r,
          const Color(0xFF8A6A44),
          const Color(0xFFBFA27A),
        );
      case UnitKind.soldier || UnitKind.legionary when _roman:
        _galea(canvas, head, r);
      case UnitKind.soldier || UnitKind.legionary:
        // Bronze cap with a crest.
        final cap = Path()
          ..addArc(
            Rect.fromCenter(
              center: head + const Offset(0, -0.01),
              width: r * 2.2,
              height: r * 2.3,
            ),
            math.pi,
            math.pi,
          )
          ..close();
        final b = cap.getBounds();
        canvas
          ..drawPath(
            cap,
            _fill
              ..shader = Gradient.linear(
                b.topLeft,
                b.bottomRight,
                const [Color(0xFFE2B865), _bronze, _bronzeDark],
                const [0, 0.5, 1],
              ),
          )
          ..drawPath(cap, _edge);
        _fill.shader = null;
        canvas
          ..drawRect(
            Rect.fromLTRB(
              b.left - 0.01,
              b.bottom - 0.02,
              b.right + 0.01,
              b.bottom + 0.015,
            ),
            _fill..color = _bronzeDark,
          )
          ..drawLine(
            Offset(head.dx - r * 0.1, b.top + 0.01),
            Offset(head.dx - r * 0.5, b.top - 0.08),
            Paint()
              ..color = const Color(0xFF8C2A20)
              ..strokeWidth = 0.05
              ..strokeCap = StrokeCap.round,
          );
    }
  }

  static void _headcloth(
    Canvas canvas,
    Offset head,
    double r,
    Color a,
    Color b,
  ) {
    final cloth = Path()
      ..moveTo(head.dx + r * 0.7, head.dy - r * 0.4)
      ..quadraticBezierTo(
        head.dx,
        head.dy - r * 1.5,
        head.dx - r * 1.0,
        head.dy - r * 0.2,
      )
      ..lineTo(head.dx - r * 1.1, head.dy + r * 1.3)
      ..lineTo(head.dx - r * 0.5, head.dy + r * 1.1)
      ..lineTo(head.dx - r * 0.2, head.dy - r * 0.2)
      ..close();
    canvas
      ..drawPath(cloth, _fill..color = b)
      ..drawPath(cloth, _edge)
      ..drawLine(
        Offset(head.dx + r * 0.7, head.dy - r * 0.4),
        Offset(head.dx - r * 0.2, head.dy - r * 0.2),
        Paint()
          ..color = a
          ..strokeWidth = 0.03,
      );
  }

  static void _nemes(Canvas canvas, Offset head, double r) {
    final nemes = Path()
      ..moveTo(head.dx + r * 0.75, head.dy - r * 0.45)
      ..quadraticBezierTo(
        head.dx,
        head.dy - r * 1.6,
        head.dx - r * 1.05,
        head.dy - r * 0.3,
      )
      ..lineTo(head.dx - r * 1.35, head.dy + r * 1.8)
      ..lineTo(head.dx - r * 0.55, head.dy + r * 1.6)
      ..lineTo(head.dx - r * 0.25, head.dy - r * 0.1)
      ..close();
    canvas
      ..save()
      ..clipPath(nemes);
    final b = nemes.getBounds();
    for (var i = 0; i < 12; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          b.left,
          b.top + i * b.height / 12,
          b.width,
          b.height / 12,
        ),
        _fill
          ..color = i.isEven
              ? const Color(0xFFD9B04A)
              : const Color(0xFF22407E),
      );
    }
    canvas
      ..restore()
      ..drawPath(nemes, _edge)
      // Uraeus: the rearing cobra on the brow.
      ..drawCircle(
        head + Offset(r * 0.72, -r * 0.55),
        0.03,
        _fill..color = const Color(0xFFE8C45A),
      );
  }

  // ------------------------------------------------------------ gear

  // ------------------------------------------------------------ Medieval

  /// A steel kettle hat with a wide brim.
  static void _kettleHat(Canvas canvas, Offset head, double r) {
    final crown = Path()
      ..addArc(
        Rect.fromCenter(
          center: head + Offset(0, -r * 0.1),
          width: r * 2.0,
          height: r * 2.1,
        ),
        math.pi,
        math.pi,
      )
      ..close();
    final brim = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: head + Offset(0, -r * 0.05),
        width: r * 2.9,
        height: r * 0.35,
      ),
      Radius.circular(r * 0.17),
    );
    final steel = Paint()
      ..shader = Gradient.linear(
        head + Offset(-r, -r),
        head + Offset(r, 0),
        const [Color(0xFFDDE2E6), Color(0xFF8A9299)],
      );
    canvas
      ..drawPath(crown, steel)
      ..drawPath(crown, _edge)
      ..drawRRect(brim, steel)
      ..drawRRect(brim, _edge);
  }

  /// A black heater shield with the Baron's gold chevron.
  static void _heater(Canvas canvas, Offset centre) {
    final rect = Rect.fromCenter(center: centre, width: 0.46, height: 0.6);
    final shape = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + rect.height * 0.45)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom - 0.08,
        centre.dx,
        rect.bottom,
      )
      ..quadraticBezierTo(
        rect.left,
        rect.bottom - 0.08,
        rect.left,
        rect.top + rect.height * 0.45,
      )
      ..close();
    canvas
      ..drawPath(shape, _fill..color = const Color(0xFF22222A))
      ..save()
      ..clipPath(shape)
      ..drawPath(
        Path()
          ..moveTo(rect.left, rect.center.dy + 0.08)
          ..lineTo(centre.dx, rect.center.dy - 0.1)
          ..lineTo(rect.right, rect.center.dy + 0.08)
          ..lineTo(rect.right, rect.center.dy + 0.2)
          ..lineTo(centre.dx, rect.center.dy + 0.02)
          ..lineTo(rect.left, rect.center.dy + 0.2)
          ..close(),
        _fill..color = const Color(0xFFE2B84A),
      )
      ..restore()
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = const Color(0xFF2B1A0E),
      );
  }

  // ------------------------------------------------------------ Persia

  /// A wrapped turban with a tail; archers wear blue, others white.
  static void _turban(Canvas canvas, Offset head, double r, UnitKind kind) {
    final cloth = kind == UnitKind.archer
        ? const Color(0xFF3F7FC0)
        : const Color(0xFFF4EEDF);
    final wrap = Path()
      ..addOval(
        Rect.fromCenter(
          center: head + Offset(0, -r * 0.55),
          width: r * 2.25,
          height: r * 1.35,
        ),
      );
    canvas
      ..drawPath(
        Path()
          ..moveTo(head.dx - r * 0.9, head.dy - r * 0.4)
          ..quadraticBezierTo(
            head.dx - r * 1.5,
            head.dy + r * 0.3,
            head.dx - r * 1.2,
            head.dy + r * 1.1,
          )
          ..lineTo(head.dx - r * 0.8, head.dy + r * 0.9)
          ..close(),
        _fill..color = cloth,
      )
      ..drawPath(wrap, _fill..color = cloth)
      ..drawPath(wrap, _edge);
    final fold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..color = const Color(0x55000000);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: head + Offset(0, -r * (0.3 + 0.2 * i)),
          width: r * 2.1,
          height: r * 0.8,
        ),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        fold,
      );
    }
    canvas.drawCircle(
      head + Offset(r * 0.75, -r * 0.55),
      0.04,
      _fill..color = const Color(0xFFD83B2E),
    );
  }

  /// The royal kidaris: a tall golden crown.
  static void _tiara(Canvas canvas, Offset head, double r) {
    final crown = Path()
      ..moveTo(head.dx - r * 0.95, head.dy - r * 0.55)
      ..lineTo(head.dx - r * 0.75, head.dy - r * 2.0)
      ..lineTo(head.dx - r * 0.35, head.dy - r * 1.6)
      ..lineTo(head.dx, head.dy - r * 2.2)
      ..lineTo(head.dx + r * 0.35, head.dy - r * 1.6)
      ..lineTo(head.dx + r * 0.75, head.dy - r * 2.0)
      ..lineTo(head.dx + r * 0.95, head.dy - r * 0.55)
      ..close();
    final b = crown.getBounds();
    canvas
      ..drawPath(
        crown,
        _fill
          ..shader = Gradient.linear(b.topCenter, b.bottomCenter, const [
            Color(0xFFFFE08A),
            Color(0xFFD9A63E),
          ]),
      )
      ..drawPath(crown, _edge);
    _fill.shader = null;
    canvas.drawCircle(
      head + Offset(0, -r * 1.05),
      0.05,
      _fill..color = const Color(0xFF2E9CB0),
    );
  }

  /// The spara: a round wicker shield, painted with a sun.
  static void _spara(Canvas canvas, Offset centre) {
    const r = 0.26;
    canvas
      ..drawCircle(centre, r, _fill..color = const Color(0xFFC89A58))
      ..drawCircle(centre, r * 0.55, _fill..color = const Color(0xFF2E9CB0));
    final ray = Paint()
      ..color = const Color(0xFFE2B84A)
      ..strokeWidth = 0.03;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        centre + Offset(math.cos(a), math.sin(a)) * r * 0.6,
        centre + Offset(math.cos(a), math.sin(a)) * r * 0.9,
        ray,
      );
    }
    canvas
      ..drawCircle(centre, 0.05, _fill..color = const Color(0xFFE2B84A))
      ..drawCircle(
        centre,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = const Color(0xFF2B1A0E),
      );
  }

  // ------------------------------------------------------------ Rome

  /// Segmented iron armour over the chest.
  static void _lorica(Canvas canvas, Offset hip, Offset neck) {
    final plate = Paint()
      ..shader = Gradient.linear(
        Offset(hip.dx - 0.2, 0),
        Offset(hip.dx + 0.2, 0),
        const [Color(0xFF8E959C), Color(0xFFD5DADF), Color(0xFF6E757C)],
        const [0, 0.55, 1],
      );
    final top = neck.dy + 0.1, bottom = hip.dy - 0.06;
    final bands = 4;
    final h = (bottom - top) / bands;
    for (var i = 0; i < bands; i++) {
      final r = RRect.fromLTRBR(
        hip.dx - 0.19,
        top + i * h,
        hip.dx + 0.19,
        top + (i + 1) * h + 0.01,
        const Radius.circular(0.03),
      );
      canvas
        ..drawRRect(r, plate)
        ..drawRRect(r, _edge);
    }
  }

  /// The legionary's galea: an iron helmet with a red transverse crest.
  static void _galea(Canvas canvas, Offset head, double r) {
    final cap = Path()
      ..addArc(
        Rect.fromCenter(
          center: head + const Offset(0, -0.01),
          width: r * 2.2,
          height: r * 2.3,
        ),
        math.pi,
        math.pi,
      )
      ..close();
    final b = cap.getBounds();
    canvas
      // Crest across the crown.
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(head.dx - 0.01, b.top - 0.05),
            width: r * 2.1,
            height: 0.12,
          ),
          const Radius.circular(0.06),
        ),
        _fill..color = const Color(0xFFD8322A),
      )
      ..drawPath(
        cap,
        _fill
          ..shader = Gradient.linear(b.topLeft, b.bottomRight, const [
            Color(0xFFE3E7EA),
            Color(0xFF9AA2A9),
          ]),
      )
      ..drawPath(cap, _edge);
    _fill.shader = null;
    // Neck guard and cheek piece.
    canvas
      ..drawRect(
        Rect.fromLTRB(
          b.left - 0.03,
          b.bottom - 0.02,
          b.left + 0.1,
          b.bottom + 0.1,
        ),
        _fill..color = const Color(0xFF9AA2A9),
      )
      ..drawRect(
        Rect.fromLTRB(
          head.dx + r * 0.2,
          b.bottom - 0.02,
          head.dx + r * 0.5,
          b.bottom + 0.12,
        ),
        _fill..color = const Color(0xFFB8BFC5),
      );
  }

  /// A general's golden laurel wreath.
  static void _laurel(Canvas canvas, Offset head, double r) {
    final leaf = Paint()..color = const Color(0xFFE2B84A);
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012
      ..color = const Color(0xFF7A5A14);
    for (var i = 0; i < 7; i++) {
      final a = math.pi * (1.05 + i * 0.13);
      final c = head + Offset(math.cos(a) * r * 1.02, math.sin(a) * r * 1.05);
      final o = Rect.fromCenter(center: c, width: 0.09, height: 0.05);
      canvas
        ..save()
        ..translate(c.dx, c.dy)
        ..rotate(a + math.pi / 2)
        ..translate(-c.dx, -c.dy)
        ..drawOval(o, leaf)
        ..drawOval(o, vein)
        ..restore();
    }
  }

  /// The scutum: a tall, curved red shield with a bronze boss; the
  /// legionary's is big enough to hide behind.
  static void _scutum(Canvas canvas, Offset centre, {required bool big}) {
    final rect = Rect.fromCenter(
      center: centre + Offset(0.02, big ? -0.05 : 0),
      width: big ? 0.52 : 0.4,
      height: big ? 1.05 : 0.78,
    );
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(0.06));
    canvas.drawRRect(
      shape,
      _fill
        ..shader = Gradient.linear(
          rect.centerLeft,
          rect.centerRight,
          const [Color(0xFFA82A1F), Color(0xFFE5483A), Color(0xFF8C1F16)],
          const [0, 0.5, 1],
        ),
    );
    _fill.shader = null;
    final gold = Paint()
      ..color = const Color(0xFFE2B84A)
      ..strokeWidth = 0.035
      ..style = PaintingStyle.stroke;
    canvas
      ..drawRRect(shape.deflate(0.04), gold)
      // Crossed lightning bolts on the face.
      ..drawLine(
        rect.topCenter + const Offset(-0.1, 0.12),
        rect.bottomCenter + const Offset(0.1, -0.12),
        gold,
      )
      ..drawLine(
        rect.topCenter + const Offset(0.1, 0.12),
        rect.bottomCenter + const Offset(-0.1, -0.12),
        gold,
      )
      ..drawCircle(rect.center, 0.07, _fill..color = const Color(0xFFD9A63E))
      ..drawCircle(rect.center, 0.07, _edge)
      ..drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = const Color(0xFF2B1A0E),
      );
  }

  static void _spear(Canvas canvas, Offset butt, Offset tip) {
    canvas.drawLine(
      butt,
      tip,
      Paint()
        ..color = _wood
        ..strokeWidth = 0.04
        ..strokeCap = StrokeCap.round,
    );
    final dir = (tip - butt) / (tip - butt).distance;
    final side = Offset(-dir.dy, dir.dx);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + dir.dx * 0.22, tip.dy + dir.dy * 0.22)
        ..lineTo(tip.dx + side.dx * 0.05, tip.dy + side.dy * 0.05)
        ..lineTo(tip.dx - side.dx * 0.05, tip.dy - side.dy * 0.05)
        ..close(),
      _fill..color = const Color(0xFFCB9A4C),
    );
  }

  static void _shield(Canvas canvas, Offset centre) {
    // A tall hide shield with a rounded top, as Egyptian infantry carried.
    final rect = Rect.fromCenter(center: centre, width: 0.4, height: 0.72);
    final shape = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + 0.2)
      ..arcToPoint(
        Offset(rect.right, rect.top + 0.2),
        radius: const Radius.circular(0.2),
      )
      ..lineTo(rect.right, rect.bottom)
      ..close();
    canvas.drawPath(
      shape,
      _fill
        ..shader = Gradient.linear(
          rect.centerLeft,
          rect.centerRight,
          const [Color(0xFFD83B2E), Color(0xFFF05A48), Color(0xFFA82A1F)],
          const [0, 0.5, 1],
        ),
    );
    _fill.shader = null;
    // Cowhide patches.
    canvas
      ..save()
      ..clipPath(shape);
    // A pale band down the middle.
    canvas.drawRect(
      Rect.fromCenter(center: centre, width: 0.1, height: 0.8),
      _fill..color = const Color(0xFFFFF1D6),
    );
    canvas
      ..restore()
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = const Color(0xFF2B1A0E),
      )
      ..drawCircle(
        centre + const Offset(0, -0.08),
        0.06,
        _fill..color = _bronze,
      );
  }

  static void _bow(Canvas canvas, Offset hand, double draw) {
    final bow = Path()
      ..moveTo(hand.dx - 0.05, hand.dy - 0.45)
      ..quadraticBezierTo(
        hand.dx + 0.25 + 0.1 * draw,
        hand.dy,
        hand.dx - 0.05,
        hand.dy + 0.45,
      );
    canvas
      ..drawPath(
        bow,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.04
          ..color = _wood,
      )
      ..drawLine(
        Offset(hand.dx - 0.05, hand.dy - 0.45),
        Offset(hand.dx - 0.05 - 0.2 * draw, hand.dy + 0.45 - 0.45),
        Paint()
          ..color = const Color(0xCCE8E0CC)
          ..strokeWidth = 0.01,
      )
      ..drawLine(
        Offset(hand.dx - 0.05 - 0.2 * draw, hand.dy),
        Offset(hand.dx - 0.05, hand.dy + 0.45),
        Paint()
          ..color = const Color(0xCCE8E0CC)
          ..strokeWidth = 0.01,
      );
  }

  static void _mallet(Canvas canvas, Offset hand, double lift) {
    final dir = Offset(math.sin(lift), -math.cos(lift));
    final head = hand + dir * 0.45;
    canvas
      ..drawLine(
        hand - dir * 0.08,
        head,
        Paint()
          ..color = _wood
          ..strokeWidth = 0.04,
      )
      ..save()
      ..translate(head.dx, head.dy)
      ..rotate(lift)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(-0.12, -0.07, 0.12, 0.07),
          const Radius.circular(0.02),
        ),
        _fill..color = const Color(0xFF8A6A48),
      )
      ..restore();
  }

  static void _crook(Canvas canvas, Offset hand) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(hand.dx, hand.dy + 0.2)
      ..lineTo(hand.dx, hand.dy - 0.35)
      ..arcToPoint(
        Offset(hand.dx - 0.12, hand.dy - 0.33),
        radius: const Radius.circular(0.07),
      );
    canvas
      ..drawPath(path, paint..color = const Color(0xFF22407E))
      ..drawPath(
        path,
        paint
          ..color = const Color(0xFFD9B04A)
          ..strokeWidth = 0.015,
      );
  }
}
