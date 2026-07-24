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
  // What the badge count means (e.g. "3 pending" vs "3 new") — callers know
  // this, IconTile doesn't. Falls back to the bare "$label, $badge" if a
  // caller doesn't pass one, which is still tied together rather than two
  // disconnected nodes, just less descriptive.
  final String? badgeSemanticLabel;
  const IconTile({super.key, required this.onTap, required this.icon, required this.label, this.tone = TileTone.brand, this.badge, this.badgeSemanticLabel});

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
    // The count badge (e.g. "3" pending Approvals) is a visually-obvious
    // overlay next to the label, but as separate Text nodes a screen reader
    // announces the bare number ("3") with nothing tying it to what it
    // counts — it's read either before or after "Approvals" with no
    // indication it means "3 pending". Semantics + ExcludeSemantics (the
    // pattern already used for TrendChart and the announcement unread-dot)
    // replaces both with one coherent label; the visual content underneath
    // is unchanged.
    return Semantics(
      label: badge == null ? label : (badgeSemanticLabel ?? '$label, $badge'),
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
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
        ),
      ),
    );
  }
}
