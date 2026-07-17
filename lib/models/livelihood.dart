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

  const LivelihoodActivity({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.activityType,
    this.description,
    required this.investment,
    required this.revenue,
    required this.status,
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
      );
}
