import 'dart:async';
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
    final result = await showModalBottomSheet<ShgSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ShgSearchSheet(repository: _profileRepository),
    );
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
      if (mounted) context.go(Paths.roleSelect);
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
                        Text(l10n.searchSelectShg, style: AppTheme.sans(14, color: Neutral.c500)),
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

class _ShgSearchSheet extends StatefulWidget {
  final ProfileRepository repository;
  const _ShgSearchSheet({required this.repository});
  @override
  State<_ShgSearchSheet> createState() => _ShgSearchSheetState();
}

class _ShgSearchSheetState extends State<_ShgSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<ShgSearchResult> _results = [];
  bool _loading = false;
  String? _error;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    // A later keystroke can start a second search before an earlier one's
    // response arrives; only the most recent request may write its results,
    // so a slow stale response can't clobber what the user is now seeing.
    final generation = ++_searchGeneration;
    setState(() => _loading = true);
    try {
      final results = await widget.repository.searchShgs(value);
      if (mounted && generation == _searchGeneration) setState(() => _results = results);
    } catch (_) {
      if (mounted && generation == _searchGeneration) setState(() => _error = 'Could not load SHGs. Please try again.');
    } finally {
      if (mounted && generation == _searchGeneration) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.findYourShg, style: AppTheme.display(16)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Neutral.c200), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(Icons.search, size: 16, color: Neutral.c400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onChanged: _onChanged,
                      decoration: InputDecoration(border: InputBorder.none, hintText: l10n.searchShgHint),
                      style: AppTheme.sans(14),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(child: Text(l10n.noShgsFound, style: AppTheme.sans(13, color: Neutral.c400)))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final shg = _results[i];
                              return AppCard(
                                onTap: () => Navigator.of(context).pop(shg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shg.name, style: AppTheme.sans(14, weight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('${shg.village}, ${shg.district}', style: AppTheme.sans(12, color: Neutral.c500)),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
