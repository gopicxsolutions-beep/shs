import 'package:flutter/material.dart';
import '../theme/colors.dart';

enum ProgressTone { brand, gold, danger, info }

class AppProgressBar extends StatelessWidget {
  final num value;
  final num max;
  final ProgressTone tone;
  const AppProgressBar({super.key, required this.value, this.max = 100, this.tone = ProgressTone.brand});

  @override
  Widget build(BuildContext context) {
    final pct = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final color = switch (tone) {
      ProgressTone.brand => Brand.c500,
      ProgressTone.gold => Gold.c500,
      ProgressTone.danger => Accent.red500,
      ProgressTone.info => Accent.sky600,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Container(height: 8, width: double.infinity, color: Neutral.c100),
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 8,
              width: constraints.maxWidth * pct,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
