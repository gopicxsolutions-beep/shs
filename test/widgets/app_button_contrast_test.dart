import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/theme/colors.dart';
import 'package:shg_saathi/widgets/app_button.dart';

import 'wcag_contrast.dart';

/// Regression coverage for 2 real WCAG AA contrast failures found this
/// session in AppButton's label text, the highest-traffic text/background
/// pairing in the app since AppButton is the shared button used almost
/// everywhere: `primary` (Brand.c600/white, 4.33:1 — the *default* variant,
/// used by nearly every "Submit"/"Add"/"Continue" button in the app) and
/// `gold` (Gold.c500/white, 2.39:1 — a serious failure). Both bumped one
/// shade darker; `danger` (Accent.red50/Accent.red600, 4.41:1) got the
/// same fix already covered by app_badge_contrast_test.dart's identical
/// color pair.
void main() {
  const pairs = {
    ButtonVariant.primary: (Brand.c700, Colors.white),
    ButtonVariant.secondary: (Brand.c50, Brand.c700),
    ButtonVariant.outline: (Colors.white, Neutral.c800),
    ButtonVariant.gold: (Gold.c700, Colors.white),
    ButtonVariant.danger: (Accent.red50, Accent.red700),
  };

  for (final entry in pairs.entries) {
    test('${entry.key} button label meets WCAG AA (4.5:1) against its background', () {
      final (bg, fg) = entry.value;
      final ratio = contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '${entry.key} measured $ratio:1 — below the AA threshold for normal-sized text');
    });
  }
}
