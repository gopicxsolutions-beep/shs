import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan.dart';
import '../../models/meeting.dart';
import '../../models/report.dart';
import '../../models/shg.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/meeting_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class _LeaderDashboardData {
  final ShgReportData report;
  final ShgProfile? shg;
  final List<Loan> pendingLoans;
  final List<Loan> overdueLoans;
  final Meeting? upcomingMeeting;
  const _LeaderDashboardData({required this.report, required this.shg, required this.pendingLoans, required this.overdueLoans, required this.upcomingMeeting});
}

class LeaderDashboard extends StatelessWidget {
  const LeaderDashboard({super.key});

  Future<_LeaderDashboardData> _load(BuildContext context) async {
    final shgId = context.read<AppState>().profile?.shgId;
    final results = await Future.wait([
      ReportRepository().fetchShgReport(shgId),
      ShgRepository().fetchShg(shgId),
      LoanRepository().fetchForShg(shgId),
      MeetingRepository().fetchForShg(shgId),
    ]);
    final loans = results[2] as List<Loan>;
    final meetings = results[3] as List<Meeting>;
    // `fetchForShg` sorts newest-scheduled-date-first — same bug already
    // fixed in meeting_qr_page.dart/meeting_attendance_page.dart/
    // member_dashboard.dart: without re-sorting by date ascending, this
    // picked the farthest-future upcoming meeting instead of the soonest.
    // `!m.hasPassed` also excludes meetings whose date has already gone by
    // — nothing in the app ever advances `status` away from 'upcoming'
    // once a meeting happens (see `Meeting.hasPassed`'s doc comment), so
    // without it a meeting from weeks ago would keep showing as the
    // dashboard's "next meeting" forever.
    final upcoming = meetings.where((m) => m.status == 'upcoming' && !m.hasPassed).toList()..sort((a, b) => a.date.compareTo(b.date));
    return _LeaderDashboardData(
      report: results[0] as ShgReportData,
      shg: results[1] as ShgProfile?,
      pendingLoans: loans.where((l) => l.status == 'pending').toList(),
      overdueLoans: loans.where((l) => l.status == 'overdue').toList(),
      upcomingMeeting: upcoming.isEmpty ? null : upcoming.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncBuilder<_LeaderDashboardData>(
      future: () => _load(context),
      builder: (context, data) => _LeaderDashboardBody(data: data),
    );
  }
}

class _LeaderDashboardBody extends StatelessWidget {
  final _LeaderDashboardData data;
  const _LeaderDashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final report = data.report;
    final pendingLoans = data.pendingLoans;
    final overdueLoans = data.overdueLoans;
    final upcomingMeeting = data.upcomingMeeting;
    final recoveryPct = report.activeLoanCount > 0 ? ((1 - (overdueLoans.length / report.activeLoanCount)) * 100).round() : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'Group Savings', value: '₹${(report.totalSavings / 100000).toStringAsFixed(1)}L', tone: StatTone.brand, trend: '${report.memberCount} members', icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Loans Outstanding', value: '₹${(report.totalOutstanding / 100000).toStringAsFixed(1)}L', tone: StatTone.gold, trend: '${overdueLoans.length} overdue', icon: Icons.account_balance_rounded)),
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
                IconTile(
                  onTap: () => context.go(Paths.loanApproval),
                  icon: Icons.fact_check_rounded,
                  label: 'Approvals',
                  tone: TileTone.gold,
                  badge: pendingLoans.isNotEmpty ? '${pendingLoans.length}' : null,
                  badgeSemanticLabel: pendingLoans.isNotEmpty ? 'Approvals, ${pendingLoans.length} pending' : null,
                ),
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
                  Text(
                    overdueLoans.first.nextDueDate != null
                        ? '${overdueLoans.first.memberName} — EMI overdue since ${DateFormat('dd MMM').format(overdueLoans.first.nextDueDate!)}'
                        : '${overdueLoans.first.memberName} — EMI overdue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(12, color: Accent.red500),
                  ),
                ])),
                // Paths.loanTracking always shows the signed-in user's own
                // loans, not the SHG's — for a leader tapping "View" here
                // that was showing their own unrelated loan instead of the
                // actual defaulting member's. Route to that loan directly.
                InkWell(onTap: () => context.go(Paths.loanDetail(overdueLoans.first.id)), child: Text('View', style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.red600))),
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
                              AppBadge(text: '₹${NumberFormat('#,##,##0', 'en_IN').format(l.amount)}', tone: BadgeTone.warning),
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
                    // This calendar-style date badge is a fixed 48x48
                    // square by design — at a scaled-up accessibility text
                    // size the month + day text no longer fits that
                    // height. FittedBox scales the pair down together to
                    // stay inside the square instead of overflowing it.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(DateFormat('MMM').format(upcomingMeeting.date), style: AppTheme.sans(9, weight: FontWeight.w700, color: Brand.c700)),
                        Text(DateFormat('dd').format(upcomingMeeting.date), style: AppTheme.sans(15, weight: FontWeight.w700, color: Brand.c700)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(upcomingMeeting.agenda ?? 'Meeting', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                    Text('${upcomingMeeting.time ?? ''} · ${upcomingMeeting.venue ?? ''}', style: AppTheme.sans(11, color: Neutral.c500)),
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
              Expanded(child: _healthTile(data.shg?.grade ?? '—', 'Grading')),
              const SizedBox(width: 12),
              Expanded(child: _healthTile('${report.avgAttendancePct.round()}%', 'Attendance')),
              const SizedBox(width: 12),
              Expanded(child: _healthTile('$recoveryPct%', 'Recovery')),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _healthTile(String value, String label) => AppCard(
        child: Semantics(
          label: '$label: $value',
          child: ExcludeSemantics(
            child: Column(children: [
              Text(value, style: AppTheme.display(16, color: Brand.c700)),
              const SizedBox(height: 2),
              Text(label, style: AppTheme.sans(10, color: Neutral.c500)),
            ]),
          ),
        ),
      );
}
