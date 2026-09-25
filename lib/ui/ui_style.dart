import 'package:flutter/material.dart';

/// Shared colors and text styles for the serious bronze-and-parchment UI.
abstract final class UiStyle {
  static const ink = Color(0xFF1A140F);
  static const panel = Color(0xEE231A13);
  static const bronze = Color(0xFFB0874A);
  static const parchment = Color(0xFFE8D9B8);
  static const blood = Color(0xFF9E2B25);

  static const title = TextStyle(
    color: parchment,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: 6,
  );
  static const heading = TextStyle(
    color: parchment,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );
  static const body = TextStyle(color: parchment, fontSize: 16);

  static BoxDecoration panelDecoration = BoxDecoration(
    color: panel,
    border: Border.all(color: bronze, width: 2),
    borderRadius: BorderRadius.circular(6),
  );
}

class SiegeButton extends StatelessWidget {
  const SiegeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? null : Icon(icon, size: 18),
      label: Text(label.toUpperCase()),
      style: OutlinedButton.styleFrom(
        foregroundColor: UiStyle.parchment,
        backgroundColor: UiStyle.ink,
        side: const BorderSide(color: UiStyle.bronze, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
