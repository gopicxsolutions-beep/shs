import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/loan.dart';
import '../../models/meeting.dart';
import '../../models/report.dart';
import '../../models/savings.dart';
import '../../models/training.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/meeting_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/savings_repository.dart';
import '../../repositories/scheme_repository.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class _MemberDashboardData {
  final MemberReport report;
  final List<MonthlyTotal> savingsTrend;
  final Loan? activeLoan;
  final Meeting? upcomingMeeting;
  final Course? inProgressCourse;
  final int inProgressCoursePct;
  final int newSchemesCount;
  final List<_AnnouncementSummary> announcements;
  const _MemberDashboardData({
    required this.report,
    required this.savingsTrend,
    required this.activeLoan,
    required this.upcomingMeeting,
    required this.inProgressCourse,
    required this.inProgressCoursePct,
    required this.newSchemesCount,
    required this.announcements,
  });
}

class _AnnouncementSummary {
  final String id;
  final String title;
  final DateTime createdAt;
  final bool read;
  const _AnnouncementSummary({required this.id, required this.title, required this.createdAt, required this.read});
}

class MemberDashboard extends StatelessWidget {
  const MemberDashboard({super.key});

  Future<_MemberDashboardData> _load(BuildContext context) async {
    final appState = context.read<AppState>();
    final memberId = appState.profile?.id;
    final shgId = appState.profile?.shgId;

    final results = await Future.wait([
      ReportRepository().fetchMemberReport(memberId: memberId, shgId: shgId),
      SavingsRepository().fetchForMember(memberId),
      LoanRepository().fetchForMember(memberId),
      MeetingRepository().fetchForShg(shgId),
      TrainingRepository().fetchCourses(),
      TrainingRepository().fetchMyProgress(memberId),
      SchemeRepository().fetchSchemes(),
      SchemeRepository().fetchMyApplications(memberId),
      AnnouncementRepository().fetchForShg(shgId, memberId),
    ]);

    final report = results[0] as MemberReport;
    final savingsEntries = results[1] as List<SavingsEntry>;
    final loans = results[2] as List<Loan>;
    final meetings = results[3] as List<Meeting>;
    final courses = results[4] as List<Course>;
    final progress = results[5] as Map<String, CourseProgress>;
    final schemes = results[6] as List<dynamic>;
    final myApplications = results[7] as Map<String, dynamic>;
    final announcements = results[8] as List<dynamic>;

    final activeLoan = loans.where((l) => l.status == 'active' || l.status == 'overdue').firstOrNull;
    // `meetings` is sorted newest-scheduled-date-first (for the meetings
    // list view) — same bug already fixed in meeting_qr_page.dart and
    // meeting_attendance_page.dart: naively taking the first 'upcoming'
    // match picked the farthest-future meeting instead of the soonest one
    // whenever more than one was scheduled, showing the wrong date on the
    // dashboard's "MEETING ALERT" card. `!m.hasPassed` also excludes
    // meetings whose date has already gone by — nothing in the app ever
    // advances `status` away from 'upcoming' once a meeting happens (see
    // `Meeting.hasPassed`'s doc comment), so without it a meeting from
    // weeks ago would keep showing as the "next meeting" forever.
    final upcomingMeetings = meetings.where((m) => m.status == 'upcoming' && !m.hasPassed).toList()..sort((a, b) => a.date.compareTo(b.date));
    final upcomingMeeting = upcomingMeetings.firstOrNull;

    Course? inProgressCourse;
    int inProgressPct = 0;
    for (final c in courses) {
      final p = progress[c.id];
      if (p != null && p.progress > 0 && p.progress < 100) {
        inProgressCourse = c;
        inProgressPct = p.progress;
        break;
      }
    }

    final newSchemesCount = schemes.where((s) => !myApplications.containsKey(s.id as String)).length;

    return _MemberDashboardData(
      report: report,
      savingsTrend: SavingsRepository().monthlyTrend(savingsEntries),
      activeLoan: activeLoan,
      upcomingMeeting: upcomingMeeting,
      inProgressCourse: inProgressCourse,
      inProgressCoursePct: inProgressPct,
      newSchemesCount: newSchemesCount,
      announcements: announcements
          .take(3)
          .map((a) => _AnnouncementSummary(id: a.id as String, title: a.title as String, createdAt: a.createdAt as DateTime, read: a.read as bool))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppAsyncBuilder<_MemberDashboardData>(
      future: () => _load(context),
      builder: (context, data) => _MemberDashboardBody(data: data),
    );
  }
}

class _MemberDashboardBody extends StatelessWidget {
  final _MemberDashboardData data;
  const _MemberDashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final report = data.report;
    final myLoan = data.activeLoan;
    final upcomingMeeting = data.upcomingMeeting;
    final inProgressCourse = data.inProgressCourse;
    final newSchemesCount = data.newSchemesCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: 'My Savings', value: '₹${NumberFormat('#,##,##0', 'en_IN').format(report.totalSavings)}', tone: StatTone.brand, trend: '${report.savingsEntryCount} entries', icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'Outstanding Loan', value: '₹${NumberFormat('#,##,##0', 'en_IN').format(report.totalOutstanding)}', tone: StatTone.gold, trend: myLoan?.nextDueDate != null ? 'Next EMI ${DateFormat('dd MMM').format(myLoan!.nextDueDate!)}' : 'No dues', icon: Icons.account_balance_rounded)),
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
                IconTile(
                  onTap: () => context.go(Paths.schemes),
                  icon: Icons.description_rounded,
                  label: 'Schemes',
                  tone: TileTone.violet,
                  badge: newSchemesCount > 0 ? '$newSchemesCount' : null,
                  badgeSemanticLabel: newSchemesCount > 0 ? 'Schemes, $newSchemesCount new' : null,
                ),
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
                      Text('${report.attendancePct.round()}%', style: AppTheme.sans(14, weight: FontWeight.w700)),
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
                    Text('₹${NumberFormat('#,##,##0', 'en_IN').format(report.totalSavings)}', style: AppTheme.display(22)),
                    Text(report.period, style: AppTheme.sans(11, color: Neutral.c500)),
                  ]),
                ]),
                const SizedBox(height: 12),
                SizedBox(height: 64, child: _SavingsTrendChart(trend: data.savingsTrend)),
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
                    Text('₹${NumberFormat('#,##,##0', 'en_IN').format(myLoan.outstanding)}', style: AppTheme.display(18)),
                    Flexible(child: Text('of ₹${NumberFormat('#,##,##0', 'en_IN').format(myLoan.amount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500))),
                  ]),
                  const SizedBox(height: 8),
                  AppProgressBar(value: myLoan.amount - myLoan.outstanding, max: myLoan.amount, tone: ProgressTone.gold),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: AppBadge(text: myLoan.nextDueDate != null ? 'EMI ₹${NumberFormat('#,##,##0', 'en_IN').format(myLoan.emi)} due ${DateFormat('dd MMM').format(myLoan.nextDueDate!)}' : 'EMI ₹${NumberFormat('#,##,##0', 'en_IN').format(myLoan.emi)}', tone: BadgeTone.warning, dot: true)),
                    const SizedBox(width: 8),
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
                    Row(children: [Icon(Icons.event_note_rounded, size: 14, color: Brand.c600), const SizedBox(width: 6), Flexible(child: Text('MEETING ALERT', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(10, weight: FontWeight.w700, color: Brand.c600)))]),
                    const SizedBox(height: 8),
                    Text(DateFormat('dd MMM yyyy').format(upcomingMeeting.date), style: AppTheme.sans(14, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(upcomingMeeting.agenda ?? 'Meeting', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
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
                    Row(children: [Icon(Icons.school_rounded, size: 14, color: Gold.c600), const SizedBox(width: 6), Flexible(child: Text('TRAINING ALERT', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(10, weight: FontWeight.w700, color: Gold.c600)))]),
                    const SizedBox(height: 8),
                    Text(inProgressCourse.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    AppProgressBar(value: data.inProgressCoursePct, tone: ProgressTone.gold),
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
                Text('Ask about savings, loans & budgeting', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
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
              child: data.announcements.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text('No announcements yet', style: AppTheme.sans(12, color: Neutral.c400)))
                  : Column(
                      children: data.announcements.map((a) {
                        return Semantics(
                          label: [
                            if (!a.read) 'Unread',
                            a.title,
                            DateFormat('dd MMM yyyy').format(a.createdAt),
                          ].join(', '),
                          button: true,
                          onTap: () => context.go(Paths.announcementDetail(a.id)),
                          child: ExcludeSemantics(
                            child: InkWell(
                              onTap: () => context.go(Paths.announcementDetail(a.id)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (!a.read) Padding(padding: const EdgeInsets.only(top: 5, right: 8), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Brand.c500, shape: BoxShape.circle))),
                                  if (a.read) const SizedBox(width: 14),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c800)),
                                    Text(DateFormat('dd MMM yyyy').format(a.createdAt), style: AppTheme.sans(10, color: Neutral.c400)),
                                  ])),
                                ]),
                              ),
                            ),
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
  final List<MonthlyTotal> trend;
  const _SavingsTrendChart({required this.trend});

  String get _semanticLabel {
    final parts = trend.map((t) => '${t.label} ${t.total.toStringAsFixed(0)}').join(', ');
    return 'Savings trend chart: $parts';
  }

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) return const SizedBox();
    return Semantics(
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: [for (var i = 0; i < trend.length; i++) FlSpot(i.toDouble(), trend[i].total.toDouble())],
                isCurved: true,
                color: Brand.c600,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: Brand.c500.withValues(alpha: 0.18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
