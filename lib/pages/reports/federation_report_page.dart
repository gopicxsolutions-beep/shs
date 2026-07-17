import 'package:flutter/material.dart';
import '../../layout/page_header.dart';
import '../../models/report.dart';
import '../../repositories/report_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

class FederationReportPage extends StatelessWidget {
  const FederationReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ReportRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Federation Reports'),
      body: AppAsyncBuilder<FederationReportData>(
        future: repo.fetchFederationReport,
        builder: (context, r) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(r.period, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'SHGs', value: '${r.shgCount}', tone: StatTone.ink, icon: Icons.apartment_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Members', value: '${r.memberCount}', tone: StatTone.brand, icon: Icons.groups_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'Total Savings', value: '₹${r.totalSavings}', tone: StatTone.brand, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loan Outstanding', value: '₹${r.totalOutstanding}', tone: StatTone.gold, icon: Icons.account_balance_rounded)),
              ]),
            ],
          );
        },
      ),
    );
  }
}
