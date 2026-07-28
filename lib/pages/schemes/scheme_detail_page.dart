import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../models/types.dart';
import '../../repositories/scheme_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_header.dart';

String _schemeStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'applied' => l10n.schemeStatusApplied,
      'under_review' => l10n.schemeStatusUnderReview,
      'approved' => l10n.schemeStatusApproved,
      'rejected' => l10n.schemeStatusRejected,
      _ => status,
    };

class _SchemeWithEligibility {
  final Scheme? scheme;
  // Null when the scheme has no structured criteria at all
  // (SchemeEligibilityResult.checks would be empty) — same "nothing to
  // proactively check" case SchemeEligibilityPage already treats as
  // `!hasCriteria` (falls back to "see full details", not a false "eligible"
  // claim).
  final SchemeEligibilityResult? eligibility;
  const _SchemeWithEligibility(this.scheme, this.eligibility);
}

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

  // Mirrors SchemeEligibilityPage's identical helper — kept as a separate
  // copy per this codebase's established per-file-duplicated-helper
  // convention (see e.g. _loanStatusLabel across loans/*.dart) rather than a
  // shared import for one small pure function.
  int? _monthsSince(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    var months = (now.year - date.year) * 12 + (now.month - date.month);
    if (now.day < date.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  /// Real, proactive eligibility check — was previously purely reactive:
  /// a member below a scheme's minimum grade/age could tap "Apply Now" and
  /// only find out via the RLS rejection's generic, actively-wrong-advice
  /// error ("Please try again" when retrying fails identically), with no
  /// way to learn WHICH criterion she failed short of separately opening
  /// the standalone Eligibility Checker. Reuses that exact same evaluator
  /// (`evaluateSchemeEligibility`, `lib/models/scheme.dart`) against the
  /// same member-context shape `SchemeEligibilityPage` already resolves, so
  /// the two screens can never disagree about the same scheme/member pair.
  Future<_SchemeWithEligibility> _load(String? shgId, AppLocalizations l10n) async {
    final scheme = await _repo.fetchSchemeById(widget.schemeId);
    if (scheme == null) return const _SchemeWithEligibility(null, null);
    final hasShg = SupabaseService.isConfigured ? shgId != null : true;
    final shg = hasShg ? await ShgRepository().fetchShg(shgId) : null;
    final result = evaluateSchemeEligibility(
      scheme,
      l10n: l10n,
      hasShgMembership: hasShg,
      shgAgeMonths: _monthsSince(shg?.formationDate),
      shgGrade: shg?.grade,
    );
    return _SchemeWithEligibility(scheme, result.checks.isEmpty ? null : result);
  }

  Future<void> _apply(String? memberId) async {
    setState(() => _applying = true);
    try {
      await _repo.apply(schemeId: widget.schemeId, memberId: memberId);
      _appKey.currentState?.reload();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? l10n.schemeDetailApplicationSubmitted : l10n.profileUpdateDemoMode)),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.schemeDetailApplyError)));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
      appBar: PageHeader(title: l10n.schemeDetailTitle),
      body: AppAsyncBuilder<_SchemeWithEligibility>(
        future: () => _load(appState.profile?.shgId, l10n),
        builder: (context, data) {
          final scheme = data.scheme;
          final eligibility = data.eligibility;
          if (scheme == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.schemeDetailNotFound);
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
                      Text(l10n.schemeDetailDeadlineLabel(DateFormat('dd MMM yyyy').format(scheme.deadline!)), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (scheme.benefit != null) ...[
                SectionHeader(title: l10n.schemeDetailBenefitSection),
                AppCard(child: Text(scheme.benefit!, style: AppTheme.sans(13))),
                const SizedBox(height: 20),
              ],
              SectionHeader(title: l10n.schemeDetailEligibilitySection),
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
                        Text(l10n.schemeDetailApplicationStatusLabel, style: AppTheme.sans(13)),
                        Flexible(child: AppBadge(text: _schemeStatusLabel(l10n, app.status), tone: BadgeTone.brand)),
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
                        Expanded(child: Text(l10n.schemeDetailDeadlinePassed, style: AppTheme.sans(12, color: Neutral.c500))),
                      ]));
                    }
                    if (eligibility != null && !eligibility.isEligible) {
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Icon(Icons.block_rounded, size: 18, color: Accent.red500),
                              const SizedBox(width: 10),
                              Expanded(child: Text(l10n.schemeDetailIneligibleMessage, style: AppTheme.sans(12, color: Neutral.c500))),
                            ]),
                            const SizedBox(height: 10),
                            ...eligibility.checks.where((c) => !c.met).map((c) => Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 28),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Icon(Icons.cancel_rounded, size: 14, color: Accent.red500),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(c.label, style: AppTheme.sans(11, color: Neutral.c500))),
                                  ]),
                                )),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => context.go(Paths.schemeEligibility),
                              child: Text(l10n.schemeDetailViewEligibilityLink, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                            ),
                          ],
                        ),
                      );
                    }
                    return AppButton(
                      label: _applying ? l10n.schemeDetailSubmitting : l10n.schemeDetailApplyNow,
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
