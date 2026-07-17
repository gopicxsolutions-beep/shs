import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/report.dart';
import '../../repositories/report_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

class MemberReportPage extends StatelessWidget {
  const MemberReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;
    final shgId = appState.profile?.shgId;
    final repo = ReportRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'My Reports'),
      body: AppAsyncBuilder<MemberReport>(
        future: () => repo.fetchMemberReport(memberId: memberId, shgId: shgId),
        builder: (context, r) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(r.period, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'Total Savings', value: '₹${r.totalSavings}', tone: StatTone.brand, trend: '${r.savingsEntryCount} entries', icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loan Outstanding', value: '₹${r.totalOutstanding}', tone: StatTone.gold, trend: '${r.activeLoanCount} active', icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Meeting Attendance', style: AppTheme.sans(13, weight: FontWeight.w700)),
                      Text('${r.attendancePct.toStringAsFixed(0)}%', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: r.attendancePct / 100, minHeight: 8, backgroundColor: Neutral.c100, color: Brand.c500),
                    ),
                    const SizedBox(height: 6),
                    Text('${r.meetingsAttended} of ${r.meetingsTotal} meetings attended', style: AppTheme.sans(11, color: Neutral.c500)),
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
