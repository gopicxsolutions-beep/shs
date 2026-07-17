/// Mirrors a row in `public.schemes`.
class Scheme {
  final String id;
  final String name;
  final String? fullName;
  final String? agency;
  final String? benefit;
  final List<String> eligibility;
  final DateTime? deadline;

  const Scheme({
    required this.id,
    required this.name,
    this.fullName,
    this.agency,
    this.benefit,
    this.eligibility = const [],
    this.deadline,
  });

  factory Scheme.fromMap(Map<String, dynamic> map) => Scheme(
        id: map['id'] as String,
        name: map['name'] as String,
        fullName: map['full_name'] as String?,
        agency: map['agency'] as String?,
        benefit: map['benefit'] as String?,
        eligibility: (map['eligibility'] as List?)?.map((e) => e as String).toList() ?? const [],
        deadline: map['deadline'] != null ? DateTime.parse(map['deadline'] as String) : null,
      );
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
