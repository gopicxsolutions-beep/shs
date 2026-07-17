import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

enum TileTone { brand, gold, sky, rose, violet, ink }

class IconTile extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final TileTone tone;
  final String? badge;
  const IconTile({super.key, required this.onTap, required this.icon, required this.label, this.tone = TileTone.brand, this.badge});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      TileTone.brand => (Brand.c50, Brand.c600),
      TileTone.gold => (Gold.c50, Gold.c600),
      TileTone.sky => (Accent.sky50, Accent.sky600),
      TileTone.rose => (Accent.rose50, Accent.rose600),
      TileTone.violet => (Accent.violet50, Accent.violet600),
      TileTone.ink => (Neutral.c100, Neutral.c600),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 22, color: fg),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: const BoxDecoration(color: Accent.red500, shape: BoxShape.circle),
                      child: Text(badge!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: AppTheme.sans(11, weight: FontWeight.w600, color: Neutral.c700)),
          ],
        ),
      ),
    );
  }
}
