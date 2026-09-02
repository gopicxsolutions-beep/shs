import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/shg.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/baseline_survey.dart';
import '../../models/profile.dart' show ShgSearchResult;
import '../../routes/paths.dart';
import '../../services/profile_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/choice_field.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/shg_search_sheet.dart';

/// Registration. Two parts, one continuous wizard, `_step`-indexed
/// (0 = basic info, 1-9 = the ICSSR baseline survey's Sections A-I — see
/// migration 0151_iteration44_member_baseline_survey.sql for the full field
/// list this mirrors) so both submit together in a single
/// `completeProfileSetup`/`submitBaselineSurvey` pair on the last step,
/// rather than as separate routes — see AppState.needsBaselineSurvey's doc
/// comment for why this page (not a standalone route) is also where an
/// account created before the survey requirement shipped fills the gap in.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  static const _totalSurveySections = 9;

  // Basic info (step 0)
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _mandal = TextEditingController();
  final _district = TextEditingController();
  final _profileRepository = ProfileRepository();
  ShgSearchResult? _selectedShg;

  // Section A: Demographics
  final _age = TextEditingController();
  String? _educationLevel;
  final _casteCommunity = TextEditingController();
  String? _maritalStatus;
  final _householdSize = TextEditingController();
  String? _surveyLocation;
  final _surveyLocationOther = TextEditingController();
  final _annualIncome = TextEditingController();
  final _primaryIncomeSource = TextEditingController();

  // Section B: Enterprise Profile
  String? _enterpriseType;
  String? _enterpriseSector;
  final _enterpriseSectorOther = TextEditingController();
  final _yearsInOperation = TextEditingController();
  final _monthlyRevenue = TextEditingController();
  final _employeesCount = TextEditingController();
  String? _registrationStatus;
  String? _marketReach;

  // Section C: Digital Access & Usage
  bool? _ownsSmartphone;
  String? _internetAccess;
  String? _internetType;
  final _internetTypeOther = TextEditingController();
  Set<String> _appsUsed = {};
  bool? _receivedDigitalTraining;
  String? _digitalPaymentFrequency;
  String? _digitalToolsComfort;

  // Section D: Financial Inclusion
  bool? _hasBankAccount;
  String? _creditAccess;
  String? _digitalPaymentUsage;
  String? _savingsPattern;
  bool? _awareGovtSchemes;
  final _govtSchemesDetail = TextEditingController();

  // Section E: Entrepreneurial Skills
  String? _businessPlanningKnowledge;
  String? _recordKeeping;
  bool? _hasInventorySystem;
  bool? _participatedBusinessTraining;
  String? _onlineMarketingAbility;
  String? _innovationLevel;

  // Section F: Empowerment & Agency
  String? _householdDecisionRole;
  String? _mobility;
  bool? _shgLeadershipRole;
  String? _techConfidence;
  String? _communityInfluence;
  String? _negotiationAbility;

  // Section G: Challenges & Needs
  final _challenge1 = TextEditingController();
  final _challenge2 = TextEditingController();
  final _challenge3 = TextEditingController();
  Set<String> _trainingNeeds = {};
  final _trainingNeedsOther = TextEditingController();
  Set<String> _supportNeeded = {};
  bool? _interestedInTrials;
  final _expectedBenefit = TextEditingController();

  // Section H: Expectations from Government/NGOs
  Set<String> _govtNgoSupportNeeded = {};
  final _govtNgoSupportOther = TextEditingController();

  // Section I: Consent & Confidentiality
  bool _consentGiven = false;
  final _signatureName = TextEditingController();

  int _step = 0;
  // True for an account that already has a `profiles` row (and may already
  // be an approved member) but is missing only the baseline survey — see
  // AppState.needsBaselineSurvey's doc comment. Step 0 (name/village/SHG)
  // doesn't apply to her: that data already exists.
  bool _surveyOnly = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    _surveyOnly = profile != null;
    if (_surveyOnly) _step = 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    _mandal.dispose();
    _district.dispose();
    _age.dispose();
    _casteCommunity.dispose();
    _householdSize.dispose();
    _surveyLocationOther.dispose();
    _annualIncome.dispose();
    _primaryIncomeSource.dispose();
    _enterpriseSectorOther.dispose();
    _yearsInOperation.dispose();
    _monthlyRevenue.dispose();
    _employeesCount.dispose();
    _internetTypeOther.dispose();
    _govtSchemesDetail.dispose();
    _challenge1.dispose();
    _challenge2.dispose();
    _challenge3.dispose();
    _trainingNeedsOther.dispose();
    _expectedBenefit.dispose();
    _govtNgoSupportOther.dispose();
    _signatureName.dispose();
    super.dispose();
  }

  Widget _field(String label, {String? placeholder, TextEditingController? controller, TextInputAction? textInputAction, TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 6),
        Container(
          height: maxLines > 1 ? null : 44,
          decoration: BoxDecoration(border: Border.all(color: Neutral.c200), borderRadius: BorderRadius.circular(12), color: Colors.white),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 10 : 0),
          alignment: maxLines > 1 ? Alignment.topLeft : Alignment.centerLeft,
          child: TextField(
            controller: controller,
            textInputAction: textInputAction,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(border: InputBorder.none, hintText: placeholder),
            style: AppTheme.sans(14),
          ),
        ),
      ],
    );
  }

  Widget _numberField(String label, TextEditingController controller, {bool decimal = false}) =>
      _field(label, controller: controller, keyboardType: TextInputType.numberWithOptions(decimal: decimal));

  Widget _yesNo(AppLocalizations l10n, String label, bool? value, ValueChanged<bool> onChanged) => ChoiceChipGroup<bool>(
        label: label,
        value: value,
        onChanged: onChanged,
        options: [ChoiceOption(true, l10n.commonYes), ChoiceOption(false, l10n.commonNo)],
      );

  List<Widget> _spaced(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(height: 14));
      out.add(items[i]);
    }
    return out;
  }

  int? _parseInt(TextEditingController c) => int.tryParse(c.text.trim());
  double? _parseDouble(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _pickShg() async {
    if (!SupabaseService.isConfigured) {
      setState(() => _selectedShg = const ShgSearchResult(
            id: 'demo-shg',
            name: ShgInfo.name,
            village: ShgInfo.village,
            mandal: ShgInfo.mandal,
            district: ShgInfo.district,
            grade: ShgInfo.grade,
          ));
      return;
    }
    final result = await showShgSearchSheet(context, search: _profileRepository.searchShgs);
    if (!mounted) return;
    if (result != null) setState(() => _selectedShg = result);
  }

  BaselineSurveyDraft _buildDraft() => BaselineSurveyDraft(
        age: _parseInt(_age),
        educationLevel: _educationLevel,
        casteCommunity: _casteCommunity.text,
        maritalStatus: _maritalStatus,
        householdSize: _parseInt(_householdSize),
        surveyLocation: _surveyLocation,
        surveyLocationOther: _surveyLocationOther.text,
        annualHouseholdIncome: _parseDouble(_annualIncome),
        primaryIncomeSource: _primaryIncomeSource.text,
        enterpriseType: _enterpriseType,
        enterpriseSector: _enterpriseSector,
        enterpriseSectorOther: _enterpriseSectorOther.text,
        yearsInOperation: _parseDouble(_yearsInOperation),
        monthlyRevenue: _parseDouble(_monthlyRevenue),
        employeesCount: _parseInt(_employeesCount),
        registrationStatus: _registrationStatus,
        marketReach: _marketReach,
        ownsSmartphone: _ownsSmartphone,
        internetAccess: _internetAccess,
        internetType: _internetType,
        internetTypeOther: _internetTypeOther.text,
        appsUsed: _appsUsed,
        receivedDigitalTraining: _receivedDigitalTraining,
        digitalPaymentFrequency: _digitalPaymentFrequency,
        digitalToolsComfort: _digitalToolsComfort,
        hasBankAccount: _hasBankAccount,
        creditAccess: _creditAccess,
        digitalPaymentUsage: _digitalPaymentUsage,
        savingsPattern: _savingsPattern,
        awareGovtSchemes: _awareGovtSchemes,
        govtSchemesDetail: _govtSchemesDetail.text,
        businessPlanningKnowledge: _businessPlanningKnowledge,
        recordKeeping: _recordKeeping,
        hasInventorySystem: _hasInventorySystem,
        participatedBusinessTraining: _participatedBusinessTraining,
        onlineMarketingAbility: _onlineMarketingAbility,
        innovationLevel: _innovationLevel,
        householdDecisionRole: _householdDecisionRole,
        mobility: _mobility,
        shgLeadershipRole: _shgLeadershipRole,
        techConfidence: _techConfidence,
        communityInfluence: _communityInfluence,
        negotiationAbility: _negotiationAbility,
        topChallenges: [_challenge1.text, _challenge2.text, _challenge3.text],
        trainingNeeds: _trainingNeeds,
        trainingNeedsOther: _trainingNeedsOther.text,
        supportNeeded: _supportNeeded,
        interestedInTrainingTrials: _interestedInTrials,
        expectedProjectBenefit: _expectedBenefit.text,
        govtNgoSupportNeeded: _govtNgoSupportNeeded,
        govtNgoSupportOther: _govtNgoSupportOther.text,
        consentGiven: _consentGiven,
        signatureName: _signatureName.text,
      );

  void _advance() => setState(() => _step++);
  void _retreat() => setState(() => _step--);

  Future<void> _submit() async {
    // Same re-entrancy guard as login_page.dart._submit — see its comment.
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    if (!_surveyOnly && _selectedShg != null && SupabaseService.isConfigured) {
      appState.setPendingShg(_selectedShg!);
    }
    try {
      if (!_surveyOnly) {
        // See profile_setup_page.dart's (this file's) original doc comment,
        // preserved below on `_basicInfoFields`, for why an SHG is
        // mandatory and why `village` uses `?? _selectedShg?.village` while
        // `mandal`/`district` don't.
        await appState.completeProfileSetup(
          name: _name.text.trim(),
          village: _village.text.trim().isNotEmpty ? _village.text.trim() : _selectedShg?.village,
          mandal: _mandal.text.trim().isNotEmpty ? _mandal.text.trim() : _selectedShg?.mandal,
          district: _district.text.trim().isNotEmpty ? _district.text.trim() : _selectedShg?.district,
        );
      }
      await appState.submitBaselineSurvey(_buildDraft());
      // Mirrors otp_page.dart's own post-verify navigation — an explicit
      // `hasProfile` check, not a blind `context.go(Paths.dashboard)`. The
      // router's `!hasProfile` redirect (lib/routes/router.dart) always
      // sends a non-onboarding destination back to `Paths.profileSetup`
      // specifically, never `Paths.roleSelect` — correct for a `!hasProfile`
      // visit from anywhere else, but wrong for exactly this moment in demo
      // mode: `submitBaselineSurvey` above doesn't set `hasProfile` there
      // (only `setRole`/Role Select does — see AppState's two-flag doc
      // comment), so a blind dashboard navigation would bounce straight
      // back to this same page instead of advancing to Role Select. Live
      // mode is unaffected either way: `completeProfileSetup` always makes
      // `hasProfile` true before this line runs (or it already was, for the
      // `_surveyOnly` gap-fill case), so this always picks
      // `Paths.dashboard` there, and the router's own (correctly-targeted)
      // `needsShgApproval` redirect takes it from there if needed.
      if (mounted) context.go(appState.hasProfile ? Paths.dashboard : Paths.roleSelect);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.baselineSurveySubmitError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Basic info — unchanged from before this page grew the baseline survey
  // steps, aside from no longer submitting on its own Continue tap (that
  // now just advances to Section A; the actual submit is `_submit`, gated
  // to the survey's last step).
  //
  // An SHG is required, not optional: every signup starts as a plain
  // 'member' with a mandatory SHG join request — Role Select no longer lets
  // anyone self-declare 'leader' (see role_select_page.dart), so becoming a
  // leader now happens ONLY by whoever approves this same join request
  // choosing to promote her at that moment (see ShgJoinRequestsPage).
  // Without a mandatory SHG pick here, a leader-to-be had no path to ever
  // end up linked to a real SHG at all — the actual bug this requirement
  // exists to close.
  //
  // This doesn't block staff signup: no self-service path has ever reached
  // crp/clf/admin (`profiles_insert_self`'s RLS only ever allows
  // role in ('member','leader')) — staff are exclusively promoted from an
  // existing profile via Admin > Manage Users, which never goes through
  // this page. Nor does it block a fresh deployment's first admin: that
  // account has always been a one-time direct-SQL promotion, not something
  // that runs through Profile Setup either.
  List<Widget> _basicInfoFields(AppLocalizations l10n) => [
        _field(l10n.fieldFullName, placeholder: 'e.g. Lakshmi Devi', controller: _name, textInputAction: TextInputAction.next),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _field(l10n.profileVillage, placeholder: 'Kondapur', controller: _village, textInputAction: TextInputAction.next)),
          const SizedBox(width: 12),
          Expanded(child: _field(l10n.fieldMandal, placeholder: 'Hanamkonda', controller: _mandal, textInputAction: TextInputAction.next)),
        ]),
        const SizedBox(height: 14),
        _field(l10n.fieldDistrict, placeholder: 'Warangal', controller: _district, textInputAction: TextInputAction.done),
        const SizedBox(height: 14),
        Text(l10n.yourShg, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 6),
        AppCard(
          onTap: _pickShg,
          borderColor: _selectedShg != null ? Brand.c500 : null,
          child: _selectedShg != null
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedShg!.name, style: AppTheme.sans(14, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${_selectedShg!.village}, ${_selectedShg!.district}', style: AppTheme.sans(12, color: Neutral.c500)),
                        ],
                      ),
                    ),
                    Text(l10n.changeShg, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                  ],
                )
              : Row(children: [
                  Icon(Icons.search, size: 16, color: Neutral.c500),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.searchSelectShg, style: AppTheme.sans(14, color: Neutral.c500), overflow: TextOverflow.ellipsis)),
                ]),
        ),
      ];

  List<Widget> _sectionA(AppLocalizations l10n) => _spaced([
        _numberField(l10n.baselineSurveyAge, _age),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyEducationLevel,
          value: _educationLevel,
          onChanged: (v) => setState(() => _educationLevel = v),
          options: [
            ChoiceOption('none', l10n.baselineSurveyEducationNone),
            ChoiceOption('primary', l10n.baselineSurveyEducationPrimary),
            ChoiceOption('secondary', l10n.baselineSurveyEducationSecondary),
            ChoiceOption('graduate', l10n.baselineSurveyEducationGraduate),
            ChoiceOption('postgraduate', l10n.baselineSurveyEducationPostgraduate),
          ],
        ),
        _field(l10n.baselineSurveyCasteCommunity, controller: _casteCommunity),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyMaritalStatus,
          value: _maritalStatus,
          onChanged: (v) => setState(() => _maritalStatus = v),
          options: [
            ChoiceOption('single', l10n.baselineSurveyMaritalSingle),
            ChoiceOption('married', l10n.baselineSurveyMaritalMarried),
            ChoiceOption('widowed', l10n.baselineSurveyMaritalWidowed),
            ChoiceOption('separated_divorced', l10n.baselineSurveyMaritalSeparated),
          ],
        ),
        _numberField(l10n.baselineSurveyHouseholdSize, _householdSize),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyLocation,
          value: _surveyLocation,
          onChanged: (v) => setState(() => _surveyLocation = v),
          options: [
            ChoiceOption('east_godavari', l10n.baselineSurveyLocationEastGodavari),
            ChoiceOption('west_godavari', l10n.baselineSurveyLocationWestGodavari),
            ChoiceOption('krishna', l10n.baselineSurveyLocationKrishna),
            ChoiceOption('other', l10n.baselineSurveyOtherOption),
          ],
        ),
        if (_surveyLocation == 'other') _field(l10n.baselineSurveySpecifyPlaceholder, controller: _surveyLocationOther),
        _numberField(l10n.baselineSurveyAnnualIncome, _annualIncome, decimal: true),
        _field(l10n.baselineSurveyPrimaryIncomeSource, controller: _primaryIncomeSource),
      ]);

  List<Widget> _sectionB(AppLocalizations l10n) => _spaced([
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyEnterpriseType,
          value: _enterpriseType,
          onChanged: (v) => setState(() => _enterpriseType = v),
          options: [
            ChoiceOption('shg_led', l10n.baselineSurveyEnterpriseShgLed),
            ChoiceOption('individual', l10n.baselineSurveyEnterpriseIndividual),
            ChoiceOption('collective', l10n.baselineSurveyEnterpriseCollective),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveySector,
          value: _enterpriseSector,
          onChanged: (v) => setState(() => _enterpriseSector = v),
          options: [
            ChoiceOption('agri_food_processing', l10n.baselineSurveySectorAgriFood),
            ChoiceOption('tailoring_textiles', l10n.baselineSurveySectorTailoring),
            ChoiceOption('retail', l10n.baselineSurveySectorRetail),
            ChoiceOption('services', l10n.baselineSurveySectorServices),
            ChoiceOption('others', l10n.baselineSurveyOthersOption),
          ],
        ),
        if (_enterpriseSector == 'others') _field(l10n.baselineSurveySpecifyPlaceholder, controller: _enterpriseSectorOther),
        _numberField(l10n.baselineSurveyYearsInOperation, _yearsInOperation, decimal: true),
        _numberField(l10n.baselineSurveyMonthlyRevenue, _monthlyRevenue, decimal: true),
        _numberField(l10n.baselineSurveyEmployees, _employeesCount),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyRegistrationStatus,
          value: _registrationStatus,
          onChanged: (v) => setState(() => _registrationStatus = v),
          options: [
            ChoiceOption('registered', l10n.baselineSurveyRegistered),
            ChoiceOption('unregistered', l10n.baselineSurveyUnregistered),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyMarketReach,
          value: _marketReach,
          onChanged: (v) => setState(() => _marketReach = v),
          options: [
            ChoiceOption('local', l10n.baselineSurveyMarketLocal),
            ChoiceOption('district', l10n.baselineSurveyMarketDistrict),
            ChoiceOption('state', l10n.baselineSurveyMarketState),
            ChoiceOption('national', l10n.baselineSurveyMarketNational),
            ChoiceOption('international', l10n.baselineSurveyMarketInternational),
          ],
        ),
      ]);

  List<Widget> _sectionC(AppLocalizations l10n) => _spaced([
        _yesNo(l10n, l10n.baselineSurveyOwnsSmartphone, _ownsSmartphone, (v) => setState(() => _ownsSmartphone = v)),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyInternetAccess,
          value: _internetAccess,
          onChanged: (v) => setState(() => _internetAccess = v),
          options: [
            ChoiceOption('regular', l10n.baselineSurveyFreqRegular),
            ChoiceOption('occasional', l10n.baselineSurveyFreqOccasional),
            ChoiceOption('never', l10n.baselineSurveyFreqNever),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyInternetType,
          value: _internetType,
          onChanged: (v) => setState(() => _internetType = v),
          options: [
            ChoiceOption('mobile_data', l10n.baselineSurveyInternetMobileData),
            ChoiceOption('wifi', l10n.baselineSurveyInternetWifi),
            ChoiceOption('other', l10n.baselineSurveyOtherOption),
          ],
        ),
        if (_internetType == 'other') _field(l10n.baselineSurveySpecifyPlaceholder, controller: _internetTypeOther),
        MultiChoiceChipGroup(
          label: l10n.baselineSurveyAppsUsed,
          values: _appsUsed,
          onChanged: (v) => setState(() => _appsUsed = v),
          options: [
            ChoiceOption('whatsapp', l10n.baselineSurveyAppWhatsapp),
            ChoiceOption('youtube', l10n.baselineSurveyAppYoutube),
            ChoiceOption('upi', l10n.baselineSurveyAppUpi),
            ChoiceOption('govt_portals', l10n.baselineSurveyAppGovtPortals),
            ChoiceOption('social_media', l10n.baselineSurveyAppSocialMedia),
            ChoiceOption('ecommerce', l10n.baselineSurveyAppEcommerce),
          ],
        ),
        _yesNo(l10n, l10n.baselineSurveyReceivedDigitalTraining, _receivedDigitalTraining, (v) => setState(() => _receivedDigitalTraining = v)),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyDigitalPaymentFrequency,
          value: _digitalPaymentFrequency,
          onChanged: (v) => setState(() => _digitalPaymentFrequency = v),
          options: [
            ChoiceOption('daily', l10n.baselineSurveyFreqDaily),
            ChoiceOption('weekly', l10n.baselineSurveyFreqWeekly),
            ChoiceOption('occasionally', l10n.baselineSurveyFreqOccasionally),
            ChoiceOption('never', l10n.baselineSurveyFreqNever),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyDigitalToolsComfort,
          value: _digitalToolsComfort,
          onChanged: (v) => setState(() => _digitalToolsComfort = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
      ]);

  List<Widget> _sectionD(AppLocalizations l10n) => _spaced([
        _yesNo(l10n, l10n.baselineSurveyBankAccount, _hasBankAccount, (v) => setState(() => _hasBankAccount = v)),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyCreditAccess,
          value: _creditAccess,
          onChanged: (v) => setState(() => _creditAccess = v),
          options: [
            ChoiceOption('formal', l10n.baselineSurveyCreditFormal),
            ChoiceOption('informal', l10n.baselineSurveyCreditInformal),
            ChoiceOption('none', l10n.baselineSurveyNoneOption),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyDigitalPaymentUsage,
          value: _digitalPaymentUsage,
          onChanged: (v) => setState(() => _digitalPaymentUsage = v),
          options: [
            ChoiceOption('often', l10n.baselineSurveyFreqOften),
            ChoiceOption('sometimes', l10n.baselineSurveyFreqSometimes),
            ChoiceOption('never', l10n.baselineSurveyFreqNever),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveySavingsPattern,
          value: _savingsPattern,
          onChanged: (v) => setState(() => _savingsPattern = v),
          options: [
            ChoiceOption('regular', l10n.baselineSurveyFreqRegular),
            ChoiceOption('irregular', l10n.baselineSurveyFreqIrregular),
            ChoiceOption('none', l10n.baselineSurveyNoneOption),
          ],
        ),
        _yesNo(l10n, l10n.baselineSurveyAwareGovtSchemes, _awareGovtSchemes, (v) => setState(() => _awareGovtSchemes = v)),
        if (_awareGovtSchemes == true) _field(l10n.baselineSurveyGovtSchemesDetail, controller: _govtSchemesDetail),
      ]);

  List<Widget> _sectionE(AppLocalizations l10n) => _spaced([
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyBusinessPlanningKnowledge,
          value: _businessPlanningKnowledge,
          onChanged: (v) => setState(() => _businessPlanningKnowledge = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyRecordKeeping,
          value: _recordKeeping,
          onChanged: (v) => setState(() => _recordKeeping = v),
          options: [
            ChoiceOption('manual', l10n.baselineSurveyRecordManual),
            ChoiceOption('digital', l10n.baselineSurveyRecordDigital),
            ChoiceOption('none', l10n.baselineSurveyNoneOption),
          ],
        ),
        _yesNo(l10n, l10n.baselineSurveyInventorySystem, _hasInventorySystem, (v) => setState(() => _hasInventorySystem = v)),
        _yesNo(l10n, l10n.baselineSurveyBusinessTraining, _participatedBusinessTraining, (v) => setState(() => _participatedBusinessTraining = v)),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyOnlineMarketingAbility,
          value: _onlineMarketingAbility,
          onChanged: (v) => setState(() => _onlineMarketingAbility = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyInnovationLevel,
          value: _innovationLevel,
          onChanged: (v) => setState(() => _innovationLevel = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
      ]);

  List<Widget> _sectionF(AppLocalizations l10n) => _spaced([
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyDecisionMakingRole,
          value: _householdDecisionRole,
          onChanged: (v) => setState(() => _householdDecisionRole = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyMobility,
          value: _mobility,
          onChanged: (v) => setState(() => _mobility = v),
          options: [
            ChoiceOption('always', l10n.baselineSurveyFreqAlways),
            ChoiceOption('sometimes', l10n.baselineSurveyFreqSometimes),
            ChoiceOption('never', l10n.baselineSurveyFreqNever),
          ],
        ),
        _yesNo(l10n, l10n.baselineSurveyShgLeadershipRole, _shgLeadershipRole, (v) => setState(() => _shgLeadershipRole = v)),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyTechConfidence,
          value: _techConfidence,
          onChanged: (v) => setState(() => _techConfidence = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyCommunityInfluence,
          value: _communityInfluence,
          onChanged: (v) => setState(() => _communityInfluence = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
        ChoiceChipGroup<String>(
          label: l10n.baselineSurveyNegotiationAbility,
          value: _negotiationAbility,
          onChanged: (v) => setState(() => _negotiationAbility = v),
          options: [
            ChoiceOption('high', l10n.baselineSurveyLevelHigh),
            ChoiceOption('moderate', l10n.baselineSurveyLevelModerate),
            ChoiceOption('low', l10n.baselineSurveyLevelLow),
          ],
        ),
      ]);

  List<Widget> _sectionG(AppLocalizations l10n) => _spaced([
        Text(l10n.baselineSurveyTopChallenges, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 10),
        Column(children: _spaced([
          _field(l10n.baselineSurveyChallengeHint(1), controller: _challenge1),
          _field(l10n.baselineSurveyChallengeHint(2), controller: _challenge2),
          _field(l10n.baselineSurveyChallengeHint(3), controller: _challenge3),
        ])),
        MultiChoiceChipGroup(
          label: l10n.baselineSurveyTrainingNeeds,
          values: _trainingNeeds,
          onChanged: (v) => setState(() => _trainingNeeds = v),
          options: [
            ChoiceOption('digital_marketing', l10n.baselineSurveyTrainingDigitalMarketing),
            ChoiceOption('financial_management', l10n.baselineSurveyTrainingFinancialManagement),
            ChoiceOption('product_quality', l10n.baselineSurveyTrainingProductQuality),
            ChoiceOption('ecommerce_training', l10n.baselineSurveyTrainingEcommerce),
            ChoiceOption('others', l10n.baselineSurveyOthersOption),
          ],
        ),
        if (_trainingNeeds.contains('others')) _field(l10n.baselineSurveySpecifyPlaceholder, controller: _trainingNeedsOther),
        MultiChoiceChipGroup(
          label: l10n.baselineSurveySupportNeeded,
          values: _supportNeeded,
          onChanged: (v) => setState(() => _supportNeeded = v),
          options: [
            ChoiceOption('credit_access', l10n.baselineSurveySupportCredit),
            ChoiceOption('marketing_support', l10n.baselineSurveySupportMarketing),
            ChoiceOption('mentorship', l10n.baselineSurveySupportMentorship),
            ChoiceOption('govt_scheme_awareness', l10n.baselineSurveySupportGovtAwareness),
            ChoiceOption('networking', l10n.baselineSurveySupportNetworking),
          ],
        ),
        _yesNo(l10n, l10n.baselineSurveyInterestedInTrials, _interestedInTrials, (v) => setState(() => _interestedInTrials = v)),
        _field(l10n.baselineSurveyExpectedBenefit, controller: _expectedBenefit, maxLines: 3),
      ]);

  List<Widget> _sectionH(AppLocalizations l10n) => _spaced([
        MultiChoiceChipGroup(
          label: l10n.baselineSurveyGovtNgoSupport,
          values: _govtNgoSupportNeeded,
          onChanged: (v) => setState(() => _govtNgoSupportNeeded = v),
          options: [
            ChoiceOption('subsidies_financial_aid', l10n.baselineSurveySupportSubsidies),
            ChoiceOption('digital_training_centers', l10n.baselineSurveySupportDigitalCenters),
            ChoiceOption('market_linkages', l10n.baselineSurveySupportMarketLinkages),
            ChoiceOption('improved_infrastructure', l10n.baselineSurveySupportInfrastructure),
            ChoiceOption('others', l10n.baselineSurveyOthersOption),
          ],
        ),
        if (_govtNgoSupportNeeded.contains('others')) _field(l10n.baselineSurveySpecifyPlaceholder, controller: _govtNgoSupportOther),
      ]);

  List<Widget> _sectionI(AppLocalizations l10n) => _spaced([
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)),
          child: Text(l10n.baselineSurveyConsentStatement, style: AppTheme.sans(13, color: Neutral.c700)),
        ),
        InkWell(
          onTap: () => setState(() => _consentGiven = !_consentGiven),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(value: _consentGiven, onChanged: (v) => setState(() => _consentGiven = v ?? false), activeColor: Brand.c600),
              Expanded(child: Text(l10n.baselineSurveyConsentCheckbox, style: AppTheme.sans(13, weight: FontWeight.w600))),
            ],
          ),
        ),
        _field(l10n.baselineSurveySignatureLabel, placeholder: l10n.baselineSurveySignaturePlaceholder, controller: _signatureName, textInputAction: TextInputAction.done),
      ]);

  // Every field in every section is required — Next stays disabled until
  // all of a section's fields are filled/selected, not just the final
  // consent step. A "specify" field conditionally shown for an "other(s)"
  // choice is required too, exactly like every other field on the section
  // it belongs to.
  bool _sectionAValid() =>
      _age.text.trim().isNotEmpty &&
      _educationLevel != null &&
      _casteCommunity.text.trim().isNotEmpty &&
      _maritalStatus != null &&
      _householdSize.text.trim().isNotEmpty &&
      _surveyLocation != null &&
      (_surveyLocation != 'other' || _surveyLocationOther.text.trim().isNotEmpty) &&
      _annualIncome.text.trim().isNotEmpty &&
      _primaryIncomeSource.text.trim().isNotEmpty;

  bool _sectionBValid() =>
      _enterpriseType != null &&
      _enterpriseSector != null &&
      (_enterpriseSector != 'others' || _enterpriseSectorOther.text.trim().isNotEmpty) &&
      _yearsInOperation.text.trim().isNotEmpty &&
      _monthlyRevenue.text.trim().isNotEmpty &&
      _employeesCount.text.trim().isNotEmpty &&
      _registrationStatus != null &&
      _marketReach != null;

  bool _sectionCValid() =>
      _ownsSmartphone != null &&
      _internetAccess != null &&
      _internetType != null &&
      (_internetType != 'other' || _internetTypeOther.text.trim().isNotEmpty) &&
      _appsUsed.isNotEmpty &&
      _receivedDigitalTraining != null &&
      _digitalPaymentFrequency != null &&
      _digitalToolsComfort != null;

  bool _sectionDValid() =>
      _hasBankAccount != null &&
      _creditAccess != null &&
      _digitalPaymentUsage != null &&
      _savingsPattern != null &&
      _awareGovtSchemes != null &&
      (_awareGovtSchemes != true || _govtSchemesDetail.text.trim().isNotEmpty);

  bool _sectionEValid() =>
      _businessPlanningKnowledge != null &&
      _recordKeeping != null &&
      _hasInventorySystem != null &&
      _participatedBusinessTraining != null &&
      _onlineMarketingAbility != null &&
      _innovationLevel != null;

  bool _sectionFValid() =>
      _householdDecisionRole != null &&
      _mobility != null &&
      _shgLeadershipRole != null &&
      _techConfidence != null &&
      _communityInfluence != null &&
      _negotiationAbility != null;

  bool _sectionGValid() =>
      _challenge1.text.trim().isNotEmpty &&
      _challenge2.text.trim().isNotEmpty &&
      _challenge3.text.trim().isNotEmpty &&
      _trainingNeeds.isNotEmpty &&
      (!_trainingNeeds.contains('others') || _trainingNeedsOther.text.trim().isNotEmpty) &&
      _supportNeeded.isNotEmpty &&
      _interestedInTrials != null &&
      _expectedBenefit.text.trim().isNotEmpty;

  bool _sectionHValid() =>
      _govtNgoSupportNeeded.isNotEmpty &&
      (!_govtNgoSupportNeeded.contains('others') || _govtNgoSupportOther.text.trim().isNotEmpty);

  List<Widget> _stepFields(AppLocalizations l10n) => switch (_step) {
        0 => _basicInfoFields(l10n),
        1 => _sectionA(l10n),
        2 => _sectionB(l10n),
        3 => _sectionC(l10n),
        4 => _sectionD(l10n),
        5 => _sectionE(l10n),
        6 => _sectionF(l10n),
        7 => _sectionG(l10n),
        8 => _sectionH(l10n),
        _ => _sectionI(l10n),
      };

  String _sectionTitle(AppLocalizations l10n) => switch (_step) {
        1 => l10n.baselineSurveySectionADemographics,
        2 => l10n.baselineSurveySectionBEnterprise,
        3 => l10n.baselineSurveySectionCDigital,
        4 => l10n.baselineSurveySectionDFinancial,
        5 => l10n.baselineSurveySectionEEntrepreneurial,
        6 => l10n.baselineSurveySectionFEmpowerment,
        7 => l10n.baselineSurveySectionGChallenges,
        8 => l10n.baselineSurveySectionHExpectations,
        _ => l10n.baselineSurveySectionIConsent,
      };

  Widget _header(AppLocalizations l10n) {
    if (_step == 0) {
      return Column(children: [
        Container(
          width: 64, height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 100),
          decoration: BoxDecoration(
            color: Brand.c600, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 20),
        Text(l10n.profileSetupTitle, textAlign: TextAlign.center, style: AppTheme.display(22)),
        const SizedBox(height: 6),
        Text(l10n.profileSetupSubtitle, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
        const SizedBox(height: 28),
      ]);
    }
    final sectionOf = l10n.baselineSurveySectionOf(_step, _totalSurveySections);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppProgressBar(value: _step, max: _totalSurveySections, semanticLabel: sectionOf),
        const SizedBox(height: 14),
        Text(l10n.baselineSurveyTitle, style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c600)),
        const SizedBox(height: 2),
        Text(_sectionTitle(l10n), style: AppTheme.display(20)),
        const SizedBox(height: 4),
        Text(sectionOf, style: AppTheme.sans(12, color: Neutral.c500)),
        if (_step == 1) ...[
          const SizedBox(height: 10),
          Text(l10n.baselineSurveyIntro, style: AppTheme.sans(12, color: Neutral.c500)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final firstStep = _surveyOnly ? 1 : 0;
    final isLastStep = _step == 9;
    final canProceed = switch (_step) {
      0 => _name.text.trim().isNotEmpty && _selectedShg != null,
      1 => _sectionAValid(),
      2 => _sectionBValid(),
      3 => _sectionCValid(),
      4 => _sectionDValid(),
      5 => _sectionEValid(),
      6 => _sectionFValid(),
      7 => _sectionGValid(),
      8 => _sectionHValid(),
      _ => _consentGiven && _signatureName.text.trim().isNotEmpty,
    };
    final actionLabel = _saving
        ? (isLastStep ? l10n.baselineSurveySubmitting : l10n.profileSetupSaving)
        : (isLastStep ? l10n.baselineSurveySubmitButton : (_step == 0 ? l10n.profileSetupContinue : l10n.actionNext));
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(l10n),
              ..._stepFields(l10n),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(_error!, style: AppTheme.sans(12, color: Accent.red600))),
              ],
              const SizedBox(height: 24),
              Row(children: [
                if (_step > firstStep) ...[
                  Expanded(
                    child: AppButton(
                      label: l10n.actionBack,
                      variant: ButtonVariant.outline,
                      size: ButtonSize.lg,
                      onPressed: _saving ? null : _retreat,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: actionLabel,
                    fullWidth: true,
                    size: ButtonSize.lg,
                    onPressed: canProceed && !_saving ? (isLastStep ? _submit : _advance) : null,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
