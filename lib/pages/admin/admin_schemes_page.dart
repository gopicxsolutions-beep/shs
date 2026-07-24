import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../models/types.dart';
import '../../repositories/scheme_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class AdminSchemesPage extends StatefulWidget {
  const AdminSchemesPage({super.key});
  @override
  State<AdminSchemesPage> createState() => _AdminSchemesPageState();
}

// Grades in best→worst order, matching `EligibilityCriteria.minShgGrade`'s
// vocabulary (`lib/models/scheme.dart`) and the badge maps already used on
// `analytics_shg_list_page.dart`/`crp_dashboard.dart`.
const _gradeOptions = ['A+', 'A', 'B+', 'B', 'C'];

class _AdminSchemesPageState extends State<AdminSchemesPage> {
  final _repo = SchemeRepository();
  final GlobalKey<AppAsyncBuilderState<List<Scheme>>> _key = GlobalKey();
  final _name = TextEditingController();
  final _agency = TextEditingController();
  final _benefit = TextEditingController();
  final _minShgAgeMonths = TextEditingController();
  // Structured eligibility criteria form state (see `EligibilityCriteria` in
  // lib/models/scheme.dart) — reset before each dialog opens, read back once
  // the dialog is confirmed. Plain fields (not part of a form widget) are
  // enough here per the "a simple form is fine" scope for this feature.
  bool _requiresShgMembership = false;
  String? _minShgGrade;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _agency.dispose();
    _benefit.dispose();
    _minShgAgeMonths.dispose();
    super.dispose();
  }

  /// Shared by both Add and Edit dialogs — the criteria section is
  /// identical in each, just seeded from different starting values.
  List<Widget> _criteriaFields(StateSetter setDialogState) => [
        const Divider(height: 28),
        Text('Eligibility criteria (optional)', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 4),
        Text(
          'Checked automatically against a member\'s SHG. Leave blank for requirements this app can\'t verify automatically (age, income, BPL status, ...) — keep those in the eligibility text instead.',
          style: AppTheme.sans(11, color: Neutral.c500),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _requiresShgMembership,
          title: const Text('Requires SHG membership'),
          onChanged: (v) => setDialogState(() => _requiresShgMembership = v ?? false),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _minShgAgeMonths,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Minimum SHG age in months (optional)'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _minShgGrade,
          decoration: const InputDecoration(hintText: 'Minimum SHG grade (optional)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('No minimum')),
            ..._gradeOptions.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
          ],
          onChanged: (v) => setDialogState(() => _minShgGrade = v),
        ),
      ];

  /// Parses [_minShgAgeMonths] into the `EligibilityCriteria` to save, or
  /// returns false and shows a validation message without saving if the
  /// field holds something other than blank or a positive whole number —
  /// same "fail loud, not silent" precedent as this page's existing
  /// blank-name check below.
  bool _buildCriteria(void Function(EligibilityCriteria) onValid) {
    final raw = _minShgAgeMonths.text.trim();
    int? minAge;
    if (raw.isNotEmpty) {
      minAge = int.tryParse(raw);
      if (minAge == null || minAge <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum SHG age must be a whole number of months.')));
        return false;
      }
    }
    onValid(EligibilityCriteria(requiresShgMembership: _requiresShgMembership, minShgAgeMonths: minAge, minShgGrade: _minShgGrade));
    return true;
  }

  Future<void> _addScheme() async {
    _name.clear();
    _agency.clear();
    _benefit.clear();
    _minShgAgeMonths.clear();
    _requiresShgMembership = false;
    _minShgGrade = null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add scheme'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Scheme name')),
                const SizedBox(height: 12),
                TextField(controller: _agency, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Agency')),
                const SizedBox(height: 12),
                TextField(controller: _benefit, maxLength: 300, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'Benefit')),
                ..._criteriaFields(setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)?.actionAdd ?? 'Add')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_name.text.trim().isEmpty) {
      // Same silent-no-op gap as admin_shgs_page.dart's "Add SHG": tapping
      // "Add" on a blank name closed the dialog with zero feedback, looking
      // exactly like a dead button rather than a validation failure.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheme name is required.')));
      }
      return;
    }
    EligibilityCriteria? criteria;
    if (!_buildCriteria((c) => criteria = c) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.createScheme(name: _name.text.trim(), agency: _agency.text.trim(), benefit: _benefit.text.trim(), criteria: criteria!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Scheme added' : 'Demo mode — scheme not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add this scheme. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // `SchemeRepository.updateScheme()` was a fully-working, RLS-backed write
  // (`schemes_write_admin`) with genuinely zero call sites anywhere in the
  // app — this page could Add and Delete a scheme, but never Edit one, so a
  // typo in a scheme's name/agency/benefit was permanently uncorrectable
  // short of deleting and re-adding it (losing its id and any applications
  // already filed against it). Mirrors `_addScheme`'s own dialog shape,
  // just pre-filled and calling `updateScheme` instead of `createScheme`.
  Future<void> _editScheme(Scheme s) async {
    _name.text = s.name;
    _agency.text = s.agency ?? '';
    _benefit.text = s.benefit ?? '';
    _minShgAgeMonths.text = s.criteria.minShgAgeMonths?.toString() ?? '';
    _requiresShgMembership = s.criteria.requiresShgMembership;
    // Defensive fallback to "No minimum" for a stored `min_shg_grade` outside
    // this dropdown's 5-item vocabulary (e.g. written directly via SQL,
    // bypassing this form — there's no DB CHECK constraint on the column).
    // `DropdownButtonFormField`'s `initialValue` must exactly match one of
    // its `items`' values or Flutter trips a value-matching assertion/crash
    // when the dialog opens — without this fallback, a single out-of-
    // vocabulary grade value would make this scheme's Edit dialog
    // permanently uncorrectable through the UI (crashing every time it's
    // opened, including any retry).
    _minShgGrade = _gradeOptions.contains(s.criteria.minShgGrade) ? s.criteria.minShgGrade : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit scheme'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Scheme name')),
                const SizedBox(height: 12),
                TextField(controller: _agency, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Agency')),
                const SizedBox(height: 12),
                TextField(controller: _benefit, maxLength: 300, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'Benefit')),
                ..._criteriaFields(setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_name.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheme name is required.')));
      }
      return;
    }
    EligibilityCriteria? criteria;
    if (!_buildCriteria((c) => criteria = c) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.updateScheme(s.id, name: _name.text.trim(), fullName: s.fullName, agency: _agency.text.trim(), benefit: _benefit.text.trim(), criteria: criteria!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Scheme updated' : 'Demo mode — scheme not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this scheme. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteScheme(Scheme s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scheme?'),
        content: Text('This removes "${s.name}" from the catalog.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)?.actionDelete ?? 'Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteScheme(s.id);
      if (mounted) {
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Scheme deleted' : 'Demo mode — not saved (connect Supabase to persist)'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this scheme. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().user.role == Role.admin;

    return Scaffold(
      appBar: PageHeader(
        title: 'Manage Schemes',
        right: isAdmin
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addScheme : null,
                tooltip: 'Add scheme',
              )
            : null,
      ),
      body: AppAsyncBuilder<List<Scheme>>(
        key: _key,
        future: _repo.fetchSchemes,
        builder: (context, schemes) {
          if (schemes.isEmpty) {
            return const AppEmptyState(icon: Icons.description_rounded, message: 'No schemes in the catalog yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schemes.length,
            itemBuilder: (context, i) {
              final s = schemes[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: AppTheme.sans(13, weight: FontWeight.w700)),
                            if (s.agency != null) Text(s.agency!, style: AppTheme.sans(11, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      if (isAdmin) ...[
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: !_busy ? Brand.c600 : Neutral.c300),
                          onPressed: !_busy ? () => _editScheme(s) : null,
                          tooltip: 'Edit ${s.name}',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: !_busy ? Accent.red500 : Neutral.c300),
                          onPressed: !_busy ? () => _deleteScheme(s) : null,
                          tooltip: 'Delete ${s.name}',
                        ),
                      ],
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
