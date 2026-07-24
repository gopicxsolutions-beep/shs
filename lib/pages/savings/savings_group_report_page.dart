import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../repositories/savings_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/list_row.dart';

class SavingsGroupReportPage extends StatelessWidget {
  const SavingsGroupReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Only `profile?.shgId` is used below. `.watch<AppState>()` would
    // rebuild this whole page — including the per-member totals map, sort,
    // and monthly trend, all recomputed synchronously in build(), plus an
    // eagerly-built (non-lazy) `ListView` of every ranked member row — on
    // every unrelated AppState change (e.g. the periodic token-refresh
    // notify in app_state.dart's `_authSub`), even though nothing this page
    // displays depends on it. `.select` only rebuilds when shgId changes.
    final shgId = context.select<AppState, String?>((s) => s.profile?.shgId);
    final repo = SavingsRepository();

    return Scaffold(
      appBar: PageHeader(title: l10n.savingsGroupReportTitle),
      body: AppAsyncBuilder<List<SavingsEntry>>(
        future: () => repo.fetchForShg(shgId),
        builder: (context, entries) {
          if (entries.isEmpty) {
            return Center(child: AppEmptyState(icon: Icons.groups_rounded, message: l10n.savingsGroupReportEmpty));
          }
          // Only verified entries count as confirmed group savings — a
          // pending entry is an unconfirmed self-report not yet reconciled
          // by the SHG leader.
          final verifiedEntries = entries.where((e) => e.status == 'verified').toList();
          // See SavingsRepository.aggregateVerifiedTotals's own doc comment
          // for why this is keyed by memberId, not memberName. `names`
          // tracks the display name for each id separately, purely for
          // rendering — built from the same entry list.
          final totals = SavingsRepository.aggregateVerifiedTotals(verifiedEntries);
          final names = <String, String>{for (final e in verifiedEntries) e.memberId: e.memberName};
          final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final groupTotal = totals.values.fold<num>(0, (a, b) => a + b);
          final trend = repo.monthlyTrend(verifiedEntries);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.savingsGroupReportTotalLabel, style: AppTheme.sans(12, color: Neutral.c500)),
                    const SizedBox(height: 4),
                    Text('₹${NumberFormat('#,##,##0', 'en_IN').format(groupTotal)}', style: AppTheme.display(24)),
                    const SizedBox(height: 4),
                    Text(l10n.savingsGroupReportSummary(totals.length, trend.length), style: AppTheme.sans(11, color: Neutral.c500)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padded: false,
                child: Column(
                  children: [
                    for (var i = 0; i < sorted.length; i++)
                      AppListRow(
                        leading: AppAvatar(name: names[sorted[i].key]!, size: 36),
                        title: names[sorted[i].key]!,
                        subtitle: l10n.savingsGroupReportRank(i + 1),
                        trailing: Text('₹${NumberFormat('#,##,##0', 'en_IN').format(sorted[i].value)}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                        chevron: false,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
