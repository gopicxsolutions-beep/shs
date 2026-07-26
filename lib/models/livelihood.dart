import '../l10n/gen/app_localizations.dart';
import '../widgets/app_badge.dart';

/// Status badge tone for `livelihood_activities.status`, shared so the home
/// list and the activity detail page can't silently diverge on how a given
/// status is colored — the detail page used to hardcode `BadgeTone.neutral`
/// regardless of status while the home list correctly varied it.
const livelihoodStatusTones = <String, BadgeTone>{
  'planned': BadgeTone.neutral,
  'active': BadgeTone.brand,
  'completed': BadgeTone.success,
};

/// Canonical `activity_type` values stored on `public.livelihood_activities`
/// — used both by `LivelihoodEntryPage`'s type picker and by every page that
/// displays an already-saved activity, so a translated label is never
/// computed in only one place and silently skipped in the others (the raw
/// English key was previously shown as-is on the home/detail list views even
/// in a Hindi/Telugu session, since only the entry page's picker translated
/// it).
const livelihoodActivityTypes = ['Dairy', 'Tailoring', 'Retail', 'Poultry', 'Agriculture', 'Handicrafts', 'Other'];

String livelihoodActivityTypeLabel(String type, AppLocalizations l10n) => {
      'Dairy': l10n.livelihoodEntryTypeDairy,
      'Tailoring': l10n.livelihoodEntryTypeTailoring,
      'Retail': l10n.livelihoodEntryTypeRetail,
      'Poultry': l10n.livelihoodEntryTypePoultry,
      'Agriculture': l10n.livelihoodEntryTypeAgriculture,
      'Handicrafts': l10n.livelihoodEntryTypeHandicrafts,
      'Other': l10n.livelihoodEntryTypeOther,
    }[type] ??
    type;

/// Mirrors a row in `public.livelihood_activities` (joined with member name).
class LivelihoodActivity {
  final String id;
  final String memberId;
  final String memberName;
  final String activityType;
  final String? description;
  final num investment;
  final num revenue;
  final String status; // planned | active | completed
  // Only populated when the query joins `shgs(name)` (today: only
  // LivelihoodRepository.fetchAllForStaff()'s platform-wide fetch) — null
  // everywhere else, including demo mode. Mirrors Loan.shgName.
  final String? shgName;

  const LivelihoodActivity({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.activityType,
    this.description,
    required this.investment,
    required this.revenue,
    required this.status,
    this.shgName,
  });

  num get profit => revenue - investment;

  factory LivelihoodActivity.fromMap(Map<String, dynamic> map) => LivelihoodActivity(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Member',
        activityType: map['activity_type'] as String,
        description: map['description'] as String?,
        investment: map['investment'] as num? ?? 0,
        revenue: map['revenue'] as num? ?? 0,
        status: map['status'] as String,
        shgName: (map['shgs'] as Map<String, dynamic>?)?['name'] as String?,
      );
}
