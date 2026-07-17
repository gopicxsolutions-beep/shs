import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/shg.dart';
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

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    _mandal.dispose();
    _district.dispose();
    super.dispose();
  }

  Widget _field(String label, {String? placeholder, TextEditingController? controller}) {
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
    if (result != null) setState(() => _selectedShg = result);
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty && _selectedShg != null;
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
              Text('Create your profile', textAlign: TextAlign.center, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              Text('Tell us a bit about yourself to get started', textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
              const SizedBox(height: 28),
              _field('Full name', placeholder: 'e.g. Lakshmi Devi', controller: _name),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field('Village', placeholder: 'Kondapur', controller: _village)),
                const SizedBox(width: 12),
                Expanded(child: _field('Mandal', placeholder: 'Hanamkonda', controller: _mandal)),
              ]),
              const SizedBox(height: 14),
              _field('District', placeholder: 'Warangal', controller: _district),
              const SizedBox(height: 14),
              Text('Your SHG', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
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
                          Text('Change', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                        ],
                      )
                    : Row(children: [
                        Icon(Icons.search, size: 16, color: Neutral.c500),
                        const SizedBox(width: 8),
                        Text('Search & select your SHG', style: AppTheme.sans(14, color: Neutral.c500)),
                      ]),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: _saving ? 'Saving…' : 'Continue',
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
    setState(() => _loading = true);
    try {
      final results = await widget.repository.searchShgs(value);
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load SHGs. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find your SHG', style: AppTheme.display(16)),
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
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search by SHG name'),
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
                        ? Center(child: Text('No SHGs found', style: AppTheme.sans(13, color: Neutral.c400)))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
