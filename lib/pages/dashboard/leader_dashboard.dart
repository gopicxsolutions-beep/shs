import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/loans.dart';
import '../../data/meetings.dart';
import '../../data/shg.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/avatar.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class LeaderDashboard extends StatelessWidget {
  const LeaderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingLoans = loans.where((l) => l.status == 'pending').toList();
    final overdueLoans = loans.where((l) => l.status == 'overdue').toList();
    final upcomingMeeting = meetings.where((m) => m.status == 'upcoming').isNotEmpty ? meetings.firstWhere((m) => m.status == 'upcoming') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'Group Savings', value: '₹${(ShgInfo.totalSavings / 100000).toStringAsFixed(1)}L', tone: StatTone.brand, trend: '${ShgInfo.memberCount} members', icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Loans Outstanding', value: '₹${(ShgInfo.totalLoans / 100000).toStringAsFixed(1)}L', tone: StatTone.gold, trend: '${overdueLoans.length} overdue', icon: Icons.account_balance_rounded)),
            ]),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconTile(onTap: () => context.go(Paths.shgMembers), icon: Icons.groups_rounded, label: 'Members', tone: TileTone.brand),
                IconTile(onTap: () => context.go(Paths.loanApproval), icon: Icons.fact_check_rounded, label: 'Approvals', tone: TileTone.gold, badge: pendingLoans.isNotEmpty ? '${pendingLoans.length}' : null),
                IconTile(onTap: () => context.go(Paths.meetingSchedule), icon: Icons.event_rounded, label: 'Schedule', tone: TileTone.sky),
                IconTile(onTap: () => context.go(Paths.reportsShg), icon: Icons.bar_chart_rounded, label: 'Reports', tone: TileTone.violet),
              ],
            ),
          ),
        ),
        if (overdueLoans.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: AppCard(
              color: Accent.red50,
              borderColor: Accent.red100,
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Accent.red100, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.warning_rounded, color: Accent.red600, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${overdueLoans.length} Defaulter Alert${overdueLoans.length > 1 ? 's' : ''}', style: AppTheme.sans(14, weight: FontWeight.w700, color: Accent.red700)),
                  Text('${overdueLoans.first.memberName} — EMI overdue since ${overdueLoans.first.nextDueDate}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Accent.red500)),
                ])),
                InkWell(onTap: () => context.go(Paths.loanTracking), child: Text('View', style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.red600))),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Pending Loan Approvals', action: 'Review all', onAction: () => context.go(Paths.loanApproval)),
            AppCard(
              padded: false,
              child: pendingLoans.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text('No pending loan requests', style: AppTheme.sans(12, color: Neutral.c400)))
                  : Column(
                      children: pendingLoans.map((l) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              AppAvatar(name: l.memberName, size: 32),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l.memberName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                                Text(l.purpose, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c400)),
                              ])),
                              AppBadge(text: '₹${l.amount}', tone: BadgeTone.warning),
                            ]),
                          )).toList(),
                    ),
            ),
          ]),
        ),
        if (upcomingMeeting != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader(title: 'Next Meeting', action: 'Manage', onAction: () => context.go(Paths.meetings)),
              AppCard(
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(upcomingMeeting.date.split(' ').length > 1 ? upcomingMeeting.date.split(' ')[1] : '', style: AppTheme.sans(9, weight: FontWeight.w700, color: Brand.c700)),
                      Text(upcomingMeeting.date.split(' ')[0], style: AppTheme.sans(15, weight: FontWeight.w700, color: Brand.c700)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(upcomingMeeting.agenda, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                    Text('${upcomingMeeting.time} · ${upcomingMeeting.venue}', style: AppTheme.sans(11, color: Neutral.c500)),
                  ])),
                ]),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'SHG Health'),
            Row(children: [
              Expanded(child: _healthTile(ShgInfo.grade, 'Grading')),
              const SizedBox(width: 12),
              Expanded(child: _healthTile('96%', 'Attendance')),
              const SizedBox(width: 12),
              Expanded(child: _healthTile('94%', 'Recovery')),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _healthTile(String value, String label) => AppCard(
        child: Column(children: [
          Text(value, style: AppTheme.display(16, color: Brand.c700)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.sans(10, color: Neutral.c500)),
        ]),
      );
}
