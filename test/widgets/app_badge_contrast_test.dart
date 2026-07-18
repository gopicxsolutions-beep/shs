import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/theme/colors.dart';
import 'package:shg_saathi/widgets/app_badge.dart';

import 'wcag_contrast.dart';

/// Regression coverage for a real WCAG AA contrast failure found this
/// session: AppBadge's `danger` tone (Accent.red50/Accent.red600, 4.41:1)
/// and `info` tone (Accent.sky50/Accent.sky600, 3.84:1) both measured below
/// the 4.5:1 threshold required for normal-sized text — badges render at
/// 11px, well under the "large text" 18pt/14pt-bold threshold that would
/// only need 3:1. Both were bumped one shade darker. This computes the
/// actual contrast ratio for every BadgeTone's foreground/background pair,
/// so a future color change that regresses contrast fails a real check
/// instead of only looking fine in code review.
void main() {
  const pairs = {
    BadgeTone.brand: (Brand.c50, Brand.c700),
    BadgeTone.gold: (Gold.c50, Gold.c700),
    BadgeTone.success: (Accent.emerald50, Accent.emerald700),
    BadgeTone.warning: (Accent.amber50, Accent.amber700),
    BadgeTone.danger: (Accent.red50, Accent.red700),
    BadgeTone.neutral: (Neutral.c100, Neutral.c600),
    BadgeTone.info: (Accent.sky50, Accent.sky700),
  };

  for (final entry in pairs.entries) {
    test('${entry.key} badge text meets WCAG AA (4.5:1) against its background', () {
      final (bg, fg) = entry.value;
      final ratio = contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '${entry.key} measured $ratio:1 — below the AA threshold for normal-sized text');
    });
  }
}
