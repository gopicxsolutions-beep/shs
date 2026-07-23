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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not load more SHGs. Please try again.')));
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
    super.dispose();
  }

  /// Shared by both Add and Edit dialogs — identical fields in each, just
  /// seeded from different starting values. Mirrors
  /// `admin_schemes_page.dart`'s `_criteriaFields` helper.
  List<Widget> _shgFormFields(BuildContext dialogContext, StateSetter setDialogState) => [
        TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'SHG name')),
        const SizedBox(height: 12),
        TextField(controller: _village, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Village')),
        const SizedBox(height: 12),
        TextField(controller: _district, maxLength: 100, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'District')),
        const SizedBox(height: 16),
        Text('Formation date (optional)', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _formationDate == null ? 'Not set' : DateFormat('dd MMM yyyy').format(_formationDate!),
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
              child: const Text('Pick date'),
            ),
            if (_formationDate != null)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                tooltip: 'Clear formation date',
                onPressed: () => setDialogState(() => _formationDate = null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _grade,
          decoration: const InputDecoration(hintText: 'Grade (optional)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Not graded')),
            ..._gradeOptions.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g))),
          ],
          onChanged: (v) => setDialogState(() => _grade = v),
        ),
      ];

  Future<void> _addShg() async {
    _name.clear();
    _village.clear();
    _district.clear();
    _formationDate = null;
    _grade = null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add SHG'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SHG name is required.')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.createShg(
        name: _name.text.trim(),
        village: _village.text.trim(),
        district: _district.text.trim(),
        formationDate: _formationDate,
        grade: _grade,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'SHG added' : 'Demo mode — SHG not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add this SHG. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// `ShgRepository.updateShg()` was a fully-working, RLS-backed write (the
  /// same `shgs_update_leader_or_staff` policy already permits any staff
  /// role, unrestricted, on every column — see
  /// supabase/migrations/0013_self_service_write_check_gaps.sql) with zero
  /// call sites anywhere in the app — there was no Edit-SHG UI at all.
  /// Concretely, that meant an SHG onboarded without a formation date/grade
  /// (true of every SHG created via `_addShg` before this fix existed) had
  /// no in-app way to ever have those facts filled in later, so a scheme
  /// requiring a minimum SHG age or grade could never be satisfied by it.
  Future<void> _editShg(ShgProfile s) async {
    _name.text = s.name;
    _village.text = s.village ?? '';
    _district.text = s.district ?? '';
    _formationDate = s.formationDate;
    // Defensive fallback for a stored grade outside this dropdown's 5-item
    // vocabulary (e.g. written directly via SQL, bypassing this form —
    // there's no DB CHECK constraint) — same "don't crash on an
    // unrecognized dropdown value" precedent as the fix to
    // `admin_schemes_page.dart`'s Edit-scheme dialog.
    _grade = _gradeOptions.contains(s.grade) ? s.grade : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit SHG'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _shgFormFields(context, setDialogState),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SHG name is required.')));
      }
      return;
    }
    setState(() => _busy = true);
    try {
      await _repo.updateShg(
        s.id,
        name: _name.text.trim(),
        village: _village.text.trim(),
        district: _district.text.trim(),
        formationDate: _formationDate,
        grade: _grade,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'SHG updated' : 'Demo mode — SHG not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this SHG. Please try again.')));
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
        title: 'Manage SHGs',
        right: isAdmin
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addShg : null,
                tooltip: 'Add SHG',
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
            return const AppEmptyState(icon: Icons.groups_rounded, message: 'No SHGs registered yet');
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
                        : TextButton(onPressed: _loadMore, child: const Text('Load more')),
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
                          tooltip: 'Edit ${s.name}',
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
