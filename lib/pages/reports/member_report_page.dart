import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/report.dart';
import '../../repositories/report_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

/// Hub for the 3 named member reports the spec calls for (Savings
/// Statement, Loan Statement, Attendance Report), plus a quick at-a-glance
/// overview on top.
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
                Expanded(child: StatCard(label: 'Total Savings', value: '₹${NumberFormat('#,##,##0', 'en_IN').format(r.totalSavings)}', tone: StatTone.brand, trend: '${r.savingsEntryCount} entries', icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loan Outstanding', value: '₹${NumberFormat('#,##,##0', 'en_IN').format(r.totalOutstanding)}', tone: StatTone.gold, trend: '${r.activeLoanCount} active', icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 20),
              Text('Reports', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
              const SizedBox(height: 12),
              _ReportTile(
                icon: Icons.receipt_long_rounded,
                title: 'Savings Statement',
                subtitle: 'Running balance across every savings entry',
                onTap: () => context.go(Paths.savingsStatement),
              ),
              const SizedBox(height: 8),
              _ReportTile(
                icon: Icons.account_balance_rounded,
                title: 'Loan Statement',
                subtitle: 'Every loan, EMI schedule & outstanding balance',
                onTap: () => context.go(Paths.reportsLoanStatement),
              ),
              const SizedBox(height: 8),
              _ReportTile(
                icon: Icons.event_available_rounded,
                title: 'Attendance Report',
                subtitle: '${r.attendancePct.toStringAsFixed(0)}% · ${r.meetingsAttended} of ${r.meetingsTotal} meetings',
                onTap: () => context.go(Paths.reportsAttendance),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ReportTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Icon(icon, size: 18, color: Brand.c600)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.sans(13, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTheme.sans(11, color: Neutral.c500)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: Neutral.c300),
      ]),
    );
  }
}
