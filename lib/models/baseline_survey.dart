/// Mirrors a row in `public.member_baseline_surveys` — the ICSSR baseline
/// survey (demographics, enterprise profile, digital access, financial
/// inclusion, entrepreneurial skills, empowerment, challenges & needs,
/// government/NGO expectations, consent) filled once at registration time
/// (see `lib/pages/auth/profile_setup_page.dart`).
///
/// Only a write model for now — `toMap()` is all `BaselineSurveyRepository`
/// needs to submit it. Nothing in the app currently reads a full row back
/// (only whether one exists at all, via `BaselineSurveyRepository.
/// hasSubmitted`), so there's no `fromMap` yet; add one alongside whatever
/// first needs to display an already-submitted response (e.g. a future
/// admin research-reporting view).
class BaselineSurveyDraft {
  // Section A: Demographics
  final int? age;
  final String? educationLevel;
  final String? casteCommunity;
  final String? maritalStatus;
  final int? householdSize;
  final String? surveyLocation;
  final String? surveyLocationOther;
  final double? annualHouseholdIncome;
  final String? primaryIncomeSource;

  // Section B: Enterprise Profile
  final String? enterpriseType;
  final String? enterpriseSector;
  final String? enterpriseSectorOther;
  final double? yearsInOperation;
  final double? monthlyRevenue;
  final int? employeesCount;
  final String? registrationStatus;
  final String? marketReach;

  // Section C: Digital Access & Usage
  final bool? ownsSmartphone;
  final String? internetAccess;
  final String? internetType;
  final String? internetTypeOther;
  final Set<String> appsUsed;
  final bool? receivedDigitalTraining;
  final String? digitalPaymentFrequency;
  final String? digitalToolsComfort;

  // Section D: Financial Inclusion
  final bool? hasBankAccount;
  final String? creditAccess;
  final String? digitalPaymentUsage;
  final String? savingsPattern;
  final bool? awareGovtSchemes;
  final String? govtSchemesDetail;

  // Section E: Entrepreneurial Skills
  final String? businessPlanningKnowledge;
  final String? recordKeeping;
  final bool? hasInventorySystem;
  final bool? participatedBusinessTraining;
  final String? onlineMarketingAbility;
  final String? innovationLevel;

  // Section F: Empowerment & Agency
  final String? householdDecisionRole;
  final String? mobility;
  final bool? shgLeadershipRole;
  final String? techConfidence;
  final String? communityInfluence;
  final String? negotiationAbility;

  // Section G: Challenges & Needs
  final List<String> topChallenges;
  final Set<String> trainingNeeds;
  final String? trainingNeedsOther;
  final Set<String> supportNeeded;
  final bool? interestedInTrainingTrials;
  final String? expectedProjectBenefit;

  // Section H: Expectations from Government/NGOs
  final Set<String> govtNgoSupportNeeded;
  final String? govtNgoSupportOther;

  // Section I: Consent & Confidentiality
  final bool consentGiven;
  final String signatureName;

  const BaselineSurveyDraft({
    this.age,
    this.educationLevel,
    this.casteCommunity,
    this.maritalStatus,
    this.householdSize,
    this.surveyLocation,
    this.surveyLocationOther,
    this.annualHouseholdIncome,
    this.primaryIncomeSource,
    this.enterpriseType,
    this.enterpriseSector,
    this.enterpriseSectorOther,
    this.yearsInOperation,
    this.monthlyRevenue,
    this.employeesCount,
    this.registrationStatus,
    this.marketReach,
    this.ownsSmartphone,
    this.internetAccess,
    this.internetType,
    this.internetTypeOther,
    this.appsUsed = const {},
    this.receivedDigitalTraining,
    this.digitalPaymentFrequency,
    this.digitalToolsComfort,
    this.hasBankAccount,
    this.creditAccess,
    this.digitalPaymentUsage,
    this.savingsPattern,
    this.awareGovtSchemes,
    this.govtSchemesDetail,
    this.businessPlanningKnowledge,
    this.recordKeeping,
    this.hasInventorySystem,
    this.participatedBusinessTraining,
    this.onlineMarketingAbility,
    this.innovationLevel,
    this.householdDecisionRole,
    this.mobility,
    this.shgLeadershipRole,
    this.techConfidence,
    this.communityInfluence,
    this.negotiationAbility,
    this.topChallenges = const [],
    this.trainingNeeds = const {},
    this.trainingNeedsOther,
    this.supportNeeded = const {},
    this.interestedInTrainingTrials,
    this.expectedProjectBenefit,
    this.govtNgoSupportNeeded = const {},
    this.govtNgoSupportOther,
    required this.consentGiven,
    required this.signatureName,
  });

  Map<String, dynamic> toMap() => {
        'age': age,
        'education_level': educationLevel,
        'caste_community': _blankToNull(casteCommunity),
        'marital_status': maritalStatus,
        'household_size': householdSize,
        'survey_location': surveyLocation,
        'survey_location_other': _blankToNull(surveyLocationOther),
        'annual_household_income': annualHouseholdIncome,
        'primary_income_source': _blankToNull(primaryIncomeSource),
        'enterprise_type': enterpriseType,
        'enterprise_sector': enterpriseSector,
        'enterprise_sector_other': _blankToNull(enterpriseSectorOther),
        'years_in_operation': yearsInOperation,
        'monthly_revenue': monthlyRevenue,
        'employees_count': employeesCount,
        'registration_status': registrationStatus,
        'market_reach': marketReach,
        'owns_smartphone': ownsSmartphone,
        'internet_access': internetAccess,
        'internet_type': internetType,
        'internet_type_other': _blankToNull(internetTypeOther),
        'apps_used': appsUsed.toList(),
        'received_digital_training': receivedDigitalTraining,
        'digital_payment_frequency': digitalPaymentFrequency,
        'digital_tools_comfort': digitalToolsComfort,
        'has_bank_account': hasBankAccount,
        'credit_access': creditAccess,
        'digital_payment_usage': digitalPaymentUsage,
        'savings_pattern': savingsPattern,
        'aware_govt_schemes': awareGovtSchemes,
        'govt_schemes_detail': _blankToNull(govtSchemesDetail),
        'business_planning_knowledge': businessPlanningKnowledge,
        'record_keeping': recordKeeping,
        'has_inventory_system': hasInventorySystem,
        'participated_business_training': participatedBusinessTraining,
        'online_marketing_ability': onlineMarketingAbility,
        'innovation_level': innovationLevel,
        'household_decision_role': householdDecisionRole,
        'mobility': mobility,
        'shg_leadership_role': shgLeadershipRole,
        'tech_confidence': techConfidence,
        'community_influence': communityInfluence,
        'negotiation_ability': negotiationAbility,
        'top_challenges': topChallenges.where((c) => c.trim().isNotEmpty).toList(),
        'training_needs': trainingNeeds.toList(),
        'training_needs_other': _blankToNull(trainingNeedsOther),
        'support_needed': supportNeeded.toList(),
        'interested_in_training_trials': interestedInTrainingTrials,
        'expected_project_benefit': _blankToNull(expectedProjectBenefit),
        'govt_ngo_support_needed': govtNgoSupportNeeded.toList(),
        'govt_ngo_support_other': _blankToNull(govtNgoSupportOther),
        'consent_given': consentGiven,
        'signature_name': signatureName.trim(),
      };

  static String? _blankToNull(String? value) => (value == null || value.trim().isEmpty) ? null : value.trim();
}
