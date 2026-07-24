import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum StatTone { brand, gold, ink, danger }

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final StatTone tone;
  final String? trend;
  const StatCard({super.key, required this.label, required this.value, this.icon, this.tone = StatTone.brand, this.trend});

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      StatTone.brand => Brand.c600,
      StatTone.gold => Gold.c500,
      StatTone.ink => Neutral.c900,
      StatTone.danger => Accent.red500,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, boxShadow: cardShadow),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(right: -16, top: -24, child: _dot(80)),
            Positioned(right: -32, bottom: 0, child: _dot(64)),
            // The decorative dots above are absolutely-positioned and can
            // overlap a neighboring card's bounds, which throws off screen
            // readers' geometry-based traversal across a row of these
            // (observed reading two cards' labels, then both their values,
            // interleaved). Merging this card's text into one semantics
            // node sidesteps that entirely.
            Semantics(
              label: [label, value, if (trend != null) trend].join(', '),
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75), fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text(value, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (trend != null) ...[
                            const SizedBox(height: 4),
                            Text(trend!, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    if (icon != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, size: 16, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
      );
}
