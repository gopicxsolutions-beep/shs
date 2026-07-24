import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/gen/app_localizations.dart';
import '../routes/paths.dart';
import '../state/unsaved_changes.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/discard_changes_dialog.dart';

class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? right;
  final VoidCallback? onBack;
  const PageHeader({super.key, required this.title, this.subtitle, this.right, this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Neutral.c50.withValues(alpha: 0.9), border: Border(bottom: BorderSide(color: Neutral.c100))),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Tooltip(
              // Nullable, not `!`: PageHeader is on nearly every page, and a
              // handful of older widget tests still pump a bare `MaterialApp`
              // with no localization delegates configured (predating this
              // widget's l10n usage) — fall back to English rather than
              // crash their build in that case; a real app boot always has
              // the delegates via MaterialApp.router in main.dart.
              message: AppLocalizations.of(context)?.commonBack ?? 'Back',
              child: InkWell(
                onTap: onBack ?? () => _goBack(context),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 4)]),
                  child: const Icon(Icons.arrow_back, size: 18, color: Neutral.c700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              // preferredSize fixes this header to a constant 64px (it's
              // used as a Scaffold appBar, which enforces its height
              // exactly), so the title/subtitle column can't grow taller
              // to fit larger text the way a normal page body could. At a
              // scaled-up accessibility text size a single 17pt title line
              // (let alone title+subtitle together) can exceed that fixed
              // height and overflow — FittedBox scales the whole text
              // block down to fit instead, so it stays fully visible
              // within the fixed-height chrome (ellipsis above still
              // handles the width axis).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(17)),
                    if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
                  ],
                ),
              ),
            ),
            ?right,
          ],
        ),
      ),
    );
  }

  // Every route under the app's ShellRoute is a flat sibling reached via
  // `context.go()` (a full page-stack replace, not `context.push()`), so
  // there's almost never more than one page in the Navigator stack for
  // `Navigator.maybePop()` to act on — tapping Back was a silent no-op on
  // nearly every sub-page in the app. Fall back to the dashboard (the same
  // destination as the bottom nav's Home tab) whenever there's genuinely
  // nothing to pop, so the button always takes the user somewhere instead
  // of doing nothing.
  //
  // Checked first: `UnsavedChanges.dirty` — a form page currently being
  // edited raises this flag, and since this Back button is the single
  // shared entry point every sub-page's Back arrow goes through, this is
  // where an unsaved-input warning has to live (see `unsaved_changes.dart`
  // for why `PopScope` on the form page itself can't do this instead).
  static Future<void> _goBack(BuildContext context) async {
    if (UnsavedChanges.dirty) {
      final discard = await confirmDiscardChanges(context);
      if (!discard) return;
      UnsavedChanges.dirty = false;
    }
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(Paths.dashboard);
    }
  }
}
