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
  const SavingsLedgerPage({super.key});

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
      ShgRepository().fetchMembers(shgId).then((members) {
        if (mounted) setState(() => _memberNames = {for (final m in members) m.id: m.name});
      });
      // Deliberately no .catchError: a failed roster fetch just means names
      // fall back to the stream's own 'Member' placeholder (today's
      // pre-fix behavior) rather than surfacing a second error state on top
      // of whatever the ledger's own StreamBuilder/AppAsyncBuilder already
      // shows for a real failure.
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
    final repo = SavingsRepository();
    final live = SupabaseService.isConfigured && shgId != null;
    final l10n = AppLocalizations.of(context)!;

    // This route is already router-restricted to leader/staff (see
    // `_roleRestrictedPrefixes` in router.dart), so anyone here passed that
    // gate — but crp/clf/admin still have no `profile.shgId` of their own
    // (platform-wide roles, never SHG-scoped), and `fetchForShg(null)`
    // silently resolves to an empty list, rendering as an indistinguishable
    // "no entries yet" instead of explaining the real reason. Checked
    // against `isConfigured`, not just `shgId`, because demo mode's
    // simulated identity leaves `profile` (and so `shgId`) null for every
    // previewed role too, and must keep showing its own intentional mock
    // ledger unaffected by this guard.
    if (SupabaseService.isConfigured && shgId == null) {
      return Scaffold(
        appBar: PageHeader(title: l10n.savingsLedgerTitle),
        body: AppEmptyState(icon: Icons.groups_rounded, message: l10n.commonStaffNoShgMessage),
      );
    }

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
                return _LedgerList(entries: snapshot.data ?? const [], repo: repo, memberNames: _memberNames);
              },
            )
          : AppAsyncBuilder<List<SavingsEntry>>(
              future: () => repo.fetchForShg(shgId),
              builder: (context, entries) => _LedgerList(entries: entries, repo: repo, memberNames: _memberNames),
            ),
    );
  }
}

class _LedgerList extends StatefulWidget {
  final List<SavingsEntry> entries;
  final SavingsRepository repo;
  final Map<String, String> memberNames;
  const _LedgerList({required this.entries, required this.repo, required this.memberNames});

  @override
  State<_LedgerList> createState() => _LedgerListState();
}

class _LedgerListState extends State<_LedgerList> {
  final _verifying = <String>{};

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
        final memberName = widget.memberNames[e.memberId] ?? e.memberName;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padded: false,
            child: AppListRow(
              leading: AppAvatar(name: memberName, size: 36),
              title: memberName,
              subtitle: '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode} · ${e.frequency}',
              trailing: e.status == 'pending'
                  ? SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        onPressed: !SupabaseService.isConfigured || verifying
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
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: Brand.c500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          verifying ? l10n.savingsLedgerVerifying : l10n.savingsLedgerVerifyAction('₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}'),
                          style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c600),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        AppBadge(text: l10n.savingsLedgerVerifiedBadge, tone: BadgeTone.success),
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
