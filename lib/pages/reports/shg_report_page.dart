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

class ShgReportPage extends StatelessWidget {
  const ShgReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shgId = context.watch<AppState>().profile?.shgId;
    final repo = ReportRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'SHG Reports'),
      body: AppAsyncBuilder<ShgReportData>(
        future: () => repo.fetchShgReport(shgId),
        builder: (context, r) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(r.period, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'Members', value: '${r.memberCount}', tone: StatTone.ink, icon: Icons.groups_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Active Loans', value: '${r.activeLoanCount}', tone: StatTone.gold, icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'Total Savings', value: '₹${r.totalSavings}', tone: StatTone.brand, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loan Outstanding', value: '₹${r.totalOutstanding}', tone: StatTone.danger, icon: Icons.warning_amber_rounded)),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Average Attendance', style: AppTheme.sans(13, weight: FontWeight.w700)),
                      Text('${r.avgAttendancePct.toStringAsFixed(0)}%', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: r.avgAttendancePct / 100, minHeight: 8, backgroundColor: Neutral.c100, color: Brand.c500),
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
