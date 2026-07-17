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
    final (bg, fg) = switch (variant) {
      ButtonVariant.primary => (Brand.c600, Colors.white),
      ButtonVariant.secondary => (Brand.c50, Brand.c700),
      ButtonVariant.outline => (Colors.white, Neutral.c800),
      ButtonVariant.ghost => (Colors.transparent, Neutral.c700),
      ButtonVariant.gold => (Gold.c500, Colors.white),
      ButtonVariant.danger => (Accent.red50, Accent.red600),
    };
    final child = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: fontSize + 2, color: fg), const SizedBox(width: 8)],
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg)),
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
