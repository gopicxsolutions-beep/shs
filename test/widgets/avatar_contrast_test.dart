import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/theme/colors.dart';

import 'wcag_contrast.dart';

/// Regression coverage for 2 real WCAG AA contrast failures found this
/// session in AppAvatar's hash-selected initials-text palette: the sky
/// entry (Accent.sky50/Accent.sky600, 3.84:1) and rose entry
/// (Accent.rose50/Accent.rose600, 4.28:1) both measured below the 4.5:1
/// threshold for normal-sized text — since the avatar assigned to any
/// given member's name is a deterministic hash, this wasn't a rare edge
/// case, it was roughly 2 out of every 5 members getting initials that
/// failed contrast. Both bumped one shade darker.
///
/// This mirrors AppAvatar's private `_palette` list directly rather than
/// importing it (it's a private implementation detail of the widget) —
/// if that palette's colors ever change, this test's copy must be updated
/// alongside it, which is an acceptable trade-off for testing a `private`
/// field without exposing it just for tests.
void main() {
  const palette = [
    (Brand.c100, Brand.c700),
    (Gold.c100, Gold.c700),
    (Accent.sky50, Accent.sky700),
    (Accent.rose50, Accent.rose700),
    (Accent.violet100, Accent.violet600),
  ];

  for (var i = 0; i < palette.length; i++) {
    test('AppAvatar palette entry $i meets WCAG AA (4.5:1) for its initials text', () {
      final (bg, fg) = palette[i];
      final ratio = contrastRatio(bg, fg);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: 'palette entry $i measured $ratio:1 — below the AA threshold for normal-sized text');
    });
  }
}
