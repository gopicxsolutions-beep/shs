import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

class AppListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  const AppListRow({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.chevron = true});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
                  ),
              ],
            ),
          ),
          // Flexible (not left unconstrained) so a wide trailing widget —
          // an amount + badge column, or a button whose label text grows at
          // a large accessibility text scale — shrinks to fit the row
          // instead of overflowing it; loose fit keeps trailing at its
          // natural size whenever there's room, matching every existing
          // caller's normal-scale appearance exactly.
          if (trailing != null) Flexible(fit: FlexFit.loose, child: trailing!),
          if (onTap != null && chevron) Icon(Icons.chevron_right, size: 18, color: Neutral.c300),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
