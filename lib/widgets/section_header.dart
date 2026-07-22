import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final Widget? icon;
  const SectionHeader({super.key, required this.title, this.subtitle, this.action, this.onAction, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Wrapped in Expanded so the title/subtitle shrink (and ellipsize)
          // instead of pushing the row past its bounds — on a real
          // phone-width screen, a long `title` combined with the `action`
          // link on the right overflowed the row (found via
          // test/routes/all_routes_smoke_test.dart, which exercises this
          // widget through the real app shell at a phone-sized viewport,
          // unlike the wider default test surface other tests use).
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.display(15), overflow: TextOverflow.ellipsis),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, style: AppTheme.sans(12, color: Neutral.c500), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (action != null && onAction != null)
            // Flexible so a longer action label ("Federation reports", not
            // just "See all"/"Manage") ellipsizes at a scaled-up
            // accessibility text size instead of overflowing the outer
            // Row outright — Expanded(title) above can only shrink the
            // title side down to zero, it can't make this side's own
            // natural width fit on its own.
            Flexible(
              child: InkWell(
                onTap: onAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(action!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600))),
                    Icon(Icons.chevron_right, size: 14, color: Brand.c600),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
