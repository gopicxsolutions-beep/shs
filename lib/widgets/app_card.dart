import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final bool padded;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padded = true, this.onTap, this.color, this.gradient, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padded ? const EdgeInsets.all(16) : null,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? Colors.white) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? Neutral.c100.withValues(alpha: 0.6)),
        boxShadow: cardShadow,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
