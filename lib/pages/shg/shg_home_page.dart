import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

class ShgHomePage extends StatefulWidget {
  const ShgHomePage({super.key});

  @override
  State<ShgHomePage> createState() => _ShgHomePageState();
}

class _ShgHomePageState extends State<ShgHomePage> {
  final _repo = ShgRepository();
  final GlobalKey<AppAsyncBuilderState<ShgProfile?>> _key = GlobalKey();
  final _mandal = TextEditingController();
  final _bankName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _ifsc = TextEditingController();
  DateTime? _formationDate;
  bool _busy = false;

  @override
  void dispose() {
    _mandal.dispose();
    _bankName.dispose();
    _bankAccount.dispose();
    _ifsc.dispose();
    super.dispose();
  }

  /// `updateShgLeaderFields()` is scoped to exactly the columns
  /// `shgs_update_leader_or_staff`'s WITH CHECK leaves open to the leader
  /// branch (everything except grade/clf/vo, which stay admin-only) —
  /// see ShgRepository's doc comments on both write methods. Before this,
  /// mandal/bank name/account/IFSC had NO write path anywhere in the app,
  /// so this page's own Federation/Bank Details sections were permanently
  /// blank for every SHG ever created through it.
  Future<void> _editDetails(ShgProfile shg) async {
    _mandal.text = shg.mandal ?? '';
    _bankName.text = shg.bankName ?? '';
    _bankAccount.text = shg.bankAccount ?? '';
    _ifsc.text = shg.ifsc ?? '';
    // Not locked by `shgs_update_leader_or_staff`'s WITH CHECK (only
    // grade/clf/vo are) — genuinely leader-writable at the RLS layer, but
    // this dialog didn't expose it at all until a live user kept seeing
    // "Formed" still blank right after successfully saving Mandal/bank
    // details, since those were the only fields this form ever collected.
    _formationDate = shg.formationDate;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      // A plain tap just outside the dialog card (very easy to trigger by
      // accident while tapping between fields on a touchscreen) otherwise
      // dismisses this like Cancel — silently discarding everything typed,
      // with no error and no visual difference from a real save gone
      // wrong. Found by reproducing exactly this while investigating a
      // live user report of "I filled it in and saved, but it's still
      // blank" — the fields really were blank because the dialog had
      // silently closed on an off-target tap partway through data entry.
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(l10n.shgHomeEditDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _mandal, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.shgHomeMandalHint)),
                const SizedBox(height: 12),
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
                TextField(controller: _bankName, maxLength: 100, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.shgHomeBankNameHint)),
                const SizedBox(height: 12),
                TextField(controller: _bankAccount, maxLength: 30, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.shgHomeBankAccountHint)),
                const SizedBox(height: 12),
                TextField(controller: _ifsc, maxLength: 11, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: l10n.shgHomeIfscHint)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.updateShgLeaderFields(
        shg.id,
        mandal: _mandal.text.trim().isEmpty ? null : _mandal.text.trim(),
        formationDate: _formationDate,
        bankName: _bankName.text.trim().isEmpty ? null : _bankName.text.trim(),
        bankAccount: _bankAccount.text.trim().isEmpty ? null : _bankAccount.text.trim(),
        ifsc: _ifsc.text.trim().isEmpty ? null : _ifsc.text.trim(),
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.shgHomeDetailsUpdatedMessage : l10n.shgHomeDetailsUpdatedDemoMessage),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.shgHomeDetailsUpdateError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    // Only the SHG's own leader (or an admin, via AdminShgsPage) can ever
    // successfully write these columns — `shgs_update_leader_or_staff`'s
    // WITH CHECK has no branch for crp/clf at all (see migration 0082).
    // Showing this to a crp/clf viewer would let them tap Save and get a
    // bare RLS-violation error with no indication why.
    final canEditDetails = appState.user.role == Role.leader;
    final shgId = appState.profile?.shgId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.shgHomeTitle),
      body: AppAsyncBuilder<ShgProfile?>(
        key: _key,
        future: () => _repo.fetchShg(shgId),
        builder: (context, shg) {
          if (shg == null) {
            return AppEmptyState(icon: Icons.groups_rounded, message: l10n.shgHomeNotLinked);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(shg.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                      if (shg.grade != null) AppBadge(text: shg.grade!, tone: BadgeTone.neutral),
                      if (canEditDetails)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white),
                          tooltip: l10n.shgHomeEditTooltip,
                          onPressed: _busy ? null : () => _editDetails(shg),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text('${shg.village ?? ''}, ${shg.district ?? ''}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    if (shg.regNumber != null) ...[
                      const SizedBox(height: 8),
                      Text(l10n.shgHomeRegNumberLabel(shg.regNumber!), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.shgMembers), icon: Icons.groups_rounded, label: l10n.shgHomeMembersTile, tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.shgDocuments), icon: Icons.folder_rounded, label: l10n.shgHomeDocumentsTile, tone: TileTone.gold),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.shgHomeFederationSection),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Soft hyphen (baked into the localized string itself)
                    // gives the narrow label column a sensible break point
                    // instead of an arbitrary mid-word cut.
                    _row(l10n.shgHomeVillageOrgLabel, shg.vo ?? '—'),
                    const SizedBox(height: 8),
                    _row(l10n.shgHomeClfLabel, shg.clf ?? '—'),
                    const SizedBox(height: 8),
                    _row(l10n.shgHomeMandalLabel, shg.mandal ?? '—'),
                    const SizedBox(height: 8),
                    // `ShgProfile.formationDate` (`shgs.formation_date`) was
                    // parsed by `ShgRepository.fetchShg()` but never
                    // displayed anywhere — a real, populated field with no
                    // UI to show it, the same "data with no way to see it"
                    // shape as round 65's orphaned routes.
                    _row(l10n.shgHomeFormedLabel, shg.formationDate != null ? DateFormat('dd MMM yyyy').format(shg.formationDate!) : '—'),
                  ],
                ),
              ),
              if (isLeaderOrStaff) ...[
                const SizedBox(height: 20),
                SectionHeader(title: l10n.shgHomeBankDetailsSection),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(l10n.shgHomeBankLabel, shg.bankName ?? '—'),
                      const SizedBox(height: 8),
                      _row(l10n.shgHomeAccountLabel, shg.bankAccount ?? '—'),
                      const SizedBox(height: 8),
                      _row(l10n.shgHomeIfscLabel, shg.ifsc ?? '—'),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // `label` is a short fixed caption ("Bank", "IFSC", ...) so it keeps its
  // natural width; `value` is real SHG/bank data of unbounded length (a
  // long bank branch name, a full account number, ...) and previously had
  // no flex at all, so it overflowed the row instead of wrapping.
  //
  // "short" only held at 1.0x text scale, though — "Village Organisation"
  // is long enough that at 1.5-2x scaled text (a real accessibility
  // setting, not just a hypothetically long label) it alone overflows the
  // row before `value` even gets a say. `Flexible`+ellipsis on the label
  // too keeps both sides visible instead of throwing.
  Widget _row(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: AppTheme.sans(12, weight: FontWeight.w700), textAlign: TextAlign.right)),
        ],
      );
}
