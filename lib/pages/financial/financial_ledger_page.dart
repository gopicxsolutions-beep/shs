import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/financial_entry.dart';
import '../../models/types.dart';
import '../../repositories/financial_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import 'financial_entry_dialog.dart';

/// Shared UI for cashbook/ledger/bank/audit — all four are the same shape,
/// just filtered by `financial_ledger.entry_type`.
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

    return Scaffold(
      appBar: PageHeader(
        title: widget.title,
        right: isLeaderOrStaff
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: SupabaseService.isConfigured ? Brand.c600 : Neutral.c300),
                onPressed: !SupabaseService.isConfigured
                    ? null
                    : () async {
                        final added = await showFinancialEntryDialog(context, _repo, shgId: shgId, createdBy: appState.profile?.id, entryType: widget.entryType);
                        if (added == true) _key.currentState?.reload();
                      },
              )
            : null,
      ),
      body: AppAsyncBuilder<List<FinancialEntry>>(
        key: _key,
        future: () => _repo.fetchForShg(shgId, widget.entryType),
        builder: (context, entries) {
          if (entries.isEmpty) {
            return AppEmptyState(icon: Icons.receipt_long_rounded, message: 'No ${widget.title.toLowerCase()} entries yet');
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
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: isCredit ? Brand.c50 : Accent.red50, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: isCredit ? Brand.c600 : Accent.red600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                          Text(DateFormat('dd MMM yyyy').format(e.date), style: AppTheme.sans(11, color: Neutral.c500)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isCredit ? '+₹${e.credit}' : '-₹${e.debit}',
                          style: AppTheme.sans(13, weight: FontWeight.w700, color: isCredit ? Brand.c600 : Accent.red600),
                        ),
                        Text('Bal ₹${e.balance}', style: AppTheme.sans(11, color: Neutral.c500)),
                      ],
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
