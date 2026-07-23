import '../l10n/gen/app_localizations.dart';

/// The scheme catalog's structured, machine-evaluable eligibility rules —
/// see `supabase/migrations/0040_scheme_eligibility_criteria.sql`. This
/// replaces the old approach (fuzzy keyword-matching a member's free-text
/// yes/no answers against `Scheme.eligibility`'s prose) with real typed
/// fields the app can actually evaluate against a member's real data.
///
/// Deliberately limited to what this app's own data model genuinely has
/// (`ShgProfile.formationDate`/`.grade`, `Profile.shgId`) — this app has no
/// income, gender, caste/category, age, or occupation field anywhere on
/// `Profile`, so no criterion here claims to check any of those; adding one
/// would silently always pass/fail since there's no real value behind it.
/// A scheme's free-text `eligibility` list still exists (shown on
/// `SchemeDetailPage`) for requirements that genuinely need manual/
/// documentary verification (BPL status, prior subsidy history, gender/
/// caste category, project cost, ...) and are not evaluated here.
class EligibilityCriteria {
  /// Member must currently be linked to an SHG (`Profile.shgId != null`).
  final bool requiresShgMembership;

  /// Member's SHG must have been formed at least this many months ago
  /// (`ShgProfile.formationDate`). Null = no minimum.
  final int? minShgAgeMonths;

  /// Member's SHG grade must be at least this good, using this app's own
  /// grade vocabulary/ordering (best→worst: A+, A, B+, B, C — the same set
  /// `analytics_shg_list_page.dart`/`crp_dashboard.dart` already render
  /// badges for). Null = no minimum.
  final String? minShgGrade;

  const EligibilityCriteria({
    this.requiresShgMembership = false,
    this.minShgAgeMonths,
    this.minShgGrade,
  });

  /// True when this scheme has no structured criteria set at all (only its
  /// free-text `eligibility` list, if any) — e.g. an older catalog row from
  /// before this feature, or a scheme whose real-world eligibility is
  /// entirely outside what this app can verify automatically.
  bool get isEmpty => !requiresShgMembership && minShgAgeMonths == null && minShgGrade == null;

  factory EligibilityCriteria.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EligibilityCriteria();
    return EligibilityCriteria(
      requiresShgMembership: map['requires_shg_membership'] as bool? ?? false,
      minShgAgeMonths: (map['min_shg_age_months'] as num?)?.toInt(),
      minShgGrade: map['min_shg_grade'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'requires_shg_membership': requiresShgMembership,
        'min_shg_age_months': minShgAgeMonths,
        'min_shg_grade': minShgGrade,
      };
}

/// Mirrors a row in `public.schemes`.
class Scheme {
  final String id;
  final String name;
  final String? fullName;
  final String? agency;
  final String? benefit;
  final List<String> eligibility;
  final EligibilityCriteria criteria;
  final DateTime? deadline;

  const Scheme({
    required this.id,
    required this.name,
    this.fullName,
    this.agency,
    this.benefit,
    this.eligibility = const [],
    this.criteria = const EligibilityCriteria(),
    this.deadline,
  });

  factory Scheme.fromMap(Map<String, dynamic> map) => Scheme(
        id: map['id'] as String,
        name: map['name'] as String,
        fullName: map['full_name'] as String?,
        agency: map['agency'] as String?,
        benefit: map['benefit'] as String?,
        eligibility: (map['eligibility'] as List?)?.map((e) => e as String).toList() ?? const [],
        criteria: EligibilityCriteria.fromMap(map['eligibility_criteria'] as Map<String, dynamic>?),
        deadline: map['deadline'] != null ? DateTime.parse(map['deadline'] as String) : null,
      );
}

/// One line of a [SchemeEligibilityResult] — one structured criterion the
/// scheme declares, evaluated against a specific member, worded so it can be
/// shown to the member directly (e.g. "Requires SHG membership — you are not
/// linked to an SHG").
class EligibilityCheck {
  final String label;
  final bool met;
  const EligibilityCheck({required this.label, required this.met});
}

/// The itemized result of evaluating one scheme's [EligibilityCriteria]
/// against one member. [checks] only ever contains entries for criteria the
/// scheme actually declares — a scheme with no structured criteria
/// ([EligibilityCriteria.isEmpty]) yields an empty list here, not a false
/// "fully eligible" claim about requirements this app never checked.
class SchemeEligibilityResult {
  final bool isEligible;
  final List<EligibilityCheck> checks;
  const SchemeEligibilityResult({required this.isEligible, required this.checks});
}

// Best → worst, this app's own grade vocabulary (see doc comment on
// `EligibilityCriteria.minShgGrade` above).
const _gradeOrder = ['A+', 'A', 'B+', 'B', 'C'];

/// Evaluates [scheme]'s structured criteria against caller-resolved facts
/// about one member — this function does no fetching of its own (mirrors
/// this app's repository convention of taking caller-resolved ids rather
/// than re-fetching), so it's a pure, independently testable function.
///
/// [hasShgMembership]/[shgAgeMonths]/[shgGrade] describe the member's own
/// SHG (or lack of one) at the time of evaluation. An unrecognized or
/// missing value for a criterion the scheme actually declares is treated as
/// "not met" (fail-safe) rather than silently skipped — e.g. a criterion
/// requiring a minimum SHG grade can't be confirmed met for an ungraded SHG.
SchemeEligibilityResult evaluateSchemeEligibility(
  Scheme scheme, {
  required AppLocalizations l10n,
  required bool hasShgMembership,
  int? shgAgeMonths,
  String? shgGrade,
}) {
  final criteria = scheme.criteria;
  final checks = <EligibilityCheck>[];

  if (criteria.requiresShgMembership) {
    checks.add(EligibilityCheck(
      label: hasShgMembership ? l10n.schemeEligibilityShgMembershipMet : l10n.schemeEligibilityShgMembershipUnmet,
      met: hasShgMembership,
    ));
  }

  if (criteria.minShgAgeMonths != null) {
    final required = criteria.minShgAgeMonths!;
    final met = hasShgMembership && shgAgeMonths != null && shgAgeMonths >= required;
    final String label;
    if (met) {
      label = l10n.schemeEligibilityAgeMet(shgAgeMonths, required);
    } else if (!hasShgMembership) {
      label = l10n.schemeEligibilityAgeUnmetNoShg(required);
    } else if (shgAgeMonths == null) {
      label = l10n.schemeEligibilityAgeUnmetNoRecord(required);
    } else {
      label = l10n.schemeEligibilityAgeUnmet(required, shgAgeMonths);
    }
    checks.add(EligibilityCheck(label: label, met: met));
  }

  if (criteria.minShgGrade != null) {
    final required = criteria.minShgGrade!;
    final requiredIdx = _gradeOrder.indexOf(required);
    final actualIdx = shgGrade == null ? -1 : _gradeOrder.indexOf(shgGrade);
    final met = hasShgMembership && requiredIdx != -1 && actualIdx != -1 && actualIdx <= requiredIdx;
    final String label;
    if (met) {
      label = l10n.schemeEligibilityGradeMet(shgGrade!, required);
    } else if (!hasShgMembership) {
      label = l10n.schemeEligibilityGradeUnmetNoShg(required);
    } else if (shgGrade == null) {
      label = l10n.schemeEligibilityGradeUnmetNoRecord(required);
    } else {
      label = l10n.schemeEligibilityGradeUnmet(required, shgGrade);
    }
    checks.add(EligibilityCheck(label: label, met: met));
  }

  return SchemeEligibilityResult(isEligible: checks.every((c) => c.met), checks: checks);
}

/// Mirrors a row in `public.scheme_applications`.
class SchemeApplication {
  final String id;
  final String schemeId;
  final String status; // applied | under_review | approved | rejected
  final DateTime appliedOn;

  const SchemeApplication({required this.id, required this.schemeId, required this.status, required this.appliedOn});

  factory SchemeApplication.fromMap(Map<String, dynamic> map) => SchemeApplication(
        id: map['id'] as String,
        schemeId: map['scheme_id'] as String,
        status: map['status'] as String,
        appliedOn: DateTime.parse(map['applied_on'] as String),
      );
}

/// A `scheme_applications` row joined with the scheme's and applicant's
/// names, for the staff review queue (`SchemeRepository.fetchPendingApplications`).
class SchemeApplicationReview {
  final String applicationId;
  final String schemeId;
  final String schemeName;
  final String memberName;
  final String status;
  final DateTime appliedOn;

  const SchemeApplicationReview({
    required this.applicationId,
    required this.schemeId,
    required this.schemeName,
    required this.memberName,
    required this.status,
    required this.appliedOn,
  });

  factory SchemeApplicationReview.fromMap(Map<String, dynamic> map) => SchemeApplicationReview(
        applicationId: map['id'] as String,
        schemeId: map['scheme_id'] as String,
        schemeName: (map['schemes'] as Map<String, dynamic>?)?['name'] as String? ?? 'Scheme',
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Member',
        status: map['status'] as String,
        appliedOn: DateTime.parse(map['applied_on'] as String),
      );
}
