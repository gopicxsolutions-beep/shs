import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/profile.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/profile_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileRepo = ProfileRepository();
  final _shgRepo = ShgRepository();
  final GlobalKey<AppAsyncBuilderState<ShgProfile?>> _key = GlobalKey();

  Future<void> _editProfile(Profile? profile) async {
    if (profile == null) return;
    final name = TextEditingController(text: profile.name);
    final village = TextEditingController(text: profile.village ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(hintText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: village, decoration: const InputDecoration(hintText: 'Village')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await _profileRepo.upsertMyProfile(name: name.text.trim(), role: profile.role, village: village.text.trim());
    if (!mounted) return;
    await context.read<AppState>().refreshProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(SupabaseService.isConfigured ? 'Profile updated' : 'Demo mode — not saved (connect Supabase to persist)'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.user;
    final profile = appState.profile;

    return Scaffold(
      appBar: PageHeader(
        title: 'Profile',
        right: IconButton(icon: const Icon(Icons.edit_rounded), tooltip: 'Edit profile', onPressed: () => _editProfile(profile)),
      ),
      body: AppAsyncBuilder<ShgProfile?>(
        key: _key,
        future: () => _shgRepo.fetchShg(profile?.shgId),
        builder: (context, shg) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    AppAvatar(name: user.name, size: 72),
                    const SizedBox(height: 12),
                    Text(user.name, style: AppTheme.display(18)),
                    const SizedBox(height: 6),
                    AppBadge(text: roleInfoFor(user.role).label, tone: _roleTone[user.role.name] ?? BadgeTone.neutral),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(Icons.phone_rounded, 'Mobile', user.mobile),
                    const Divider(height: 20),
                    _row(Icons.location_on_rounded, 'Village', user.village),
                    const Divider(height: 20),
                    _row(Icons.groups_rounded, 'SHG', shg?.name ?? (SupabaseService.isConfigured ? 'Not yet approved' : user.shgName)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padded: false,
                child: Column(
                  children: [
                    _linkRow(context, icon: Icons.settings_rounded, label: 'Settings', onTap: () => context.go(Paths.profileSettings)),
                    const Divider(height: 1, color: Neutral.c100),
                    _linkRow(context, icon: Icons.language_rounded, label: 'Language', onTap: () => context.go(Paths.profileLanguage)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Sign out',
                variant: ButtonVariant.outline,
                fullWidth: true,
                onPressed: () async {
                  await context.read<AppState>().signOut();
                  if (context.mounted) context.go(Paths.splash);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: Neutral.c400),
          const SizedBox(width: 10),
          Text(label, style: AppTheme.sans(12, color: Neutral.c500)),
          const Spacer(),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: AppTheme.sans(13, weight: FontWeight.w600))),
        ],
      );

  Widget _linkRow(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 18, color: Brand.c600),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTheme.sans(13, weight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, color: Neutral.c300),
          ]),
        ),
      );
}
