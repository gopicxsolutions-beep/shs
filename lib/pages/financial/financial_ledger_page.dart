import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/financial_entry.dart';
import '../../models/types.dart';
import '../../repositories/financial_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import 'financial_entry_dialog.dart';

/// Shared UI for cashbook/ledger/bank/audit — all four are the same shape,
/// just filtered by `financial_ledger.entry_type`. The only entry point the
/// rest of the app links to is Cashbook (Services tile) and Audit (SHG
/// Reports), so Ledger and Bank Reconciliation had no way to be reached from
/// the UI at all — this in-page switcher fixes that by letting any of the
/// four link to the other three.
List<(String entryType, String label, String path, IconData icon, TileTone tone)> _recordTypes(AppLocalizations l10n) => [
  ('cashbook', l10n.financialLedgerCashbookLabel, Paths.financialCashbook, Icons.receipt_long_rounded, TileTone.ink),
  ('ledger', l10n.financialLedgerLedgerLabel, Paths.financialLedger, Icons.menu_book_rounded, TileTone.sky),
  ('bank', l10n.financialLedgerBankLabel, Paths.financialBank, Icons.account_balance_rounded, TileTone.gold),
  ('audit', l10n.financialLedgerAuditLabel, Paths.financialAudit, Icons.fact_check_rounded, TileTone.violet),
];

class FinancialLedgerPage extends StatefulWidget {
  final String entryType;
  final String title;
  const FinancialLedgerPage({super.key, required this.entryType, required this.title});

  @override
  State<FinancialLedgerPage> createState() => _FinancialLedgerPageState();
}

class _FinancialLedgerPageState extends State<FinancialLedgerPage> {
  final _repo = FinancialRepository();
  final GlobalKey<AppAsyncBuilderState<List<FinancialEntry>>> _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final shgId = appState.profile?.shgId;
    final l10n = AppLocalizations.of(context)!;
    final recordTypes = _recordTypes(l10n);

    return Scaffold(
      appBar: PageHeader(
        title: widget.title,
        right: isLeaderOrStaff
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: Brand.c600),
                tooltip: l10n.financialLedgerAddEntryTooltip,
                onPressed: () async {
                  final added = await showFinancialEntryDialog(context, _repo, shgId: shgId, createdBy: appState.profile?.id, entryType: widget.entryType);
                  if (added == true) {
                    _key.currentState?.reload();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.financialLedgerEntryAdded : l10n.financialLedgerDemoMode)));
                    }
                  }
                },
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (final t in recordTypes.where((t) => t.$1 != widget.entryType)) IconTile(onTap: () => context.go(t.$3), icon: t.$4, label: t.$2, tone: t.$5)],
            ),
          ),
          Expanded(
            child: AppAsyncBuilder<List<FinancialEntry>>(
              key: _key,
              future: () => _repo.fetchForShg(shgId, widget.entryType),
              builder: (context, entries) {
                if (entries.isEmpty) {
                  return AppEmptyState(icon: Icons.receipt_long_rounded, message: l10n.financialLedgerEmpty(widget.title.toLowerCase()));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final isCredit = e.credit > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: isCredit ? Brand.c50 : Accent.red50, borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: isCredit ? Brand.c600 : Accent.red600),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.sans(13, weight: FontWeight.w700),
                                  ),
                                  Text(DateFormat('dd MMM yyyy').format(e.date), style: AppTheme.sans(11, color: Neutral.c500)),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    isCredit ? '+₹${NumberFormat('#,##,##0', 'en_IN').format(e.credit)}' : '-₹${NumberFormat('#,##,##0', 'en_IN').format(e.debit)}',
                                    style: AppTheme.sans(13, weight: FontWeight.w700, color: isCredit ? Brand.c600 : Accent.red600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // `balance` is a running total (`previousBalance + credit -
                                  // debit`, see FinancialRepository) with no floor clamp, so it
                                  // can legitimately go negative (e.g. the cashbook running
                                  // low) — interpolating the raw signed number put the minus
                                  // sign after the ₹ symbol ("Bal ₹-500"), which reads as a
                                  // typo rather than a negative balance. Pull the sign out
                                  // front instead, and format the magnitude like every other
                                  // amount on this page/app.
                                  Text(
                                    'Bal ${e.balance < 0 ? '-' : ''}₹${NumberFormat('#,##,##0', 'en_IN').format(e.balance.abs())}',
                                    style: AppTheme.sans(11, color: e.balance < 0 ? Accent.red600 : Neutral.c500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
