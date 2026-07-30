import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/loan.dart';
import '../../models/meeting.dart';
import '../../models/report.dart';
import '../../models/shg.dart';
import '../../models/shg_join_request.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/meeting_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/shg_join_request_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
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
  final List<ShgJoinRequest> pendingJoinRequests;
  const _LeaderDashboardData({
    required this.report,
    required this.shg,
    required this.pendingLoans,
    required this.overdueLoans,
    required this.upcomingMeeting,
    required this.pendingJoinRequests,
  });
}

class LeaderDashboard extends StatelessWidget {
  const LeaderDashboard({super.key});

  Future<_LeaderDashboardData> _load(BuildContext context) async {
    final profile = context.read<AppState>().profile;
    final shgId = profile?.shgId;
    final memberId = profile?.id;
    final results = await Future.wait([
      ReportRepository().fetchShgReport(shgId),
      ShgRepository().fetchShg(shgId),
      LoanRepository().fetchForShg(shgId),
      MeetingRepository().fetchForShg(shgId),
      // New members waiting to join must be easy to spot and act on from
      // the dashboard itself, not just discoverable by happening to open
      // Members and notice the person-add icon — see this section's own
      // render code below for the "Pending Join Requests" card this backs.
      ShgJoinRequestRepository().fetchPendingForShg(shgId),
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
      // `loans_update_leader_or_staff` (RLS) blocks a leader from
      // approving/rejecting her own loan (no identity may escalate itself)
      // — see loan_approval_page.dart's and loans_home_page.dart's matching
      // `l.memberId != memberId` filters. Without the same exclusion here,
      // a self-applied loan showed on this dashboard as an actionable
      // "Pending Approval" (badge, preview card, member name and amount all
      // included), but tapping through to the real Approvals page — which
      // already excludes it — landed on an empty list with no explanation.
      pendingLoans: loans.where((l) => l.status == 'pending' && l.memberId != memberId).toList(),
      overdueLoans: loans.where((l) => l.status == 'overdue').toList(),
      upcomingMeeting: upcoming.isEmpty ? null : upcoming.first,
      pendingJoinRequests: results[4] as List<ShgJoinRequest>,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A leader account with no `shgId` (an already-broken pre-redesign
    // account, or a direct-REST edge case — see AppState.completeProfile
    // Setup's and router.dart's doc comments) used to render this entire
    // dashboard as if she genuinely led an empty, brand-new SHG (all-zero
    // stats, "no pending loans"), with no indication anything was wrong.
    // Same pattern as meeting_schedule_page.dart's `shgId == null` guard.
    final shgId = context.watch<AppState>().profile?.shgId;
    if (SupabaseService.isConfigured && shgId == null) {
      final l10n = AppLocalizations.of(context)!;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: AppEmptyState(icon: Icons.groups_rounded, message: l10n.commonLeaderNoShgMessage),
      );
    }
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
    final l10n = AppLocalizations.of(context)!;
    final report = data.report;
    final pendingLoans = data.pendingLoans;
    final overdueLoans = data.overdueLoans;
    final upcomingMeeting = data.upcomingMeeting;
    // A loan-COUNT ratio over this SHG's active+overdue loans only — NOT
    // the same figure as the platform "Recovery Rate" tile elsewhere
    // (AnalyticsRepository.fetchPlatformKpis/federation_recovery_page.dart),
    // which is amount-weighted (repaid/disbursed) over active+overdue+
    // closed loans. The two used to share the "Recovery" label despite
    // measuring genuinely different things — a SHG with 9 small on-time
    // loans and 1 large overdue one could show ~90% here while its true
    // amount-weighted recovery is far lower, with no per-SHG amount-based
    // figure to reconcile against. Labeled "On-time Loans" instead of
    // computing the amount-weighted formula here, since that would need
    // this SHG's total disbursed amount (not currently in ShgReportData)
    // plumbed through just for this one tile.
    final recoveryPct = report.activeLoanCount > 0 ? ((1 - (overdueLoans.length / report.activeLoanCount)) * 100).round() : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: StatCard(label: l10n.leaderDashboardGroupSavingsLabel, value: '₹${(report.totalSavings / 100000).toStringAsFixed(1)}L', tone: StatTone.brand, trend: l10n.leaderDashboardMembersTrend(report.memberCount), icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: l10n.leaderDashboardLoansOutstandingLabel, value: '₹${(report.totalOutstanding / 100000).toStringAsFixed(1)}L', tone: StatTone.gold, trend: l10n.leaderDashboardOverdueTrend(overdueLoans.length), icon: Icons.account_balance_rounded)),
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
                IconTile(
                  onTap: () => context.go(Paths.shgMembers),
                  icon: Icons.groups_rounded,
                  label: l10n.leaderDashboardMembersTile,
                  tone: TileTone.brand,
                  badge: data.pendingJoinRequests.isNotEmpty ? '${data.pendingJoinRequests.length}' : null,
                  badgeSemanticLabel: data.pendingJoinRequests.isNotEmpty ? l10n.leaderDashboardJoinRequestsTitle : null,
                ),
                IconTile(
                  onTap: () => context.go(Paths.loanApproval),
                  icon: Icons.fact_check_rounded,
                  label: l10n.leaderDashboardApprovalsTile,
                  tone: TileTone.gold,
                  badge: pendingLoans.isNotEmpty ? '${pendingLoans.length}' : null,
                  badgeSemanticLabel: pendingLoans.isNotEmpty ? l10n.leaderDashboardApprovalsPendingBadge(pendingLoans.length) : null,
                ),
                IconTile(onTap: () => context.go(Paths.meetingSchedule), icon: Icons.event_rounded, label: l10n.leaderDashboardScheduleTile, tone: TileTone.sky),
                IconTile(onTap: () => context.go(Paths.reportsShg), icon: Icons.bar_chart_rounded, label: l10n.leaderDashboardReportsTile, tone: TileTone.violet),
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
                  Text(l10n.leaderDashboardDefaulterAlert(overdueLoans.length), style: AppTheme.sans(14, weight: FontWeight.w700, color: Accent.red700)),
                  Text(
                    overdueLoans.first.nextDueDate != null
                        ? l10n.leaderDashboardEmiOverdueSinceDate(overdueLoans.first.memberName, DateFormat('dd MMM').format(overdueLoans.first.nextDueDate!))
                        : l10n.leaderDashboardEmiOverdue(overdueLoans.first.memberName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(12, color: Accent.red500),
                  ),
                ])),
                // Paths.loanTracking always shows the signed-in user's own
                // loans, not the SHG's — for a leader tapping "View" here
                // that was showing their own unrelated loan instead of the
                // actual defaulting member's. Route to that loan directly.
                Flexible(
                  child: InkWell(
                    onTap: () => context.go(Paths.loanDetail(overdueLoans.first.id)),
                    child: Text(l10n.leaderDashboardViewAction, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Accent.red600)),
                  ),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.leaderDashboardPendingApprovalsTitle, action: l10n.leaderDashboardReviewAllAction, onAction: () => context.go(Paths.loanApproval)),
            AppCard(
              padded: false,
              child: pendingLoans.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(l10n.leaderDashboardNoPendingLoans, style: AppTheme.sans(12, color: Neutral.c400)))
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.leaderDashboardJoinRequestsTitle, action: l10n.leaderDashboardReviewAllAction, onAction: () => context.go(Paths.shgJoinRequests)),
            AppCard(
              padded: false,
              child: data.pendingJoinRequests.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(l10n.leaderDashboardNoPendingJoinRequests, style: AppTheme.sans(12, color: Neutral.c400)))
                  : Column(
                      children: data.pendingJoinRequests.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(children: [
                              AppAvatar(name: r.memberName ?? l10n.shgJoinRequestsMemberFallback, size: 32),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r.memberName ?? l10n.shgJoinRequestsMemberFallback, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700)),
                                Text(l10n.shgJoinRequestsRequestedOn(DateFormat('dd MMM yyyy').format(r.requestedAt)), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c400)),
                              ])),
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
              SectionHeader(title: l10n.leaderDashboardNextMeetingTitle, action: l10n.leaderDashboardManageAction, onAction: () => context.go(Paths.meetings)),
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
                    Text(upcomingMeeting.agenda ?? l10n.leaderDashboardMeetingFallback, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700)),
                    Text('${upcomingMeeting.time ?? ''} · ${upcomingMeeting.venue ?? ''}', style: AppTheme.sans(11, color: Neutral.c500)),
                  ])),
                ]),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: l10n.leaderDashboardShgHealthTitle),
            Row(children: [
              Expanded(child: _healthTile(data.shg?.grade ?? '—', l10n.leaderDashboardGradingLabel)),
              const SizedBox(width: 12),
              Expanded(child: _healthTile('${report.avgAttendancePct.round()}%', l10n.leaderDashboardAttendanceLabel)),
              const SizedBox(width: 12),
              Expanded(child: _healthTile('$recoveryPct%', l10n.leaderDashboardRecoveryLabel)),
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
