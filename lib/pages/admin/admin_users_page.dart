import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
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
  final GlobalKey<AppAsyncBuilderState<List<Profile>>> _key = GlobalKey();
  String? _changingRoleFor;
  String? _assigningShgFor;

  Future<void> _changeRole(Profile user) async {
    final selected = await showDialog<Role>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Change role — ${user.name}'),
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
        title: const Text('Change role?'),
        content: Text('Change ${user.name}\'s role from $currentLabel to $newLabel?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Change')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _changingRoleFor = user.id);
    try {
      await _repo.updateUserRole(user.id, selected.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Role updated' : 'Demo mode — role not saved (connect Supabase to persist)'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this role. Please try again.')));
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
          content: Text(SupabaseService.isConfigured ? 'Assigned to ${selected.name}' : 'Demo mode — assignment not saved (connect Supabase to persist)'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not assign this SHG. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _assigningShgFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().user.role == Role.admin;

    return Scaffold(
      appBar: const PageHeader(title: 'Manage Users'),
      body: AppAsyncBuilder<List<Profile>>(
        key: _key,
        future: _repo.fetchAllUsers,
        builder: (context, users) {
          if (users.isEmpty) {
            return const AppEmptyState(icon: Icons.people_rounded, message: 'No users found');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              final busy = _changingRoleFor == u.id;
              final assigningShg = _assigningShgFor == u.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  // Guard against both this row's own actions — not just
                  // `busy` (role-change in flight): without also checking
                  // `assigningShg`, an admin could tap the card to open the
                  // role picker for a user WHILE that same user's "assign
                  // SHG" write was still in flight, firing two concurrent
                  // profile updates for the same row.
                  onTap: isAdmin && !busy && !assigningShg ? () => _changeRole(u) : null,
                  child: Row(children: [
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
                    AppBadge(text: u.role, tone: _roleTone[u.role] ?? BadgeTone.neutral),
                    if (isAdmin && u.shgId == null)
                      IconButton(
                        icon: assigningShg
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add_link_rounded),
                        tooltip: 'Assign SHG',
                        color: Brand.c600,
                        onPressed: assigningShg ? null : () => _assignShg(u),
                      ),
                    if (isAdmin) ...[const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, color: Neutral.c300)],
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
