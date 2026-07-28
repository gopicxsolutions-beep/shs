import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../repositories/savings_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/list_row.dart';

String _savingsStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'verified' => l10n.savingsStatusVerified,
      'pending' => l10n.savingsStatusPending,
      _ => status,
    };

class SavingsHistoryPage extends StatefulWidget {
  const SavingsHistoryPage({super.key});
  @override
  State<SavingsHistoryPage> createState() => _SavingsHistoryPageState();
}

class _SavingsHistoryPageState extends State<SavingsHistoryPage> {
  final _repo = SavingsRepository();
  final _key = GlobalKey<AppAsyncBuilderState<List<SavingsEntry>>>();
  String? _deletingId;

  /// A still-`pending` entry never contributed to any verified total (see
  /// `savings_delete_self_or_leader_pending`, migration 0086's own doc
  /// comment) — a member can now correct her own mistake (wrong amount,
  /// accidental double-submit) instead of it being permanent from the
  /// instant of submission. A verified entry stays staff-delete-only, so no
  /// action is offered here once `status` moves past `pending`.
  Future<void> _deleteEntry(SavingsEntry e) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.savingsHistoryDeleteConfirmTitle),
        content: Text(l10n.savingsHistoryDeleteConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingId = e.id);
    try {
      await _repo.deletePendingEntry(e.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.savingsHistoryDeletedMessage : l10n.profileUpdateDemoMode)));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.savingsHistoryDeleteError)));
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(title: l10n.savingsHistoryTitle),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await _key.currentState?.reload();
          } catch (_) {
            // The FutureBuilder inside AppAsyncBuilder already surfaces this
            // failure with its own retry UI — swallow it here so it isn't
            // also reported as an unhandled async exception by
            // RefreshIndicator's separate listener on the same future.
          }
        },
        child: AppAsyncBuilder<List<SavingsEntry>>(
          key: _key,
          future: () => _repo.fetchForMember(memberId),
          builder: (context, entries) {
            if (entries.isEmpty) {
              return ListView(children: [AppEmptyState(icon: Icons.history_rounded, message: l10n.savingsHistoryEmpty)]);
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
                      title: l10n.savingsFrequencyEntryTitle(e.frequency),
                      subtitle: '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode}',
                      // Column, not Row — stacking the delete icon below the
                      // badge (rather than beside it) avoids the exact
                      // trailing-slot overflow class already caught by the
                      // stress-test suite on `shg_members_page.dart` this
                      // same round (`AppListRow`'s `Flexible(fit: loose)`
                      // bounds available width but doesn't force a
                      // `mainAxisSize: min` Row's own children to shrink).
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${NumberFormat('#,##,##0', 'en_IN').format(e.amount)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          AppBadge(text: _savingsStatusLabel(l10n, e.status), tone: e.status == 'verified' ? BadgeTone.success : BadgeTone.warning),
                          if (e.status == 'pending') ...[
                            const SizedBox(height: 4),
                            _deletingId == e.id
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    color: Accent.red600,
                                    tooltip: l10n.savingsHistoryDeleteTooltip,
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _deleteEntry(e),
                                  ),
                          ],
                        ],
                      ),
                      chevron: false,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
