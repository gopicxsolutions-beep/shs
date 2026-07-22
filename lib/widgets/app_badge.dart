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
      // red600/sky600 measure below the WCAG AA 4.5:1 contrast threshold for
      // normal-sized text against their 50-tone backgrounds — bumped one
      // shade darker (700) to pass.
      BadgeTone.danger => (Accent.red50, Accent.red700),
      BadgeTone.neutral => (Neutral.c100, Neutral.c600),
      BadgeTone.info => (Accent.sky50, Accent.sky700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          // Flexible so a badge placed next to other content in a
          // constrained Row (e.g. an EMI-due badge next to a "Details"
          // link) ellipsizes its (sometimes dynamic/unbounded) text
          // instead of overflowing — a plain Text here has no bound of
          // its own since the outer Row is `mainAxisSize.min`.
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg, height: 1))),
        ],
      ),
    );
  }
}
