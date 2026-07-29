import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../repositories/savings_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/list_row.dart';

/// Leader/staff ledger. When Supabase is configured, this is backed by a
/// realtime stream (`savings_entries` changes push straight to every open
/// ledger — e.g. a second leader's verification shows up without a manual
/// refresh). In demo mode it falls back to a one-shot mock fetch, since a
/// realtime channel has nothing to subscribe to without a live project.
class SavingsLedgerPage extends StatefulWidget {
  // Injectable so the platform-wide staff queue (live-mode-only) can be
  // widget-tested against canned cross-SHG data instead of a real network
  // call — mirrors LoanApprovalPage's round-168 `repository` seam.
  final SavingsRepository? repository;
  const SavingsLedgerPage({super.key, this.repository});

  @override
  State<SavingsLedgerPage> createState() => _SavingsLedgerPageState();
}

class _SavingsLedgerPageState extends State<SavingsLedgerPage> {
  // Supabase Realtime's `.stream()` API (used for the live branch below)
  // cannot do PostgREST-style embedded selects (`select('*, profiles(name)')`)
  // — it only ever pushes `savings_entries`' own raw columns, which has no
  // name column of its own. `SavingsEntry.fromMap` silently falls back to
  // the literal string 'Member' when no embedded `profiles` map is present,
  // so every single stream-sourced row — for every member, permanently —
  // rendered as generic "Member" instead of a real name, making it
  // impossible for a leader to tell whose pending deposit she's looking at
  // before verifying it. Live-caught: this only became visible by actually
  // running the realtime ledger against a real SHG with a real member, not
  // from reading the code in isolation. Fixed by fetching the SHG's member
  // roster once (a plain, non-streamed, embedded-join-capable fetch) and
  // resolving each row's display name from it, overriding the stream's own
  // (always-wrong-for-live-data) `memberName` field. The one-shot demo/
  // non-realtime branch already gets the correct name directly from its own
  // `select('*, profiles(name))` query — this map is a pure addition there,
  // never a regression, since `_resolveName` only overrides when the map
  // actually has an entry for that member id.
  Map<String, String> _memberNames = const {};

  @override
  void initState() {
    super.initState();
    final shgId = context.read<AppState>().profile?.shgId;
    if (SupabaseService.isConfigured && shgId != null) {
      // `.catchError` swallows a failed roster fetch on purpose — names just
      // fall back to the stream's own 'Member' placeholder (today's pre-fix
      // behavior) rather than surfacing a second error state on top of
      // whatever the ledger's own StreamBuilder/AppAsyncBuilder already
      // shows for a real failure. Without this, a rejected Future here is an
      // *unhandled* zone error, not a silently-ignored one — harmless in a
      // real app (Flutter's root zone just logs it) but exactly the kind of
      // thing `flutter test` escalates into a hard test failure, caught
      // while writing this page's first-ever widget test.
      ShgRepository().fetchMembers(shgId).then((members) {
        if (mounted) setState(() => _memberNames = {for (final m in members) m.id: m.name});
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only `profile?.shgId` is used below (to build the repo query / decide
    // `live`) — `.watch<AppState>()` would rebuild this page, and re-create
    // the StreamBuilder's `stream:` (tearing down and re-opening the
    // Supabase realtime channel), on every unrelated AppState change, e.g.
    // the GoTrue auto-refresh timer's periodic token refresh, which calls
    // `AppState.notifyListeners()` on every tick regardless of whether the
    // profile actually changed (see `_authSub` in app_state.dart). A leader
    // who leaves this ledger open for the better part of an hour would
    // otherwise get their live subscription silently torn down and rebuilt
    // for no reason. `.select` only rebuilds when shgId itself changes.
    final shgId = context.select<AppState, String?>((s) => s.profile?.shgId);
    // Same selective-rebuild reasoning as `shgId` above — only used to gate
    // the Verify/Reject controls on the viewer's own pending entries
    // (`savings_update_leader_or_staff`'s self-exclusion already blocks
    // this server-side; the button used to still render for a leader/staff
    // account's own row, tap it, and hit a silent 0-row no-op with only the
    // generic error message, indistinguishable from a real failure).
    final viewerId = context.select<AppState, String?>((s) => s.profile?.id);
    final repo = widget.repository ?? SavingsRepository();
    final live = SupabaseService.isConfigured && shgId != null;
    final l10n = AppLocalizations.of(context)!;

    // This route is already router-restricted to leader/staff (see
    // `_roleRestrictedPrefixes` in router.dart) — crp/clf/admin have no
    // `profile.shgId` of their own (platform-wide roles, never SHG-scoped).
    // `savings_select_shg_or_staff`/`savings_update_leader_or_staff` (RLS)
    // have always granted `is_staff()` unrestricted platform-wide read/
    // verify — round 168 (Loans) established the fix template this mirrors:
    // a real cross-SHG queue instead of the honest-but-dead-end message
    // round 147 shipped. No realtime stream for the platform-wide branch
    // (Supabase Realtime's `.stream()` API needs a specific row filter, and
    // a one-shot fetch — the same choice `loan_approval_page.dart` made —
    // is enough for an oversight queue). `isConfigured` still excludes demo
    // mode, whose simulated identity leaves `shgId` null for every
    // previewed role too.
    final isPlatformWide = SupabaseService.isConfigured && shgId == null;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.savingsLedgerTitle,
        subtitle: live ? l10n.savingsLedgerLiveLabel : null,
        right: IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.savingsEntry), tooltip: l10n.savingsLedgerAddTooltip),
      ),
      body: live
          ? StreamBuilder<List<SavingsEntry>>(
              stream: repo.watchForShg(shgId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  final l10n = AppLocalizations.of(context);
                  return Center(child: Semantics(label: l10n?.commonLoading ?? 'Loading…', liveRegion: true, child: const CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  final l10n = AppLocalizations.of(context);
                  return Center(child: Text(l10n?.asyncErrorGeneric ?? 'Something went wrong. Please try again.', style: AppTheme.sans(13, color: Neutral.c500)));
                }
                return _LedgerList(entries: snapshot.data ?? const [], repo: repo, memberNames: _memberNames, isPlatformWide: false, viewerId: viewerId);
              },
            )
          : AppAsyncBuilder<List<SavingsEntry>>(
              future: () => isPlatformWide ? repo.fetchAllForStaff() : repo.fetchForShg(shgId),
              builder: (context, entries) => _LedgerList(entries: entries, repo: repo, memberNames: _memberNames, isPlatformWide: isPlatformWide, viewerId: viewerId),
            ),
    );
  }
}

class _LedgerList extends StatefulWidget {
  final List<SavingsEntry> entries;
  final SavingsRepository repo;
  final Map<String, String> memberNames;
  final bool isPlatformWide;
  final String? viewerId;
  const _LedgerList({required this.entries, required this.repo, required this.memberNames, required this.isPlatformWide, required this.viewerId});

  @override
  State<_LedgerList> createState() => _LedgerListState();
}

class _LedgerListState extends State<_LedgerList> {
  final _verifying = <String>{};
  final _rejecting = <String>{};

  /// Rejects (deletes) an obviously-wrong pending entry — `savings_delete_
  /// self_or_leader_pending`/`savings_delete_staff` (migrations 0086/0014)
  /// both scope this to `status = 'pending'` only, so a verified entry
  /// can never be touched from here. The realtime stream backing this list
  /// removes the row on its own once the DELETE lands — no manual reload
  /// needed, unlike SavingsHistoryPage's one-shot fetch.
  Future<void> _reject(SavingsEntry e) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.savingsLedgerRejectConfirmTitle),
        content: Text(l10n.savingsLedgerRejectConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.savingsLedgerRejectConfirmButton)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _rejecting.add(e.id));
    try {
      await widget.repo.deletePendingEntry(e.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.savingsLedgerRejectError)));
      }
    } finally {
      if (mounted) setState(() => _rejecting.remove(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final repo = widget.repo;
    final l10n = AppLocalizations.of(context)!;
    if (entries.isEmpty) {
      return AppEmptyState(icon: Icons.fact_check_rounded, message: l10n.savingsLedgerEmpty);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final verifying = _verifying.contains(e.id);
        final rejecting = _rejecting.contains(e.id);
        final memberName = widget.memberNames[e.memberId] ?? e.memberName;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padded: false,
            child: AppListRow(
              leading: AppAvatar(name: memberName, size: 36),
              title: memberName,
              subtitle: widget.isPlatformWide && e.shgName != null
                  ? '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode} · ${e.frequency} · ${l10n.savingsLedgerShgName(e.shgName!)}'
                  : '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode} · ${e.frequency}',
              // A Column, not the bare AppButton beside a reject icon —
              // stacking avoids the same trailing-slot overflow class
              // already caught (and fixed the same way) elsewhere this
              // round in `shg_members_page.dart`/`savings_history_page.dart`.
              //
              // `e.memberId != widget.viewerId` — `savings_update_leader_or_
              // staff` (RLS) self-excludes both the leader and staff
              // branches (round 190), so a leader/staff account's own
              // pending entry can never actually be verified this way; the
              // button used to still render, get tapped, and hit a silent
              // 0-row no-op surfaced only as the generic error snackbar,
              // reading as a bug rather than a rule. Own-row pending
              // entries now show a plain read-only status badge instead.
              trailing: e.status == 'pending' && e.memberId != widget.viewerId
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppButton(
                          size: ButtonSize.sm,
                          variant: ButtonVariant.secondary,
                          label: verifying ? l10n.savingsLedgerVerifying : l10n.savingsLedgerVerifyAction('₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}'),
                          onPressed: !SupabaseService.isConfigured || verifying || rejecting
                              ? null
                              : () async {
                                  setState(() => _verifying.add(e.id));
                                  try {
                                    await repo.verifyEntry(e.id);
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(l10n.savingsLedgerVerifyError)),
                                      );
                                    }
                                  } finally {
                                    if (mounted) setState(() => _verifying.remove(e.id));
                                  }
                                },
                        ),
                        const SizedBox(height: 4),
                        rejecting
                            ? const Padding(padding: EdgeInsets.all(4), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                            : TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                onPressed: !SupabaseService.isConfigured || verifying ? null : () => _reject(e),
                                child: Text(l10n.savingsLedgerRejectAction, style: AppTheme.sans(11, weight: FontWeight.w600, color: Accent.red600)),
                              ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        e.status == 'pending'
                            ? AppBadge(text: l10n.savingsStatusPending, tone: BadgeTone.warning)
                            : AppBadge(text: l10n.savingsLedgerVerifiedBadge, tone: BadgeTone.success),
                      ],
                    ),
              chevron: false,
            ),
          ),
        );
      },
    );
  }
}
