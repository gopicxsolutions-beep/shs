import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../repositories/scheme_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// A real structured eligibility rules engine: each scheme's
/// [EligibilityCriteria] (see `lib/models/scheme.dart`) is evaluated against
/// this member's actual SHG-membership/registration-age/grade data, and the
/// itemized per-criterion result (✓/✗ with a plain-language reason) is shown
/// directly — replacing the previous version's free-text keyword-matching
/// heuristic (fuzzy-matching yes/no toggle answers against substrings of
/// each scheme's `eligibility` prose).
///
/// This is still NOT a connection to any real government eligibility API —
/// no such API exists or is reachable from this project. It's a genuine
/// rules engine over this app's own stored data (SHG membership/age/grade),
/// and it only evaluates the criteria a scheme actually declares — a
/// scheme's other free-text requirements (BPL status, prior-subsidy
/// history, age, gender/caste category, ...) still need the manual/
/// documentary verification described in that scheme's own eligibility list
/// on `SchemeDetailPage`, since this app has no stored data for any of them.
class SchemeEligibilityPage extends StatefulWidget {
  const SchemeEligibilityPage({super.key});
  @override
  State<SchemeEligibilityPage> createState() => _SchemeEligibilityPageState();
}

/// Everything the evaluator needs about the member, resolved once up front
/// (mirrors this app's "read methods take caller-resolved ids" repository
/// convention — `evaluateSchemeEligibility` itself does no fetching).
class _MemberEligibilityContext {
  final List<Scheme> schemes;
  final bool hasShgMembership;
  final int? shgAgeMonths;
  final String? shgGrade;
  const _MemberEligibilityContext({
    required this.schemes,
    required this.hasShgMembership,
    this.shgAgeMonths,
    this.shgGrade,
  });
}

class _SchemeEligibilityPageState extends State<SchemeEligibilityPage> {
  final _schemeRepo = SchemeRepository();
  final _shgRepo = ShgRepository();

  int? _monthsSince(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    var months = (now.year - date.year) * 12 + (now.month - date.month);
    if (now.day < date.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  Future<_MemberEligibilityContext> _load(String? shgId) async {
    final schemes = await _schemeRepo.fetchSchemes();
    // Demo mode's single persona is always a fully onboarded SHG member —
    // `AppState.user.shgName` is unconditionally populated regardless of
    // which role is being previewed, and `ShgRepository.fetchShg`'s own
    // demo-mode branch already ignores whatever id it's passed and always
    // returns the one mock SHG. Live mode instead reflects whether the
    // signed-in member's profile is genuinely linked to an SHG.
    final hasShg = SupabaseService.isConfigured ? shgId != null : true;
    final shg = hasShg ? await _shgRepo.fetchShg(shgId) : null;
    return _MemberEligibilityContext(
      schemes: schemes,
      hasShgMembership: hasShg,
      shgAgeMonths: _monthsSince(shg?.formationDate),
      shgGrade: shg?.grade,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shgId = context.watch<AppState>().profile?.shgId;
    return Scaffold(
      appBar: PageHeader(title: l10n.schemeEligibilityTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.schemeEligibilityIntro,
            style: AppTheme.sans(12, color: Neutral.c500),
          ),
          const SizedBox(height: 16),
          AppAsyncBuilder<_MemberEligibilityContext>(
            future: () => _load(shgId),
            builder: (context, ctx) {
              if (ctx.schemes.isEmpty) {
                return AppEmptyState(icon: Icons.info_outline_rounded, message: l10n.schemeEligibilityEmptyCatalog);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ctx.schemes.map((s) {
                  final result = evaluateSchemeEligibility(
                    s,
                    l10n: l10n,
                    hasShgMembership: ctx.hasShgMembership,
                    shgAgeMonths: ctx.shgAgeMonths,
                    shgGrade: ctx.shgGrade,
                  );
                  final hasCriteria = result.checks.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      onTap: () => context.go(Paths.schemeDetail(s.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: AppTheme.sans(13, weight: FontWeight.w700)),
                                    Text(s.benefit ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: AppBadge(
                                  text: !hasCriteria ? l10n.schemeEligibilitySeeFullDetails : (result.isEligible ? l10n.schemeEligibilityEligible : l10n.schemeEligibilityNotEligible),
                                  tone: !hasCriteria ? BadgeTone.neutral : (result.isEligible ? BadgeTone.success : BadgeTone.danger),
                                ),
                              ),
                            ],
                          ),
                          if (hasCriteria) ...[
                            const SizedBox(height: 10),
                            ...result.checks.map((c) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(c.met ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: c.met ? Brand.c500 : Accent.red500),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(c.label, style: AppTheme.sans(12))),
                                    ],
                                  ),
                                )),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              l10n.schemeEligibilityNoCriteria,
                              style: AppTheme.sans(11, color: Neutral.c500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
