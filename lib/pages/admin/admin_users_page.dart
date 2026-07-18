import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    if (selected == null) return;
    setState(() => _changingRoleFor = user.id);
    try {
      await _repo.updateUserRole(user.id, selected.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Role updated' : 'Demo mode — role not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this role. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _changingRoleFor = null);
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: isAdmin && !busy ? () => _changeRole(u) : null,
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
