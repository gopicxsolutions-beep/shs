import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../repositories/savings_repository.dart';
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
class SavingsLedgerPage extends StatelessWidget {
  const SavingsLedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = SavingsRepository();
    final shgId = appState.profile?.shgId;
    final live = SupabaseService.isConfigured && shgId != null;

    return Scaffold(
      appBar: PageHeader(
        title: 'Savings Ledger',
        subtitle: live ? 'Live' : null,
        right: IconButton(icon: const Icon(Icons.add_circle_rounded, color: Brand.c600), onPressed: () => context.go(Paths.savingsEntry), tooltip: 'Add savings'),
      ),
      body: live
          ? StreamBuilder<List<SavingsEntry>>(
              stream: repo.watchForShg(shgId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Could not load the ledger. Please try again.', style: AppTheme.sans(13, color: Neutral.c500)));
                }
                return _LedgerList(entries: snapshot.data ?? const [], repo: repo);
              },
            )
          : AppAsyncBuilder<List<SavingsEntry>>(
              future: () => repo.fetchForShg(shgId),
              builder: (context, entries) => _LedgerList(entries: entries, repo: repo),
            ),
    );
  }
}

class _LedgerList extends StatelessWidget {
  final List<SavingsEntry> entries;
  final SavingsRepository repo;
  const _LedgerList({required this.entries, required this.repo});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(icon: Icons.fact_check_rounded, message: 'No savings entries recorded yet');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padded: false,
            child: AppListRow(
              leading: AppAvatar(name: e.memberName, size: 36),
              title: e.memberName,
              subtitle: '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode} · ${e.frequency}',
              trailing: e.status == 'pending'
                  ? SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        onPressed: !SupabaseService.isConfigured
                            ? null
                            : () async {
                                try {
                                  await repo.verifyEntry(e.id);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not verify this entry. Please try again.')),
                                    );
                                  }
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(color: Brand.c500),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('₹${e.amount} · Verify', style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c600)),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('₹${e.amount}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const AppBadge(text: 'verified', tone: BadgeTone.success),
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
