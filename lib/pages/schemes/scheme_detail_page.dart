import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../models/types.dart';
import '../../repositories/scheme_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_header.dart';

class SchemeDetailPage extends StatefulWidget {
  final String schemeId;
  const SchemeDetailPage({super.key, required this.schemeId});
  @override
  State<SchemeDetailPage> createState() => _SchemeDetailPageState();
}

class _SchemeDetailPageState extends State<SchemeDetailPage> {
  final _repo = SchemeRepository();
  final GlobalKey<AppAsyncBuilderState<SchemeApplication?>> _appKey = GlobalKey();
  bool _applying = false;

  Future<void> _apply(String? memberId) async {
    setState(() => _applying = true);
    try {
      await _repo.apply(schemeId: widget.schemeId, memberId: memberId);
      _appKey.currentState?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? 'Application submitted' : 'Demo mode — not saved (connect Supabase to persist)')),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit this application. Please try again.')));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;
    // Scheme applications are a personal, self-service action (mirrors
    // `scheme_applications_insert_self`'s RLS, which only ever allows
    // `member_id = auth.uid()`) — staff/leader/CRP/CLF review applications
    // via the separate "Applications" tile instead of applying themselves.
    // Demo mode's `AppState.profile` stays permanently null regardless of
    // which role is being previewed (it's only ever assigned in live-mode
    // branches), so without this gate a non-member "Preview as" persona
    // could tap "Apply Now" and `SchemeRepository.apply()`'s demo-mode
    // branch would report a fake success — the same leaked-application
    // shape already fixed for loan applications (see `loans_home_page.dart`
    // hiding its own "Apply" affordance for `isLeaderOrStaff`).
    final isLeaderOrStaff = appState.user.role != Role.member;

    return Scaffold(
      appBar: const PageHeader(title: 'Scheme Detail'),
      body: AppAsyncBuilder<Scheme?>(
        future: () => _repo.fetchSchemeById(widget.schemeId),
        builder: (context, scheme) {
          if (scheme == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This scheme could not be found');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scheme.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (scheme.fullName != null) Text(scheme.fullName!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 8),
                    if (scheme.agency != null) Text(scheme.agency!, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    if (scheme.deadline != null) ...[
                      const SizedBox(height: 8),
                      Text('Deadline: ${DateFormat('dd MMM yyyy').format(scheme.deadline!)}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (scheme.benefit != null) ...[
                const SectionHeader(title: 'Benefit'),
                AppCard(child: Text(scheme.benefit!, style: AppTheme.sans(13))),
                const SizedBox(height: 20),
              ],
              const SectionHeader(title: 'Eligibility'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: scheme.eligibility.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: Brand.c500),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e, style: AppTheme.sans(12))),
                        ]),
                      )).toList(),
                ),
              ),
              if (!isLeaderOrStaff) ...[
                const SizedBox(height: 20),
                AppAsyncBuilder<SchemeApplication?>(
                  key: _appKey,
                  future: () async {
                    final apps = await _repo.fetchMyApplications(memberId);
                    return apps[widget.schemeId];
                  },
                  builder: (context, app) {
                    if (app != null) {
                      // `app.status` (applied/under_review/approved/rejected)
                      // is unbounded/dynamic — combined with the fixed label
                      // at a scaled-up accessibility text size it can
                      // overflow the card's row, since neither side
                      // otherwise has flex. Same pattern as the EMI-due
                      // badge fix in loan_tracking_page.dart.
                      return AppCard(child: Row(children: [
                        Text('Application status: ', style: AppTheme.sans(13)),
                        Flexible(child: AppBadge(text: app.status, tone: BadgeTone.brand)),
                      ]));
                    }
                    // `scheme.deadline` was, until now, purely decorative —
                    // shown in the header card but never checked before
                    // letting a member submit. A member could apply to a
                    // scheme whose deadline had already passed with zero
                    // indication anything was wrong (the RPC/insert would
                    // still silently succeed server-side too, see
                    // `scheme_applications_insert_self` in
                    // supabase/migrations/0030_scheme_application_deadline_enforcement.sql).
                    // Compare on the calendar date only (not the exact
                    // instant) since `deadline` is a DATE column — the whole
                    // day it falls on should still count as open.
                    final today = DateTime.now();
                    final todayDate = DateTime(today.year, today.month, today.day);
                    final deadlinePassed = scheme.deadline != null && todayDate.isAfter(scheme.deadline!);
                    if (deadlinePassed) {
                      return AppCard(child: Row(children: [
                        Icon(Icons.event_busy_rounded, size: 18, color: Neutral.c400),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Applications closed — the deadline for this scheme has passed.', style: AppTheme.sans(12, color: Neutral.c500))),
                      ]));
                    }
                    return AppButton(
                      label: _applying ? 'Submitting…' : 'Apply Now',
                      fullWidth: true,
                      size: ButtonSize.lg,
                      onPressed: _applying ? null : () => _apply(memberId),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
