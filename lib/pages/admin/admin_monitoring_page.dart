import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../layout/page_header.dart';
import '../../models/admin.dart';
import '../../repositories/admin_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/stat_card.dart';

class AdminMonitoringPage extends StatelessWidget {
  const AdminMonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AdminRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'System Monitoring'),
      body: AppAsyncBuilder<SystemHealth>(
        future: repo.fetchSystemHealth,
        builder: (context, h) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: StatCard(label: 'Total Users', value: '${h.totalUsers}', tone: StatTone.brand, icon: Icons.people_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Total SHGs', value: '${h.totalShgs}', tone: StatTone.ink, icon: Icons.apartment_rounded)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: StatCard(label: 'Savings Entries', value: '${h.totalSavingsEntries}', tone: StatTone.gold, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loans (pending)', value: '${h.totalLoans} (${h.pendingLoans})', tone: StatTone.danger, icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: Neutral.c400),
                      const SizedBox(width: 6),
                      Text('Placeholder metrics', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'These are basic row counts, not real infrastructure metrics (uptime, latency, error rate). Wiring real monitoring needs a dedicated Edge Function or an external service.',
                      style: AppTheme.sans(12, color: Neutral.c500),
                    ),
                    const SizedBox(height: 8),
                    Text('Checked ${DateFormat('dd MMM yyyy, hh:mm a').format(h.checkedAt)}', style: AppTheme.sans(11, color: Neutral.c400)),
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
