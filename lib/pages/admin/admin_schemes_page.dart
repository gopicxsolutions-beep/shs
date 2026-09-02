import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _fullName = TextEditingController();
  final _agency = TextEditingController();
  final _benefit = TextEditingController();
  // Gap-hunt iteration 42: free-text eligibility requirements (the ones
  // `EligibilityCriteria` can't machine-evaluate — see its doc comment,
  // e.g. BPL status, prior subsidy history) had no form field at all —
  // one requirement per line, mirroring `SchemeDetailPage`'s bulleted
  // rendering of this same list.
  final _eligibility = TextEditingController();
  final _minShgAgeMonths = TextEditingController();
  // Structured eligibility criteria form state (see `EligibilityCriteria` in
  // lib/models/scheme.dart) — reset before each dialog opens, read back once
  // the dialog is confirmed. Plain fields (not part of a form widget) are
  // enough here per the "a simple form is fine" scope for this feature.
  bool _requiresShgMembership = false;
  String? _minShgGrade;
  // Gap-hunt iteration 42: had no form field at all — a scheme's real-world
  // application deadline (shown on `SchemeDetailPage`) could only ever be
  // set by writing to the table directly, and any admin who then corrected
  // a typo through this page's Edit dialog silently wiped it (see
  // `SchemeRepository.updateScheme`'s doc comment for the wipe mechanism).
  DateTime? _deadline;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _fullName.dispose();
    _agency.dispose();
    _benefit.dispose();
    _eligibility.dispose();
    _minShgAgeMonths.dispose();
    super.dispose();
  }

  /// `_eligibility`'s free-text textarea, one requirement per line, into
  /// the `List<String>` `SchemeRepository` stores — mirrors
  /// `SchemeDetailPage`'s bulleted rendering of the same list. Blank lines
  /// (leading/trailing, or a field left empty) are dropped rather than
  /// stored as empty bullets.
  List<String> get _parsedEligibility => _eligibility.text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

  /// Shared by both Add and Edit dialogs — the basic catalog fields
  /// (everything except the structured criteria section below) are
  /// identical in each, just seeded from different starting values.
  List<Widget> _basicFields(BuildContext dialogContext, StateSetter setDialogState, AppLocalizations l10n) => [
        TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminSchemesNameHint)),
        const SizedBox(height: 12),
        TextField(controller: _fullName, maxLength: 150, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminSchemesFullNameHint)),
        const SizedBox(height: 12),
        TextField(controller: _agency, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminSchemesAgencyHint)),
        const SizedBox(height: 12),
        TextField(controller: _benefit, maxLength: 300, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminSchemesBenefitHint)),
        const SizedBox(height: 12),
        TextField(
          controller: _eligibility,
          maxLines: 3,
          minLines: 3,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: l10n.adminSchemesEligibilityHint),
        ),
        const SizedBox(height: 16),
        Text(l10n.adminSchemesDeadlineLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _deadline == null ? l10n.adminSchemesDeadlineNotSet : DateFormat('dd MMM yyyy').format(_deadline!),
                style: AppTheme.sans(13),
              ),
            ),
            Builder(builder: (dialogContext) {
              return TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: _deadline ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) setDialogState(() => _deadline = picked);
                },
                child: Text(l10n.adminSchemesPickDateButton),
              );
            }),
            if (_deadline != null)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                tooltip: l10n.adminSchemesClearDeadlineTooltip,
                onPressed: () => setDialogState(() => _deadline = null),
              ),
          ],
        ),
      ];

  /// Shared by both Add and Edit dialogs — the criteria section is
  /// identical in each, just seeded from different starting values.
  List<Widget> _criteriaFields(StateSetter setDialogState, AppLocalizations l10n) => [
        const Divider(height: 28),
        Text(l10n.adminSchemesCriteriaSectionTitle, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 4),
        Text(
          l10n.adminSchemesCriteriaSectionSubtext,
          style: AppTheme.sans(11, color: Neutral.c500),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _requiresShgMembership,
          title: Text(l10n.adminSchemesRequiresShgMembershipLabel),
          onChanged: (v) => setDialogState(() => _requiresShgMembership = v ?? false),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _minShgAgeMonths,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: l10n.adminSchemesMinAgeHint),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _minShgGrade,
          decoration: InputDecoration(hintText: l10n.adminSchemesMinGradeHint),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(l10n.adminSchemesNoMinimum)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminSchemesInvalidMinAgeError)));
        return false;
      }
    }
    onValid(EligibilityCriteria(requiresShgMembership: _requiresShgMembership, minShgAgeMonths: minAge, minShgGrade: _minShgGrade));
    return true;
  }

  Future<void> _addScheme() async {
    final l10n = AppLocalizations.of(context)!;
    _name.clear();
    _fullName.clear();
    _agency.clear();
    _benefit.clear();
    _eligibility.clear();
    _minShgAgeMonths.clear();
    _requiresShgMembership = false;
    _minShgGrade = null;
    _deadline = null;
    final confirmed = await showDialog<bool>(
      context: context,
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards every
      // field typed so far, indistinguishable from a real save failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminSchemesAddDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._basicFields(context, setDialogState, l10n),
                ..._criteriaFields(setDialogState, l10n),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionAdd)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSchemesNameRequiredError)));
      }
      return;
    }
    EligibilityCriteria? criteria;
    if (!_buildCriteria((c) => criteria = c) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.createScheme(
        name: _name.text.trim(),
        fullName: _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
        agency: _agency.text.trim(),
        benefit: _benefit.text.trim(),
        eligibility: _parsedEligibility,
        criteria: criteria!,
        deadline: _deadline,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.adminSchemesAddedMessage : l10n.adminSchemesDemoModeMessage),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSchemesAddErrorMessage)));
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
    final l10n = AppLocalizations.of(context)!;
    _name.text = s.name;
    _fullName.text = s.fullName ?? '';
    _agency.text = s.agency ?? '';
    _benefit.text = s.benefit ?? '';
    _eligibility.text = s.eligibility.join('\n');
    _minShgAgeMonths.text = s.criteria.minShgAgeMonths?.toString() ?? '';
    _requiresShgMembership = s.criteria.requiresShgMembership;
    _deadline = s.deadline;
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
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards every
      // field typed so far, indistinguishable from a real save failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminSchemesEditDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._basicFields(context, setDialogState, l10n),
                ..._criteriaFields(setDialogState, l10n),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_name.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSchemesNameRequiredError)));
      }
      return;
    }
    EligibilityCriteria? criteria;
    if (!_buildCriteria((c) => criteria = c) || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.updateScheme(
        s.id,
        name: _name.text.trim(),
        fullName: _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
        agency: _agency.text.trim(),
        benefit: _benefit.text.trim(),
        eligibility: _parsedEligibility,
        criteria: criteria!,
        deadline: _deadline,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.adminSchemesUpdatedMessage : l10n.adminSchemesDemoModeMessage),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSchemesUpdateErrorMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteScheme(Scheme s) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminSchemesDeleteDialogTitle),
        content: Text(l10n.adminSchemesDeleteDialogContent(s.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionDelete)),
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
          content: Text(SupabaseService.isConfigured ? l10n.adminSchemesDeletedMessage : l10n.adminSchemesDeleteDemoModeMessage),
        ));
      }
    } on PostgrestException catch (e) {
      // '23503' = foreign-key violation — a scheme with real applications
      // on file (0074's `on delete restrict`) always fails here, same
      // class of error already handled for training courses.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '23503' ? l10n.adminSchemesDeleteHasApplicationsError : l10n.adminSchemesDeleteErrorMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminSchemesDeleteErrorMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = context.watch<AppState>().user.role == Role.admin;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.adminSchemesTitle,
        right: isAdmin
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addScheme : null,
                tooltip: l10n.adminSchemesAddSchemeTooltip,
              )
            : null,
      ),
      body: AppAsyncBuilder<List<Scheme>>(
        key: _key,
        future: _repo.fetchSchemes,
        builder: (context, schemes) {
          if (schemes.isEmpty) {
            return AppEmptyState(icon: Icons.description_rounded, message: l10n.adminSchemesEmptyState);
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
                          tooltip: l10n.adminSchemesEditTooltip(s.name),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: !_busy ? Accent.red500 : Neutral.c300),
                          onPressed: !_busy ? () => _deleteScheme(s) : null,
                          tooltip: l10n.adminSchemesDeleteTooltip(s.name),
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
