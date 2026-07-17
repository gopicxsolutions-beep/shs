import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/announcements.dart';
import '../../data/loans.dart';
import '../../data/meetings.dart';
import '../../data/members.dart';
import '../../data/savings.dart';
import '../../data/schemes.dart';
import '../../data/shg.dart';
import '../../data/training.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class MemberDashboard extends StatelessWidget {
  const MemberDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final myLoan = loans.where((l) => l.memberName == 'Lakshmi Devi' && l.status == 'active').firstOrNull;
    final upcomingMeeting = meetings.where((m) => m.status == 'upcoming').firstOrNull;
    final inProgressCourse = courses.where((c) => c.progress > 0 && c.progress < 100).firstOrNull;
    final myAttendance = members.where((m) => m.name == 'Lakshmi Devi').firstOrNull?.attendance ?? 0;
    final newSchemesCount = schemes.where((s) => s.status == 'not_applied').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'My Savings', value: '₹48,200', tone: StatTone.brand, trend: '+₹500 this week', icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Outstanding Loan', value: '₹22,000', tone: StatTone.gold, trend: 'Next EMI 10 Jul', icon: Icons.account_balance_rounded)),
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
                IconTile(onTap: () => context.go(Paths.savingsEntry), icon: Icons.account_balance_wallet_rounded, label: 'Add Savings', tone: TileTone.brand),
                IconTile(onTap: () => context.go(Paths.loanApply), icon: Icons.account_balance_rounded, label: 'Apply Loan', tone: TileTone.gold),
                IconTile(onTap: () => context.go(Paths.meetingQr), icon: Icons.qr_code_rounded, label: 'Attendance', tone: TileTone.sky),
                IconTile(onTap: () => context.go(Paths.schemes), icon: Icons.description_rounded, label: 'Schemes', tone: TileTone.violet, badge: newSchemesCount > 0 ? '$newSchemesCount' : null),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: AppCard(
                  onTap: () => context.go(Paths.reportsMember),
                  child: Row(children: [
                    Icon(Icons.event_available_rounded, size: 16, color: Brand.c600),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$myAttendance%', style: AppTheme.sans(14, weight: FontWeight.w700)),
                      Text('Attendance', style: AppTheme.sans(10, color: Neutral.c500)),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  onTap: () => context.go(Paths.schemes),
                  child: Row(children: [
                    Icon(Icons.description_rounded, size: 16, color: Accent.violet600),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$newSchemesCount new', style: AppTheme.sans(14, weight: FontWeight.w700)),
                      Text('Schemes available', style: AppTheme.sans(10, color: Neutral.c500)),
                    ])),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Savings Summary', action: 'View all', onAction: () => context.go(Paths.savings)),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('₹48,200', style: AppTheme.display(22)),
                    Text('Group total: ₹${ShgInfo.totalSavings}', style: AppTheme.sans(11, color: Neutral.c500)),
                  ]),
                  const AppBadge(text: '+18% YoY', tone: BadgeTone.success),
                ]),
                const SizedBox(height: 12),
                SizedBox(height: 64, child: _SavingsTrendChart()),
              ]),
            ),
          ]),
        ),
        if (myLoan != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionHeader(title: 'Loan Summary', action: 'Track', onAction: () => context.go(Paths.loanTracking)),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(myLoan.purpose, style: AppTheme.sans(12, color: Neutral.c500)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('₹${myLoan.outstanding}', style: AppTheme.display(18)),
                    Text('of ₹${myLoan.amount}', style: AppTheme.sans(12, color: Neutral.c500)),
                  ]),
                  const SizedBox(height: 8),
                  AppProgressBar(value: myLoan.amount - myLoan.outstanding, max: myLoan.amount, tone: ProgressTone.gold),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    AppBadge(text: 'EMI ₹${myLoan.emi} due ${myLoan.nextDueDate}', tone: BadgeTone.warning, dot: true),
                    InkWell(onTap: () => context.go(Paths.paymentsQr), child: Text('Pay now', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600))),
                  ]),
                ]),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(children: [
            if (upcomingMeeting != null)
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.event_note_rounded, size: 14, color: Brand.c600), const SizedBox(width: 6), Text('MEETING ALERT', style: AppTheme.sans(10, weight: FontWeight.w700, color: Brand.c600))]),
                    const SizedBox(height: 8),
                    Text(upcomingMeeting.date, style: AppTheme.sans(14, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(upcomingMeeting.agenda, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
                    const SizedBox(height: 8),
                    InkWell(onTap: () => context.go(Paths.meetings), child: Text('Details', style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c600))),
                  ]),
                ),
              ),
            if (upcomingMeeting != null && inProgressCourse != null) const SizedBox(width: 12),
            if (inProgressCourse != null)
              Expanded(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.school_rounded, size: 14, color: Gold.c600), const SizedBox(width: 6), Text('TRAINING ALERT', style: AppTheme.sans(10, weight: FontWeight.w700, color: Gold.c600))]),
                    const SizedBox(height: 8),
                    Text(inProgressCourse.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    AppProgressBar(value: inProgressCourse.progress, tone: ProgressTone.gold),
                    const SizedBox(height: 8),
                    InkWell(onTap: () => context.go(Paths.trainingDetail(inProgressCourse.id)), child: Text('Continue', style: AppTheme.sans(11, weight: FontWeight.w700, color: Gold.c600))),
                  ]),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: AppCard(
            onTap: () => context.go(Paths.aiFinancialAdvisor),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: Accent.violet100, borderRadius: BorderRadius.circular(16)), child: Icon(Icons.auto_awesome_rounded, color: Accent.violet600, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Financial Advisor', style: AppTheme.sans(14, weight: FontWeight.w700)),
                Text('Your credit score estimate: 742 (Good)', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
              ])),
              Text('View', style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.violet600)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Recent Announcements', action: 'See all', onAction: () => context.go(Paths.announcements)),
            AppCard(
              padded: false,
              child: Column(
                children: announcements.take(3).map((a) {
                  return InkWell(
                    onTap: () => context.go(Paths.announcementDetail(a.id)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!a.read) Padding(padding: const EdgeInsets.only(top: 5, right: 8), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Brand.c500, shape: BoxShape.circle))),
                        if (a.read) const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c800)),
                          Text(a.date, style: AppTheme.sans(10, color: Neutral.c400)),
                        ])),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

class _SavingsTrendChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < savingsMonthlyTrend.length; i++) FlSpot(i.toDouble(), savingsMonthlyTrend[i].$2.toDouble())],
            isCurved: true,
            color: Brand.c600,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Brand.c500.withValues(alpha: 0.18)),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
