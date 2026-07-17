import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum BadgeTone { brand, gold, success, warning, danger, neutral, info }

class AppBadge extends StatelessWidget {
  final String text;
  final BadgeTone tone;
  final bool dot;
  const AppBadge({super.key, required this.text, this.tone = BadgeTone.neutral, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.brand => (Brand.c50, Brand.c700),
      BadgeTone.gold => (Gold.c50, Gold.c700),
      BadgeTone.success => (Accent.emerald50, Accent.emerald700),
      BadgeTone.warning => (Accent.amber50, Accent.amber700),
      BadgeTone.danger => (Accent.red50, Accent.red600),
      BadgeTone.neutral => (Neutral.c100, Neutral.c600),
      BadgeTone.info => (Accent.sky50, Accent.sky600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg, height: 1)),
        ],
      ),
    );
  }
}
