import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/paged_result.dart';
import '../../models/profile.dart';
import '../../models/types.dart';
import '../../repositories/admin_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/shg_search_sheet.dart';

const _roleTone = <String, BadgeTone>{
  'member': BadgeTone.neutral,
  'leader': BadgeTone.brand,
  'crp': BadgeTone.info,
  'clf': BadgeTone.warning,
  'admin': BadgeTone.success,
};

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _repo = AdminRepository();
  final GlobalKey<AppAsyncBuilderState<PagedResult<Profile>>> _key = GlobalKey();
  String? _changingRoleFor;
  String? _assigningShgFor;
  String? _togglingActiveFor;

  // Local, appendable copy of the loaded pages — kept separate from the
  // AppAsyncBuilder's own snapshot data (which only ever holds the single
  // most-recently-*fetched* page) so a "Load more" tap can append to what's
  // already on screen instead of the next rebuild discarding it. Reset by
  // `_loadFirstPage` whenever the whole list reloads (e.g. after a role
  // change), which is the same "start over" semantics `reload()` already has
  // everywhere else in this app.
  List<Profile> _users = [];
  bool _hasMore = false;
  bool _loadingMore = false;

  Future<PagedResult<Profile>> _loadFirstPage() async {
    final page = await _repo.fetchAllUsers();
    _users = page.items;
    _hasMore = page.hasMore;
    return page;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _users.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchAllUsers(afterName: _users.last.name);
      setState(() {
        _users = [..._users, ...page.items];
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminUsersLoadMoreError)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _changeRole(Profile user) async {
    final selected = await showDialog<Role>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.adminUsersChangeRoleDialogTitle(user.name)),
        children: roles
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(r.id),
                  child: Text(r.label),
                ))
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.name == user.role) return;
    // Role changes are a high-stakes, irreversible-in-practice action (they
    // can grant/revoke admin access), so — matching this page's own
    // "Delete scheme?" confirm pattern — picking a role from the list above
    // is treated as a proposal, not an immediate apply. Without this, a
    // single mistaken tap on the wrong SimpleDialogOption (no current-role
    // indicator, no "are you sure") silently re-wrote a real user's access
    // level with no chance to back out.
    final currentRoleMatch = roles.where((r) => r.id.name == user.role);
    final currentLabel = currentRoleMatch.isEmpty ? user.role : currentRoleMatch.first.label;
    final newLabel = roleInfoFor(selected).label;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.adminUsersChangeRoleConfirmTitle),
        content: Text(AppLocalizations.of(context)!.adminUsersChangeRoleConfirmMessage(user.name, currentLabel, newLabel)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)!.adminUsersChangeRoleConfirmButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _changingRoleFor = user.id);
    try {
      await _repo.updateUserRole(user.id, selected.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? AppLocalizations.of(context)!.adminUsersRoleUpdatedMessage : AppLocalizations.of(context)!.adminUsersRoleUpdatedDemoMessage),
        ));
        _key.currentState?.reload();
        // The admin can appear in their own "Manage Users" list and change
        // their own role — `AppState.user` (read by every `isAdmin` check
        // across the app, including this page's own AppBar action and row
        // affordances) is a locally cached profile that this write bypasses
        // entirely, so without this it would keep showing the OLD role
        // (e.g. still "admin") until the next full profile reload, letting
        // the admin keep tapping now-unauthorized actions that the server
        // silently rejects underneath them.
        final selfId = context.read<AppState>().profile?.id;
        if (selfId != null && selfId == user.id) {
          await context.read<AppState>().refreshProfile();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminUsersUpdateRoleError)));
      }
    } finally {
      if (mounted) setState(() => _changingRoleFor = null);
    }
  }

  // Members reach an SHG via the join-request/approval flow — there is no
  // equivalent path for leader/crp/clf/admin signups, so an account picking
  // one of those roles with no SHG selected during onboarding was otherwise
  // permanently stuck with no in-app recourse (My SHG, Savings, Loans, etc.
  // all correctly show "not linked to an SHG" but nothing could ever fix
  // that). `profiles_update_self_or_admin`'s RLS already lets an admin write
  // any profile column, so this only needed a UI, not a schema/RLS change.
  Future<void> _assignShg(Profile user) async {
    final selected = await showShgSearchSheet(context, search: _repo.searchShgs);
    if (selected == null || !mounted) return;
    setState(() => _assigningShgFor = user.id);
    try {
      await _repo.assignShg(user.id, selected.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? AppLocalizations.of(context)!.adminUsersAssignedToMessage(selected.name) : AppLocalizations.of(context)!.adminUsersAssignedToDemoMessage),
        ));
        _key.currentState?.reload();
        // Same stale-cache risk as the self role-change case above: if the
        // admin assigns an SHG to their OWN (unlinked) profile, `AppState`'s
        // cached shgId/shgName won't reflect it without an explicit refresh.
        final selfId = context.read<AppState>().profile?.id;
        if (selfId != null && selfId == user.id) {
          await context.read<AppState>().refreshProfile();
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminUsersAssignShgError)));
      }
    } finally {
      if (mounted) setState(() => _assigningShgFor = null);
    }
  }

  /// Same two-step "propose then confirm" caution as `_changeRole` above —
  /// deactivating a real account is high-stakes (they lose app access
  /// immediately, server-side) and reactivating restores it, neither of
  /// which should follow from a single misplaced tap.
  Future<void> _toggleActive(Profile user) async {
    final l10n = AppLocalizations.of(context)!;
    final activating = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activating ? l10n.adminUsersReactivateConfirmTitle : l10n.adminUsersDeactivateConfirmTitle),
        content: Text(activating ? l10n.adminUsersReactivateConfirmMessage(user.name) : l10n.adminUsersDeactivateConfirmMessage(user.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(activating ? l10n.adminUsersReactivateConfirmButton : l10n.adminUsersDeactivateConfirmButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _togglingActiveFor = user.id);
    try {
      await _repo.setActive(user.id, activating);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(activating ? l10n.adminUsersReactivatedMessage : l10n.adminUsersDeactivatedMessage)));
        _key.currentState?.reload();
        // Same self-write staleness risk `_changeRole`/`_assignShg` already
        // guard against: an admin can appear in their own list and
        // deactivate their own account (there's nothing here stopping that
        // — an admin choosing to lock themselves out, e.g. handing off the
        // role, is a legitimate use as long as another active admin still
        // exists — see `guard_last_admin_deactivation`, migration 0084).
        // Without this refresh, AppState's cached profile would keep
        // reporting `isActive: true` until the next unrelated reload, so
        // the router's `accountDeactivated` redirect wouldn't fire even
        // though the server has already cut this account off.
        final selfId = context.read<AppState>().profile?.id;
        if (selfId != null && selfId == user.id) {
          await context.read<AppState>().refreshProfile();
        }
      }
    } catch (e) {
      if (mounted) {
        // `guard_last_admin_deactivation` (migration 0084) raises a specific,
        // readable exception rather than silently no-opping — surface its
        // actual reason instead of the generic fallback, so an admin who
        // tries to deactivate the platform's last admin account learns why,
        // not just that "something went wrong."
        final isLastAdmin = e is PostgrestException && e.message.contains('last active admin');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLastAdmin ? l10n.adminUsersLastAdminError : l10n.adminUsersToggleActiveError)));
      }
    } finally {
      if (mounted) setState(() => _togglingActiveFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().user.role == Role.admin;

    return Scaffold(
      appBar: PageHeader(title: AppLocalizations.of(context)!.adminUsersManageTitle),
      body: AppAsyncBuilder<PagedResult<Profile>>(
        key: _key,
        future: _loadFirstPage,
        // Renders `_users`/`_hasMore` (this State's own appendable copy),
        // not the `data` snapshot directly — see their doc comment above:
        // `data` only ever reflects the single page this exact future
        // resolved to, so re-rendering straight from it would silently
        // drop anything a prior "Load more" tap had already appended.
        builder: (context, data) {
          if (_users.isEmpty) {
            return AppEmptyState(icon: Icons.people_rounded, message: AppLocalizations.of(context)!.adminUsersNoUsersFoundMessage);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _users.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _users.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _loadingMore
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : TextButton(onPressed: _loadMore, child: Text(AppLocalizations.of(context)!.actionLoadMore)),
                  ),
                );
              }
              final u = _users[i];
              final busy = _changingRoleFor == u.id;
              final assigningShg = _assigningShgFor == u.id;
              final togglingActive = _togglingActiveFor == u.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  // Guard against every one of this row's own in-flight
                  // actions — not just `busy` (role-change): without also
                  // checking `assigningShg`/`togglingActive`, an admin could
                  // open the role picker for a user WHILE that same user's
                  // "assign SHG"/deactivate write was still in flight,
                  // firing two concurrent profile updates for the same row.
                  onTap: isAdmin && !busy && !assigningShg && !togglingActive ? () => _changeRole(u) : null,
                  // Column, not one wide Row: the trailing badges + up-to-2
                  // action icons + chevron previously all lived in the same
                  // Row as the avatar/name — at 320px width + 2.0x text
                  // scale (this app's stress-test floor) that overflowed the
                  // card. Splitting the badges/actions onto their own
                  // `Wrap` below the avatar/name row lets them wrap onto a
                  // second line instead of forcing everything into one.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AppAvatar(name: u.name, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u.name, style: AppTheme.sans(13, weight: FontWeight.w700)),
                              if (u.mobile != null) Text(u.mobile!, style: AppTheme.sans(11, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        if (isAdmin) Icon(Icons.chevron_right_rounded, color: Neutral.c300),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!u.isActive) AppBadge(text: AppLocalizations.of(context)!.adminUsersInactiveBadge, tone: BadgeTone.danger),
                          AppBadge(text: u.role, tone: _roleTone[u.role] ?? BadgeTone.neutral),
                          if (isAdmin && u.shgId == null)
                            IconButton(
                              icon: assigningShg
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.add_link_rounded),
                              tooltip: AppLocalizations.of(context)!.adminUsersAssignShgTooltip,
                              color: Brand.c600,
                              onPressed: assigningShg ? null : () => _assignShg(u),
                            ),
                          if (isAdmin)
                            IconButton(
                              icon: togglingActive
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(u.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined),
                              tooltip: u.isActive ? AppLocalizations.of(context)!.adminUsersDeactivateTooltip : AppLocalizations.of(context)!.adminUsersReactivateTooltip,
                              color: u.isActive ? Accent.red600 : Brand.c600,
                              onPressed: togglingActive ? null : () => _toggleActive(u),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
