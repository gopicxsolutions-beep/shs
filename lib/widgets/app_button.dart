import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum ButtonVariant { primary, secondary, outline, ghost, gold, danger }
enum ButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool fullWidth;
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.md,
    this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = switch (size) { ButtonSize.sm => 32.0, ButtonSize.md => 44.0, ButtonSize.lg => 52.0 };
    final fontSize = switch (size) { ButtonSize.sm => 12.0, ButtonSize.md => 14.0, ButtonSize.lg => 15.0 };
    // primary/gold/danger's original shades (Brand.c600, Gold.c500,
    // Accent.red600-on-red50) measured 4.33:1 / 2.39:1 / 4.41:1 against
    // their text color — all below the WCAG AA 4.5:1 threshold for
    // normal-sized text. Bumped to shades that pass (6.14:1 / 5.30:1 / 5.91:1).
    final (bg, fg) = switch (variant) {
      ButtonVariant.primary => (Brand.c700, Colors.white),
      ButtonVariant.secondary => (Brand.c50, Brand.c700),
      ButtonVariant.outline => (Colors.white, Neutral.c800),
      ButtonVariant.ghost => (Colors.transparent, Neutral.c700),
      ButtonVariant.gold => (Gold.c700, Colors.white),
      ButtonVariant.danger => (Accent.red50, Accent.red700),
    };
    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: fontSize + 2, color: fg), const SizedBox(width: 8)],
        // Flexible so a longer label (a longer localized string, or a
        // longer dynamic label like a busy-state message) ellipsizes
        // instead of overflowing the button on narrow screens.
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg))),
      ],
    );
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: variant == ButtonVariant.outline ? BorderSide(color: Neutral.c200) : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}
