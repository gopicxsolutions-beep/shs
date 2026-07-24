import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/types.dart';
import '../routes/paths.dart';
import '../state/app_state.dart';
import '../state/unsaved_changes.dart';
import '../theme/colors.dart';
import '../widgets/discard_changes_dialog.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: _BottomNav(location: location),
    );
  }
}

class _NavItem {
  final String to;
  final String label;
  final IconData icon;
  final bool center;
  const _NavItem(this.to, this.label, this.icon, {this.center = false});
}

class _BottomNav extends StatelessWidget {
  final String location;
  const _BottomNav({required this.location});

  // A form page mid-edit (loan application, meeting schedule, product
  // listing, ...) raises `UnsavedChanges.dirty`; since every bottom-nav tap
  // is a `context.go()` full-page-stack replace (not a pop `PopScope` could
  // intercept — see `unsaved_changes.dart`), this is the only place that
  // can warn before silently discarding whatever the user typed.
  static Future<void> _navigate(BuildContext context, String to) async {
    if (UnsavedChanges.dirty) {
      final discard = await confirmDiscardChanges(context);
      if (!discard) return;
      UnsavedChanges.dirty = false;
    }
    if (context.mounted) GoRouter.of(context).go(to);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().user.role;
    final isOversight = role == Role.crp || role == Role.clf || role == Role.admin;
    // A crp/clf/admin profile has no `shg_id` of its own (see
    // ShgRepository.fetchShg's doc comment) — `Paths.shg` (ShgHomePage)
    // always resolves that to null and dead-ends on "You're not linked to
    // an SHG yet". For these roles the tab means "browse every SHG", not
    // "my SHG", so it has to point somewhere that actually lists them:
    // AnalyticsShgListPage (already what both the CRP and CLF dashboards
    // link their own "view all SHGs" actions to) for crp/clf, and the
    // admin's existing SHG management screen for admin.
    final shgsTabPath = switch (role) {
      Role.admin => Paths.adminShgs,
      Role.crp || Role.clf => Paths.analyticsShgList,
      Role.member || Role.leader => Paths.shg,
    };
    final l10n = AppLocalizations.of(context)!;
    final items = <_NavItem>[
      _NavItem(Paths.dashboard, l10n.navHome, Icons.home_rounded),
      _NavItem(shgsTabPath, isOversight ? l10n.navSHGs : l10n.navMySHG, isOversight ? Icons.apartment_rounded : Icons.groups_rounded),
      _NavItem(Paths.services, l10n.navServices, Icons.grid_view_rounded, center: true),
      _NavItem(Paths.marketplace, l10n.navMarket, Icons.storefront_rounded),
      _NavItem(Paths.profile, l10n.navProfile, Icons.person_rounded),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.97), border: Border(top: BorderSide(color: Neutral.c100)), boxShadow: navShadow),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.map((item) {
              final active = location == item.to || (item.to != Paths.dashboard && location.startsWith(item.to));
              // The active tab is conveyed only by icon/text color (Brand.c600
              // vs Neutral.c400) — real for a sighted user, invisible to a
              // screen reader, which would announce every tab identically as
              // just "Home, tab" / "Services, tab" with no indication which
              // one is currently selected. `Semantics(selected:)` is the
              // standard Flutter mechanism TalkBack/VoiceOver use to append
              // "selected" to a tab's announcement, matching what a built-in
              // BottomNavigationBar gets for free — this custom nav bar
              // (needed for the raised center FAB-style item) has to set it
              // explicitly.
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: item.label,
                  onTap: () => _navigate(context, item.to),
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: () => _navigate(context, item.to),
                      child: item.center
                      ? OverflowBox(
                          maxHeight: double.infinity,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: const Offset(0, -14),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: active ? Brand.c700 : Brand.c600,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
                                  ),
                                  child: Icon(item.icon, color: Colors.white, size: 24),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, -10),
                                child: Text(item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Brand.c600 : Neutral.c500)),
                              ),
                            ],
                          ),
                        )
                      // The nav bar is a fixed-height (64) SizedBox by
                      // design (standard bottom-nav chrome), so it can't
                      // grow to fit larger text the way a page body can. At
                      // a scaled-up accessibility text size the icon +
                      // label no longer fit that height and would overflow
                      // — FittedBox scales the whole icon+label group down
                      // together instead, keeping both visible and the bar
                      // itself compact (same fix shape as PageHeader below).
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item.icon, size: 22, color: active ? Brand.c600 : Neutral.c400),
                              const SizedBox(height: 2),
                              Text(item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Brand.c600 : Neutral.c400)),
                            ],
                          ),
                        ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
