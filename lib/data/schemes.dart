class Scheme {
  final String id;
  final String name;
  final String fullName;
  final String agency;
  final String benefit;
  final List<String> eligibility;
  final String status; // not_applied | applied | under_review | approved | rejected
  final String? deadline;
  // Structured, machine-evaluable eligibility criteria — mirrors
  // `public.schemes.eligibility_criteria` (see
  // `supabase/migrations/0040_scheme_eligibility_criteria.sql` and
  // `EligibilityCriteria` in `lib/models/scheme.dart`). Deliberately not a
  // `lib/models` import — this file stays a dependency-free data source
  // like every other `lib/data/*.dart`; `SchemeRepository.fetchSchemes()`
  // maps these three raw fields onto the real `EligibilityCriteria` type.
  //
  // Editorial note: these three fields are this project's own illustrative
  // mapping of each scheme's *existing* free-text `eligibility` prose onto
  // the only member/SHG facts this app actually stores (SHG membership,
  // registration age, grade) — not sourced from official scheme guidelines.
  // sc2 (PMEGP) and sc4 (Stand-Up India) are individual-entrepreneur
  // programmes whose real eligibility text never mentions an SHG
  // requirement at all, so they're deliberately left with no structured
  // criteria rather than an invented one — their full requirements remain
  // manual-verification-only via the free-text `eligibility` list.
  final bool requiresShgMembership;
  final int? minShgAgeMonths;
  final String? minShgGrade;
  const Scheme({
    required this.id,
    required this.name,
    required this.fullName,
    required this.agency,
    required this.benefit,
    required this.eligibility,
    this.status = 'not_applied',
    this.deadline,
    this.requiresShgMembership = false,
    this.minShgAgeMonths,
    this.minShgGrade,
  });
}

const schemes = <Scheme>[
  Scheme(
    id: 'sc1', name: 'DAY-NRLM', fullName: 'Deendayal Antyodaya Yojana - National Rural Livelihoods Mission',
    agency: 'Ministry of Rural Development', benefit: 'Revolving fund of ₹15,000–₹30,000 and interest subvention on SHG loans',
    eligibility: ['SHG registered for 6+ months', 'BPL / rural household', 'Active savings record'], status: 'approved',
    requiresShgMembership: true, minShgAgeMonths: 6,
  ),
  Scheme(
    id: 'sc2', name: 'PMEGP', fullName: 'Prime Minister’s Employment Generation Programme',
    agency: 'KVIC / Ministry of MSME', benefit: 'Subsidy up to 35% on project cost for new micro-enterprises',
    eligibility: ['Age 18+', 'No prior PMEGP subsidy availed', 'Project cost up to ₹50 lakh'], status: 'under_review', deadline: '15 Jul 2026',
  ),
  Scheme(
    id: 'sc3', name: 'MUDRA', fullName: 'Micro Units Development & Refinance Agency Yojana',
    agency: 'Ministry of Finance', benefit: 'Collateral-free loans up to ₹10 lakh under Shishu/Kishor/Tarun',
    eligibility: ['Non-farm income generating activity', 'Existing or new micro business'], status: 'applied', deadline: '10 Jul 2026',
    requiresShgMembership: true,
  ),
  Scheme(
    id: 'sc4', name: 'Stand-Up India', fullName: 'Stand-Up India Scheme',
    agency: 'Department of Financial Services', benefit: 'Bank loans ₹10 lakh – ₹1 crore for greenfield enterprises',
    eligibility: ['Women / SC/ST entrepreneur', 'Greenfield project', 'Non-individual borrowers eligible'], status: 'not_applied',
  ),
  Scheme(
    id: 'sc5', name: 'NRLM RF', fullName: 'Revolving Fund Support',
    agency: 'State Rural Livelihoods Mission', benefit: 'One-time grant support to strengthen SHG corpus',
    eligibility: ['SHG grading of B or above', 'Regular meeting & savings record'], status: 'not_applied',
    requiresShgMembership: true, minShgGrade: 'B',
  ),
];
