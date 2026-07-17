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
          Row(
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.display(15)),
                  if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: AppTheme.sans(12, color: Neutral.c500))),
                ],
              ),
            ],
          ),
          if (action != null && onAction != null)
            InkWell(
              onTap: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                  Icon(Icons.chevron_right, size: 14, color: Brand.c600),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
