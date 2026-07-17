import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/page_header.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

/// Hub for the 3 named SHG reports the spec calls for (Financial Summary,
/// Audit Report, Performance Report).
class ShgReportPage extends StatelessWidget {
  const ShgReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'SHG Reports'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Financial Summary',
            subtitle: 'Savings, loans & attendance at a glance',
            onTap: () => context.go(Paths.reportsShgFinancialSummary),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.fact_check_rounded,
            title: 'Audit Report',
            subtitle: 'Internal & external audit trail',
            onTap: () => context.go(Paths.financialAudit),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.trending_up_rounded,
            title: 'Performance Report',
            subtitle: 'Attendance trend & loan activity',
            onTap: () => context.go(Paths.reportsShgPerformance),
          ),
        ],
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
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Gold.c50, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Icon(icon, size: 18, color: Gold.c600)),
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
