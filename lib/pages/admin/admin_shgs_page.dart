import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/paged_result.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Lets an admin create new SHGs. Without this page, `shgs_insert_staff`
/// (the RLS policy already permitting any staff role to insert one — see
/// supabase/migrations/0002_rls_policies.sql) had no client anywhere that
/// called it. On a fresh deployment with zero SHGs seeded, that's not a
/// cosmetic gap: profile setup requires picking an existing SHG to
/// continue, so nobody — not even a future admin, who has no SHG to begin
/// with — could ever finish onboarding. See profile_setup_page.dart's fix
/// making that selection optional; this page is the other half, giving an
/// admin (once one exists) a real way to grow the catalog afterward instead
/// of needing direct database access every time.
///
/// Also the only place in the app that can ever set `formation_date`/`grade`
/// on an SHG (via the Add/Edit dialogs below) — the structured
/// scheme-eligibility rules engine's `minShgAgeMonths`/`minShgGrade`
/// criteria (`EligibilityCriteria` in lib/models/scheme.dart) key off
/// exactly those two columns, so without a write path here no SHG onboarded
/// through this app could ever satisfy such a scheme.
class AdminShgsPage extends StatefulWidget {
  const AdminShgsPage({super.key});
  @override
  State<AdminShgsPage> createState() => _AdminShgsPageState();
}

// Grades in best→worst order — same vocabulary/ordering as
// `EligibilityCriteria.minShgGrade` (lib/models/scheme.dart's `_gradeOrder`)
// and `admin_schemes_page.dart`'s own `_gradeOptions`.
const _gradeOptions = ['A+', 'A', 'B+', 'B', 'C'];

class _AdminShgsPageState extends State<AdminShgsPage> {
  final _repo = ShgRepository();
  final GlobalKey<AppAsyncBuilderState<PagedResult<ShgProfile>>> _key = GlobalKey();
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _district = TextEditingController();
  final _mandal = TextEditingController();
  final _vo = TextEditingController();
  final _clf = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  // Formation date / grade form state (see `EligibilityCriteria` in
  // lib/models/scheme.dart) — plain fields rather than a form widget, reset
  // before each dialog opens and read back once confirmed, same pattern as
  // `admin_schemes_page.dart`'s own criteria fields.
  DateTime? _formationDate;
  String? _grade;
  bool _busy = false;

  // Same appendable-local-copy shape as AdminUsersPage — see that page's
  // doc comment on the equivalent fields for why the builder below renders
  // these instead of the AppAsyncBuilder's own snapshot data.
  List<ShgProfile> _shgs = [];
  bool _hasMore = false;
  bool _loadingMore = false;

  Future<PagedResult<ShgProfile>> _loadFirstPage() async {
    final page = await _repo.fetchAllShgs();
    _shgs = page.items;
    _hasMore = page.hasMore;
    return page;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _shgs.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchAllShgs(afterName: _shgs.last.name);
      setState(() {
        _shgs = [..._shgs, ...page.items];
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminShgsLoadMoreError)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    _district.dispose();
    _mandal.dispose();
    _vo.dispose();
    _clf.dispose();
    _bankName.dispose();
    _bankAccount.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  /// Shared by both Add and Edit dialogs — identical fields in each, just
  /// seeded from different starting values. Mirrors
  /// `admin_schemes_page.dart`'s `_criteriaFields` helper.
  List<Widget> _shgFormFields(BuildContext dialogContext, StateSetter setDialogState) {
    final l10n = AppLocalizations.of(dialogContext)!;
    return [
      TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminShgsNameHint)),
      const SizedBox(height: 12),
      TextField(controller: _village, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminShgsVillageHint)),
      const SizedBox(height: 12),
      TextField(controller: _district, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminShgsDistrictHint)),
      const SizedBox(height: 12),
      TextField(controller: _mandal, maxLength: 100, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: l10n.adminShgsMandalHint)),
      const SizedBox(height: 16),
      Text(l10n.adminShgsFormationDateLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: Text(
              _formationDate == null ? l10n.adminShgsFormationDateNotSet : DateFormat('dd MMM yyyy').format(_formationDate!),
              style: AppTheme.sans(13),
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: _formationDate ?? DateTime.now(),
                firstDate: DateTime(1990),
                lastDate: DateTime.now(),
              );
              if (picked != null) setDialogState(() => _formationDate = picked);
            },
            child: Text(l10n.adminShgsPickDateButton),
          ),
          if (_formationDate != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              tooltip: l10n.adminShgsClearFormationDateTooltip,
              onPressed: () => setDialogState(() => _formationDate = null),
            ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String?>(
        initialValue: _grade,
        decoration: InputDecoration(hintText: l10n.adminShgsGradeHint),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(l10n.adminShgsNotGradedOption)),
          ..._gradeOptions.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
        ],
        onChanged: (v) => setDialogState(() => _grade = v),
      ),
      const SizedBox(height: 16),
      Text(l10n.adminShgsFederationSectionLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
      const SizedBox(height: 8),
      TextField(controller: _vo, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminShgsVoHint)),
      const SizedBox(height: 12),
      TextField(controller: _clf, maxLength: 100, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: l10n.adminShgsClfHint)),
      const SizedBox(height: 16),
      Text(l10n.adminShgsBankSectionLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
      const SizedBox(height: 8),
      TextField(controller: _bankName, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminShgsBankNameHint)),
      const SizedBox(height: 12),
      TextField(controller: _bankAccount, maxLength: 30, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminShgsBankAccountHint)),
      const SizedBox(height: 12),
      TextField(controller: _ifsc, maxLength: 11, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: l10n.adminShgsIfscHint)),
    ];
  }

  Future<void> _addShg() async {
    _name.clear();
    _village.clear();
    _district.clear();
    _mandal.clear();
    _vo.clear();
    _clf.clear();
    _bankName.clear();
    _bankAccount.clear();
    _ifsc.clear();
    _formationDate = null;
    _grade = null;
    final confirmed = await showDialog<bool>(
      context: context,
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards every
      // field typed so far, indistinguishable from a real save failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.adminShgsAddTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _shgFormFields(context, setDialogState),
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
      // Without this, tapping "Add" on a blank name silently closed the
      // dialog and did nothing — indistinguishable from a broken button,
      // since nothing here told the admin why no SHG was created.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminShgsNameRequiredError)));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.createShg(
        name: _name.text.trim(),
        village: _village.text.trim(),
        district: _district.text.trim(),
        mandal: _mandal.text.trim().isEmpty ? null : _mandal.text.trim(),
        formationDate: _formationDate,
        grade: _grade,
        vo: _vo.text.trim().isEmpty ? null : _vo.text.trim(),
        clf: _clf.text.trim().isEmpty ? null : _clf.text.trim(),
        bankName: _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        bankAccount: _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
        ifsc: _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim(),
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.adminShgsAddedMessage : l10n.adminShgsAddedDemoModeMessage),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminShgsAddError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// `ShgRepository.updateShg()` was a fully-working, RLS-backed write with
  /// zero call sites anywhere in the app — there was no Edit-SHG UI at all.
  /// `shgs_update_leader_or_staff` was admin-only, unrestricted, on every
  /// column at the time this comment was written — see
  /// supabase/migrations/0082_audit_trail_and_loan_attribution.sql (0013
  /// predates that tightening and is no longer the current live shape; citing it
  /// would mislead a future reader into thinking a CRP/CLF write capability
  /// still exists here to re-test — it doesn't, admin-only is correctly
  /// enforced both here and at the RLS layer).
  /// Concretely, that meant an SHG onboarded without a formation date/grade
  /// (true of every SHG created via `_addShg` before this fix existed) had
  /// no in-app way to ever have those facts filled in later, so a scheme
  /// requiring a minimum SHG age or grade could never be satisfied by it.
  Future<void> _editShg(ShgProfile s) async {
    _name.text = s.name;
    _village.text = s.village ?? '';
    _district.text = s.district ?? '';
    _mandal.text = s.mandal ?? '';
    _vo.text = s.vo ?? '';
    _clf.text = s.clf ?? '';
    _bankName.text = s.bankName ?? '';
    // `fetchAllShgs()` selects the base `shgs` table directly, which no
    // longer even has bank_account/ifsc columns (migration 0056 moved them
    // to `shg_bank_details`) — so `s` here never carries them regardless of
    // role. `shg_own_masked` unmasks both for an `is_staff()` caller (every
    // admin), so a second fetch through the same masked view this page's
    // Edit dialog already trusts for everything else gets the admin the
    // actual current values to edit, instead of either fabricating a blank
    // prefill (looks like "no data" when there may be real data) or
    // silently clobbering an existing value.
    final withBankDetails = await _repo.fetchShg(s.id);
    if (!mounted) return;
    _bankAccount.text = withBankDetails?.bankAccount ?? '';
    _ifsc.text = withBankDetails?.ifsc ?? '';
    _formationDate = s.formationDate;
    // Defensive fallback for a stored grade outside this dropdown's 5-item
    // vocabulary (e.g. written directly via SQL, bypassing this form —
    // there's no DB CHECK constraint) — same "don't crash on an
    // unrecognized dropdown value" precedent as the fix to
    // `admin_schemes_page.dart`'s Edit-scheme dialog.
    _grade = _gradeOptions.contains(s.grade) ? s.grade : null;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.adminShgsEditTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _shgFormFields(context, setDialogState),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(AppLocalizations.of(context)?.actionSave ?? 'Save')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_name.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminShgsNameRequiredError)));
      }
      return;
    }
    // Grade gates loan/scheme eligibility (0013_self_service_write_check_
    // gaps.sql's own reasoning) — unlike name/village/district/formation
    // date, a misclick here has real downstream consequences, so a grade
    // CHANGE specifically gets its own explicit old→new confirmation, the
    // same two-step caution `admin_users_page.dart`'s role-change flow
    // already uses. Declining aborts the whole edit rather than silently
    // dropping just the grade change, avoiding a confusing partial save.
    if (_grade != s.grade && mounted) {
      final l10n = AppLocalizations.of(context)!;
      String gradeLabel(String? g) => g ?? l10n.adminShgsNotGradedOption;
      final gradeConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(l10n.adminShgsGradeChangeConfirmTitle),
          content: Text(l10n.adminShgsGradeChangeConfirmMessage(s.name, gradeLabel(s.grade), gradeLabel(_grade))),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      );
      if (gradeConfirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await _repo.updateShg(
        s.id,
        name: _name.text.trim(),
        village: _village.text.trim(),
        district: _district.text.trim(),
        mandal: _mandal.text.trim().isEmpty ? null : _mandal.text.trim(),
        formationDate: _formationDate,
        grade: _grade,
        vo: _vo.text.trim().isEmpty ? null : _vo.text.trim(),
        clf: _clf.text.trim().isEmpty ? null : _clf.text.trim(),
        bankName: _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        bankAccount: _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
        ifsc: _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim(),
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.adminShgsUpdatedMessage : l10n.adminShgsAddedDemoModeMessage),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        // Was a hardcoded literal that made the already-translated
        // `adminShgsUpdateError` key (present in all 3 .arb files) dead,
        // unreachable code — a Hindi/Telugu admin always saw this in
        // English regardless of language setting.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminShgsUpdateError)));
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
        title: l10n.adminShgsManageTitle,
        right: isAdmin
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addShg : null,
                tooltip: l10n.adminShgsAddTooltip,
              )
            : null,
      ),
      body: AppAsyncBuilder<PagedResult<ShgProfile>>(
        key: _key,
        future: _loadFirstPage,
        // Renders `_shgs`/`_hasMore` (this State's own appendable copy),
        // not the `data` snapshot directly — see AdminUsersPage's identical
        // pattern for why.
        builder: (context, data) {
          if (_shgs.isEmpty) {
            return AppEmptyState(icon: Icons.groups_rounded, message: l10n.adminShgsEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _shgs.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _shgs.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _loadingMore
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : TextButton(onPressed: _loadMore, child: Text(AppLocalizations.of(context)!.actionLoadMore)),
                  ),
                );
              }
              final s = _shgs[i];
              final location = [s.village, s.district].where((p) => p != null && p.isNotEmpty).join(', ');
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
                            if (location.isNotEmpty) Text(location, style: AppTheme.sans(11, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      if (s.grade != null) Text(s.grade!, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                      if (isAdmin)
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: !_busy ? Brand.c600 : Neutral.c300),
                          onPressed: !_busy ? () => _editShg(s) : null,
                          tooltip: l10n.adminShgsEditTooltip(s.name),
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
