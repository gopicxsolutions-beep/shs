import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
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
  bool _signingOut = false;
  bool _editing = false;

  Future<void> _editProfile(Profile? profile) async {
    if (profile == null || _editing) return;
    // The dialog itself closes synchronously on tap (before the network
    // call below even starts), so without this guard a re-tap of the edit
    // icon while `updateProfile()`/`refreshProfile()` was still in flight
    // could open a second dialog pre-filled from the still-stale
    // `AppState.profile` and fire a second, overlapping write — matching
    // this page's own existing `_signingOut` guard pattern.
    setState(() => _editing = true);
    try {
      await _doEditProfile(profile);
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<void> _doEditProfile(Profile profile) async {
    final l10n = AppLocalizations.of(context)!;
    final name = TextEditingController(text: profile.name);
    final village = TextEditingController(text: profile.village ?? '');
    // Mandal/district were collected at onboarding but, before this fix,
    // had no path to ever be filled in or corrected afterward — a pre-fix
    // account had them permanently null with no recovery, and even a
    // post-fix account could never correct a typo. Reusing the same edit
    // dialog closes both gaps at once.
    final mandal = TextEditingController(text: profile.mandal ?? '');
    final district = TextEditingController(text: profile.district ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileEditProfile),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.profileName)),
              const SizedBox(height: 12),
              TextField(controller: village, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.profileVillage)),
              const SizedBox(height: 12),
              TextField(controller: mandal, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.fieldMandal)),
              const SizedBox(height: 12),
              TextField(controller: district, maxLength: 100, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: l10n.fieldDistrict)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSave)),
        ],
      ),
    );
    if (saved != true) return;
    if (name.text.trim().isEmpty) {
      // Without this, tapping "Save" with a blank name silently closed the
      // dialog and updated nothing — indistinguishable from a broken button,
      // same silent-no-op gap already fixed for "Add SHG"/"Add scheme" in
      // admin_shgs_page.dart / admin_schemes_page.dart.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileNameRequired)));
      }
      return;
    }
    try {
      await _profileRepo.updateProfile(
        name: name.text.trim(),
        village: village.text.trim(),
        mandal: mandal.text.trim().isEmpty ? null : mandal.text.trim(),
        district: district.text.trim().isEmpty ? null : district.text.trim(),
      );
      if (!mounted) return;
      await context.read<AppState>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(SupabaseService.isConfigured ? l10n.profileUpdated : l10n.profileUpdateDemoMode),
      ));
    } catch (_) {
      if (!mounted) return;
      // A silent-no-op RLS rejection (a leader/admin deactivated this
      // account mid-session, while AppState.profile is still the stale
      // pre-deactivation copy) surfaces here as the same generic exception
      // as any other write failure. Re-checking the account's real current
      // status distinguishes "you were deactivated" from an actual
      // transient error, instead of always showing the opaque generic
      // message for both.
      await context.read<AppState>().refreshProfile().catchError((_) {});
      if (!mounted) return;
      final deactivated = SupabaseService.isConfigured && context.read<AppState>().profile?.isActive == false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deactivated ? l10n.accountDeactivatedMessage : l10n.profileUpdateError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.user;
    final profile = appState.profile;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.profileTitle,
        right: IconButton(
          icon: const Icon(Icons.edit_rounded, color: Brand.c600),
          tooltip: l10n.profileEditProfile,
          // Disabled (not just a silent no-op) while the profile hasn't
          // loaded yet or a previous edit is still saving — matches this
          // file's own established standard of not leaving a tappable
          // control that does nothing with no feedback.
          onPressed: profile == null || _editing ? null : () => _editProfile(profile),
        ),
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
                    _row(Icons.phone_rounded, l10n.profileMobile, user.mobile),
                    const Divider(height: 20),
                    _row(Icons.location_on_rounded, l10n.profileVillage, user.village),
                    // Round 193 fixed mandal/district (collected at
                    // onboarding since v1) silently vanishing instead of
                    // being persisted — but a fix that only writes the
                    // data, with no reader anywhere ever displaying it
                    // again, is only half the bug. `Profile.mandal`/
                    // `.district` are null for any account created before
                    // that fix, so these rows are conditional rather than
                    // always shown.
                    if ((profile?.mandal ?? '').isNotEmpty) ...[
                      const Divider(height: 20),
                      _row(Icons.map_rounded, l10n.fieldMandal, profile!.mandal!),
                    ],
                    if ((profile?.district ?? '').isNotEmpty) ...[
                      const Divider(height: 20),
                      _row(Icons.map_rounded, l10n.fieldDistrict, profile!.district!),
                    ],
                    const Divider(height: 20),
                    _row(Icons.groups_rounded, l10n.profileSHG, shg?.name ?? _shgFallbackText(user, l10n)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padded: false,
                child: Column(
                  children: [
                    _linkRow(context, icon: Icons.settings_rounded, label: l10n.settingsTitle, onTap: () => context.go(Paths.profileSettings)),
                    const Divider(height: 1, color: Neutral.c100),
                    _linkRow(context, icon: Icons.language_rounded, label: l10n.languageTitle, onTap: () => context.go(Paths.profileLanguage)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _signingOut ? l10n.profileSigningOut : l10n.actionSignOut,
                variant: ButtonVariant.outline,
                fullWidth: true,
                // Was tappable indefinitely with zero feedback: AppState.
                // signOut() awaits NotificationService.cancelAllScheduled(),
                // a real platform-channel call with a documented hang risk
                // on some Android OEM builds — a 3s timeout now bounds that
                // (see signOut()'s own comment), but nothing here disabled
                // the button or showed any progress while it ran, so a slow
                // device left this inertly tappable and let a repeat tap
                // start a second concurrent signOut().
                onPressed: _signingOut
                    ? null
                    : () async {
                        setState(() => _signingOut = true);
                        try {
                          await context.read<AppState>().signOut();
                        } catch (_) {
                          // fall through — still navigate to splash below
                        }
                        if (context.mounted) context.go(Paths.splash);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  // `ShgRepository.fetchShg` returns null both while a member/leader is
  // still awaiting approval AND, by design, for any crp/clf/admin (staff
  // legitimately has no SHG of its own — see that method's own doc
  // comment). The old unconditional "Not yet approved" fallback told every
  // staff account viewing her own Profile tab that her onboarding was
  // incomplete, which was never true.
  String _shgFallbackText(AppUser user, AppLocalizations l10n) {
    if (!SupabaseService.isConfigured) return user.shgName;
    return (user.role == Role.member || user.role == Role.leader) ? l10n.profileShgNotYetApproved : l10n.profileShgNotApplicable;
  }

  Widget _row(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: Neutral.c400),
          const SizedBox(width: 10),
          Flexible(child: Text(label, style: AppTheme.sans(12, color: Neutral.c500))),
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
