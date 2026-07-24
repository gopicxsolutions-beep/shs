import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/shg.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/profile.dart';
import '../../routes/paths.dart';
import '../../services/profile_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/shg_search_sheet.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _mandal = TextEditingController();
  final _district = TextEditingController();
  final _profileRepository = ProfileRepository();
  ShgSearchResult? _selectedShg;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    _mandal.dispose();
    _district.dispose();
    super.dispose();
  }

  Widget _field(String label, {String? placeholder, TextEditingController? controller, TextInputAction? textInputAction}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(border: Border.all(color: Neutral.c200), borderRadius: BorderRadius.circular(12), color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            textInputAction: textInputAction,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(border: InputBorder.none, hintText: placeholder),
            style: AppTheme.sans(14),
          ),
        ),
      ],
    );
  }

  Future<void> _pickShg() async {
    if (!SupabaseService.isConfigured) {
      setState(() => _selectedShg = const ShgSearchResult(
            id: 'demo-shg',
            name: ShgInfo.name,
            village: ShgInfo.village,
            mandal: ShgInfo.mandal,
            district: ShgInfo.district,
            grade: ShgInfo.grade,
          ));
      return;
    }
    final result = await showShgSearchSheet(context, search: _profileRepository.searchShgs);
    if (!mounted) return;
    if (result != null) setState(() => _selectedShg = result);
  }

  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    if (_selectedShg != null && SupabaseService.isConfigured) {
      appState.setPendingShg(_selectedShg!);
    }
    try {
      await appState.completeProfileSetup(
        name: _name.text.trim(),
        village: _village.text.trim().isNotEmpty ? _village.text.trim() : _selectedShg?.village ?? '',
        mandal: _mandal.text.trim().isNotEmpty ? _mandal.text.trim() : _selectedShg?.mandal,
        district: _district.text.trim().isNotEmpty ? _district.text.trim() : _selectedShg?.district,
      );
      // Not always Role Select: this page is also the "Choose a different
      // SHG" retry a rejected member reaches from ShgApprovalPendingPage,
      // where Role Select was already completed in a prior session (see
      // AppState.completeProfileSetup's `isNewProfile` guard). Navigating to
      // the dashboard and letting the router's own redirect chain resolve
      // the actual next step (Role Select for a genuinely new profile,
      // ShgApprovalPendingPage again for the retry, or the dashboard itself)
      // is correct for every case instead of hardcoding one destination.
      if (mounted) context.go(Paths.dashboard);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // An SHG is optional here, not required: completeProfileSetup() never
    // writes _selectedShg onto the profile row itself — it only submits an
    // optional join request for a leader to approve later (see
    // AppState.completeProfileSetup's doc comment). Requiring one to even
    // enable Continue was a client-side-only restriction with no backend
    // basis, and it blocked every path through onboarding — including a
    // future admin/crp/clf/leader, none of whom belong to a specific SHG at
    // signup — whenever the SHG catalog was empty (e.g. a fresh deployment
    // with no SHGs seeded yet: nobody could ever become the first admin).
    final valid = _name.text.trim().isNotEmpty;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64, height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 100),
                decoration: BoxDecoration(
                  color: Brand.c600, borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              Text(l10n.profileSetupTitle, textAlign: TextAlign.center, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              Text(l10n.profileSetupSubtitle, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
              const SizedBox(height: 28),
              _field(l10n.fieldFullName, placeholder: 'e.g. Lakshmi Devi', controller: _name, textInputAction: TextInputAction.next),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field(l10n.profileVillage, placeholder: 'Kondapur', controller: _village, textInputAction: TextInputAction.next)),
                const SizedBox(width: 12),
                Expanded(child: _field(l10n.fieldMandal, placeholder: 'Hanamkonda', controller: _mandal, textInputAction: TextInputAction.next)),
              ]),
              const SizedBox(height: 14),
              _field(l10n.fieldDistrict, placeholder: 'Warangal', controller: _district, textInputAction: TextInputAction.done),
              const SizedBox(height: 14),
              Text(l10n.yourShg, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
              const SizedBox(height: 6),
              AppCard(
                onTap: _pickShg,
                borderColor: _selectedShg != null ? Brand.c500 : null,
                child: _selectedShg != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_selectedShg!.name, style: AppTheme.sans(14, weight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text('${_selectedShg!.village}, ${_selectedShg!.district}', style: AppTheme.sans(12, color: Neutral.c500)),
                              ],
                            ),
                          ),
                          Text(l10n.changeShg, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                        ],
                      )
                    : Row(children: [
                        Icon(Icons.search, size: 16, color: Neutral.c500),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.searchSelectShg, style: AppTheme.sans(14, color: Neutral.c500), overflow: TextOverflow.ellipsis)),
                      ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: _saving ? l10n.profileSetupSaving : l10n.profileSetupContinue,
                fullWidth: true,
                size: ButtonSize.lg,
                onPressed: valid && !_saving ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
