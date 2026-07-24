// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appTitle => 'NavaSakhi';

  @override
  String get navHome => 'హోమ్';

  @override
  String get navMySHG => 'నా SHG';

  @override
  String get navSHGs => 'SHGలు';

  @override
  String get navServices => 'సేవలు';

  @override
  String get navMarket => 'మార్కెట్';

  @override
  String get navProfile => 'ప్రొఫైల్';

  @override
  String get actionSave => 'సేవ్ చేయండి';

  @override
  String get actionCancel => 'రద్దు చేయండి';

  @override
  String get actionAdd => 'జోడించండి';

  @override
  String get actionEdit => 'సవరించండి';

  @override
  String get actionDelete => 'తొలగించండి';

  @override
  String get actionSubmit => 'సమర్పించండి';

  @override
  String get actionRetry => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String get actionSignOut => 'సైన్ అవుట్';

  @override
  String get actionCheckStatus => 'స్థితిని తనిఖీ చేయండి';

  @override
  String get commonLoading => 'లోడ్ అవుతోంది…';

  @override
  String get commonError => 'ఏదో తప్పు జరిగింది';

  @override
  String get commonBack => 'వెనుకకు';

  @override
  String get asyncErrorGeneric =>
      'ఏదో తప్పు జరిగింది. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get asyncErrorNetwork =>
      'మీ ఇంటర్నెట్ కనెక్షన్‌ని తనిఖీ చేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get discardChangesTitle => 'మార్పులను వదిలివేయాలా?';

  @override
  String get discardChangesMessage =>
      'మీరు ఈ పేజీలో నమోదు చేసిన సమాచారం ఇంకా సేవ్ కాలేదు. ఇప్పుడు వెళ్తే అది పోతుంది.';

  @override
  String get discardChangesKeepEditing => 'సవరించడం కొనసాగించండి';

  @override
  String get discardChangesDiscard => 'వదిలివేయండి';

  @override
  String get errorGoHome => 'హోమ్‌కు వెళ్ళండి';

  @override
  String get error404Title => 'పేజీ కనుగొనబడలేదు';

  @override
  String get error404Message =>
      'మీరు వెతుకుతున్న పేజీ లేదు లేదా తరలించబడి ఉండవచ్చు.';

  @override
  String get profileLoadErrorTitle => 'మీ ప్రొఫైల్ లోడ్ కాలేదు';

  @override
  String get qrPermissionDenied => 'కెమెరా అనుమతి తిరస్కరించబడింది.';

  @override
  String get qrUnsupported => 'ఈ పరికరంలో స్కానింగ్‌కు మద్దతు లేదు.';

  @override
  String get qrCameraUnavailable => 'కెమెరా అందుబాటులో లేదు.';

  @override
  String get qrManualFallbackHint =>
      'మీరు ఇప్పటికీ వివరాలను మాన్యువల్‌గా నమోదు చేయవచ్చు.';

  @override
  String get qrEnterManually => 'బదులుగా మాన్యువల్‌గా నమోదు చేయండి';

  @override
  String get qrManualEntry => 'మాన్యువల్ ఎంట్రీ';

  @override
  String get qrTurnOffFlashlight => 'ఫ్లాష్‌లైట్ ఆఫ్ చేయండి';

  @override
  String get qrTurnOnFlashlight => 'ఫ్లాష్‌లైట్ ఆన్ చేయండి';

  @override
  String get qrTakingTooLong => 'కెమెరా ప్రారంభం కావడానికి చాలా సమయం పడుతోంది.';

  @override
  String get qrScanToPayTitle => 'చెల్లించడానికి స్కాన్ చేయండి';

  @override
  String get qrScanToPayInstructions =>
      'మీ కెమెరాను వ్యాపారి UPI QR కోడ్‌పై పాయింట్ చేయండి';

  @override
  String get qrScanAttendanceTitle => 'హాజరు QR స్కాన్ చేయండి';

  @override
  String get qrScanAttendanceInstructions =>
      'మీ కెమెరాను వేదికలో ప్రదర్శించిన QR కోడ్‌పై పాయింట్ చేయండి';

  @override
  String get profileTitle => 'ప్రొఫైల్';

  @override
  String get profileEditProfile => 'ప్రొఫైల్ సవరించండి';

  @override
  String get profileMobile => 'మొబైల్';

  @override
  String get profileVillage => 'గ్రామం';

  @override
  String get profileSHG => 'SHG';

  @override
  String get profileName => 'పేరు';

  @override
  String get profileUpdated => 'ప్రొఫైల్ నవీకరించబడింది';

  @override
  String get profileUpdateDemoMode =>
      'డెమో మోడ్ — సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get profileUpdateError =>
      'మీ ప్రొఫైల్‌ను నవీకరించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get profileNameRequired => 'పేరు అవసరం.';

  @override
  String get settingsTitle => 'సెట్టింగ్‌లు';

  @override
  String get settingsNotifications => 'నోటిఫికేషన్‌లు';

  @override
  String get settingsNotifMeetingReminders => 'సమావేశ రిమైండర్‌లు';

  @override
  String get settingsNotifPaymentAlerts => 'చెల్లింపు హెచ్చరికలు';

  @override
  String get settingsNotifAnnouncements => 'ప్రకటనలు';

  @override
  String get settingsNotifLocalOnly =>
      'రిమైండర్‌లు ఈ పరికరంలో మాత్రమే షెడ్యూల్ చేయబడతాయి — సర్వర్ ద్వారా పంపబడవు. మీరు వేరే ఫోన్ ఉపయోగిస్తే లేదా యాప్‌ను మళ్లీ ఇన్‌స్టాల్ చేస్తే, ఇవి మీకు చేరవు. ఒక సమావేశం రద్దు చేయబడితే, ఈ పరికరం యొక్క రిమైండర్ మాత్రమే వెంటనే రద్దవుతుంది — మరో సభ్యురాలి ఫోన్‌లో ఆమె సమావేశాల ట్యాబ్‌ను మళ్లీ తెరిచే వరకు పాత రిమైండర్ కనిపించవచ్చు.';

  @override
  String get settingsNotifPermissionDenied =>
      'మీ ఫోన్ సెట్టింగ్‌లలో ఈ యాప్ కోసం నోటిఫికేషన్‌లు ఆఫ్‌లో ఉన్నాయి. రిమైండర్‌లు అందుకోవాలంటే వాటిని అక్కడ ఆన్ చేయండి.';

  @override
  String get settingsNotifCancelPendingError =>
      'ఈ పరికరంలో ఈ రిమైండర్‌లను ఆఫ్ చేయలేకపోయాము. మేము స్వయంచాలకంగా మళ్లీ ప్రయత్నిస్తూనే ఉంటాము — దయచేసి మీ కనెక్షన్‌ని తనిఖీ చేయండి, లేదా మళ్లీ ప్రయత్నించండి.';

  @override
  String get settingsLanguage => 'భాష';

  @override
  String get settingsPreviewAs => 'ఇలా చూడండి';

  @override
  String get settingsAppVersion => 'యాప్ వెర్షన్';

  @override
  String get settingsGeneralSection => 'సాధారణం';

  @override
  String get settingsPreviewRoleDescription =>
      'ఈ యాప్ ప్రతి పాత్ర డాష్‌బోర్డ్‌ను చూడటానికి మిమ్మల్ని అనుమతిస్తుంది — ఎప్పుడైనా మార్చుకోవచ్చు.';

  @override
  String get settingsPreferenceError =>
      'ఈ అభిరుచిని సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get settingsRoleSwitchError =>
      'పాత్రను మార్చలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get languageTitle => 'భాష';

  @override
  String get languageSubtitle => 'యాప్ కోసం మీకు ఇష్టమైన భాషను ఎంచుకోండి';

  @override
  String get languageEnglish => 'ఇంగ్లీష్';

  @override
  String get languageTelugu => 'తెలుగు';

  @override
  String get languageHindi => 'హిందీ';

  @override
  String get servicesTitle => 'సేవలు';

  @override
  String get loginTitle => 'తిరిగి స్వాగతం';

  @override
  String get loginSubtitle =>
      'కొనసాగించడానికి మీ నమోదిత మొబైల్ నంబర్‌ను నమోదు చేయండి';

  @override
  String get loginSending => 'పంపుతోంది…';

  @override
  String get loginSendOtp => 'OTP పంపండి';

  @override
  String get loginOtpError =>
      'OTP పంపలేకపోయాము. దయచేసి నంబర్‌ను తనిఖీ చేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get loginDataProtected =>
      'మీ డేటా DAY-NRLM మార్గదర్శకాల ప్రకారం సురక్షితంగా ఉంచబడుతుంది. మేము మీ ఆధార్ వివరాలను ఎప్పుడూ పంచుకోము.';

  @override
  String get loginTermsAgreement =>
      'కొనసాగించడం ద్వారా మీరు సేవా నిబంధనలు & గోప్యతా విధానానికి అంగీకరిస్తున్నారు';

  @override
  String get otpTitle => 'OTP ధృవీకరించండి';

  @override
  String get otpHint => 'మీ ఫోన్‌కు పంపిన 6-అంకెల కోడ్‌ను నమోదు చేయండి';

  @override
  String get otpVerify => 'ధృవీకరించండి';

  @override
  String get otpSentTo => 'మేము 6-అంకెల కోడ్‌ను పంపాము ';

  @override
  String get otpVerifyContinue => 'ధృవీకరించి కొనసాగించండి';

  @override
  String get otpVerifying => 'ధృవీకరిస్తోంది…';

  @override
  String get otpResendIn => 'OTP మళ్ళీ పంపడం ';

  @override
  String get otpResend => 'OTP మళ్ళీ పంపండి';

  @override
  String get otpDidntReceive =>
      'కోడ్ రాలేదా? మీ SMS ఇన్‌బాక్స్‌ను తనిఖీ చేయండి.';

  @override
  String get otpVerifyError =>
      'తప్పు లేదా గడువు ముగిసిన కోడ్. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get otpResendError =>
      'కోడ్‌ను మళ్ళీ పంపలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String otpDigitLabel(int position) {
    return 'OTP అంకె $position, 6లో';
  }

  @override
  String get profileSetupTitle => 'మీ ప్రొఫైల్‌ను సృష్టించండి';

  @override
  String get profileSetupSubtitle =>
      'ప్రారంభించడానికి మీ గురించి కొంచెం చెప్పండి';

  @override
  String get fieldFullName => 'పూర్తి పేరు';

  @override
  String get fieldMandal => 'మండలం';

  @override
  String get fieldDistrict => 'జిల్లా';

  @override
  String get yourShg => 'మీ SHG (ఐచ్ఛికం)';

  @override
  String get searchSelectShg => 'మీ SHGని వెతికి ఎంచుకోండి';

  @override
  String get changeShg => 'మార్చండి';

  @override
  String get profileSetupSaving => 'సేవ్ చేస్తోంది…';

  @override
  String get profileSetupContinue => 'కొనసాగించండి';

  @override
  String get findYourShg => 'మీ SHGని కనుగొనండి';

  @override
  String get searchShgHint => 'SHG పేరు ద్వారా వెతకండి';

  @override
  String get noShgsFound => 'SHGలు కనుగొనబడలేదు';

  @override
  String get roleSelectTitle => 'ఇలా కొనసాగించండి';

  @override
  String get roleSelectSubtitle =>
      'అనుకూలీకరించిన అనుభవం కోసం SHG వ్యవస్థలో మీ పాత్రను ఎంచుకోండి';

  @override
  String get roleSelectSaveError =>
      'మీ పాత్రను సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get dashboardGreeting => 'తిరిగి స్వాగతం';

  @override
  String get shgApprovalWaitingTitle => 'ఆమోదం కోసం వేచి ఉంది';

  @override
  String get shgApprovalWaitingMessage =>
      'మీ చేరిక అభ్యర్థన మీ SHG నాయకుడికి పంపబడింది. ఆమోదం లభించిన తర్వాత మీకు యాక్సెస్ లభిస్తుంది.';

  @override
  String get shgApprovalRejectedTitle => 'అభ్యర్థన ఆమోదించబడలేదు';

  @override
  String get shgApprovalRejectedMessage =>
      'మీ SHG నాయకుడు ఈ అభ్యర్థనను ఆమోదించలేదు. మీరు వేరే SHGని ఎంచుకుని మళ్ళీ ప్రయత్నించవచ్చు.';

  @override
  String get unknownShg => 'తెలియని SHG';

  @override
  String get chooseDifferentShg => 'వేరే SHGని ఎంచుకోండి';

  @override
  String get checkingStatus => 'తనిఖీ చేస్తోంది…';

  @override
  String get shgApprovalCheckError =>
      'స్థితిని తనిఖీ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get voiceNoLoans => 'మీ పేరు మీద ఎలాంటి రుణాలు లేవు.';

  @override
  String voiceNoActiveLoans(int count) {
    return 'మీ పేరు మీద మొత్తం $count రుణాలు ఉన్నాయి, కానీ వాటిలో ఏదీ ప్రస్తుతం క్రియాశీలంగా లేదు.';
  }

  @override
  String voiceLoanActive(String purpose, String amount, String outstanding) {
    return '$purpose: ₹$amount రుణం, ₹$outstanding ఇంకా చెల్లించాల్సి ఉంది.';
  }

  @override
  String voiceSavingsThisMonth(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'సార్లు',
      one: 'సారి',
    );
    return 'ఈ నెల మీరు $count $_temp0 పొదుపు చేసారు, మొత్తం ₹$amount.';
  }

  @override
  String get voiceNoAnnouncements => 'మీకు ఎలాంటి ప్రకటనలు లేవు.';

  @override
  String get voiceOpeningSavingsForm =>
      'మీ కోసం పొదుపు ఎంట్రీ ఫారమ్ తెరవబడుతోంది.';

  @override
  String get voiceUnknownCommand => 'క్షమించండి, అది నాకు అర్థం కాలేదు.';

  @override
  String get aiDisclaimer =>
      'ఈ సలహా AI ద్వారా రూపొందించబడింది మరియు తప్పుగా ఉండవచ్చు. ఇది వృత్తిపరమైన ఆర్థిక, న్యాయ లేదా వైద్య సలహా కాదు; ముఖ్యమైన నిర్ణయాలు తీసుకునే ముందు మీ SHG నాయకుడిని లేదా అర్హతగల సలహాదారుని సంప్రదించండి.';

  @override
  String get adminDashboardJustNow => 'ఇప్పుడే';

  @override
  String adminDashboardMinutesAgo(int count) {
    return '$count నిమిషాల క్రితం';
  }

  @override
  String adminDashboardHoursAgo(int count) {
    return '$count గంటల క్రితం';
  }

  @override
  String adminDashboardDaysAgo(int count) {
    return '$count రోజుల క్రితం';
  }

  @override
  String adminDashboardMonthsAgo(int count) {
    return '$count నెలల క్రితం';
  }

  @override
  String get adminDashboardTotalShgsLabel => 'మొత్తం SHGలు';

  @override
  String adminDashboardActiveMembersTrend(int count) {
    return '$count మంది సభ్యులు';
  }

  @override
  String get adminDashboardSystemUptimeLabel => 'సిస్టమ్ అప్‌టైమ్';

  @override
  String get adminDashboardHeartbeatHealthy => 'ఆరోగ్యంగా ఉంది';

  @override
  String get adminDashboardHeartbeatStale => 'పాతది';

  @override
  String adminDashboardHeartbeatTrend(String time) {
    return 'హార్ట్‌బీట్: $time';
  }

  @override
  String get adminDashboardHeartbeatPending => 'ఇంకా హార్ట్‌బీట్ నమోదు కాలేదు';

  @override
  String get adminDashboardUsersTile => 'వినియోగదారులు';

  @override
  String get adminDashboardShgsTile => 'SHGలు';

  @override
  String get adminDashboardSchemesTile => 'పథకాలు';

  @override
  String get adminDashboardMonitoringTile => 'పర్యవేక్షణ';

  @override
  String get adminDashboardReportsTile => 'నివేదికలు';

  @override
  String adminDashboardPendingReviewCount(int count) {
    return '$count పథక దరఖాస్తులు సమీక్ష కోసం పెండింగ్‌లో ఉన్నాయి';
  }

  @override
  String get adminDashboardAwaitingReviewSubtitle =>
      'సిబ్బంది ఆమోదం లేదా తిరస్కరణ కోసం వేచి ఉంది';

  @override
  String get adminDashboardReviewAction => 'సమీక్షించండి';

  @override
  String get adminDashboardPlatformSnapshotTitle => 'ప్లాట్‌ఫారమ్ స్నాప్‌షాట్';

  @override
  String get adminDashboardAnalyticsAction => 'అనలిటిక్స్';

  @override
  String get adminDashboardLoansDisbursedLabel => 'పంపిణీ చేసిన రుణాలు';

  @override
  String get adminDashboardTrainingCompletionLabel => 'శిక్షణ పూర్తి';

  @override
  String get adminDashboardRecentActivityTitle => 'ఇటీవలి సిస్టమ్ కార్యాచరణ';

  @override
  String get adminDashboardNoRecentActivity => 'ఇంకా ఇటీవలి కార్యాచరణ లేదు';

  @override
  String get clfDashboardVillageOrgsLabel => 'గ్రామ సంస్థలు';

  @override
  String clfDashboardShgsTotalTrend(int count) {
    return 'మొత్తం $count SHGలు';
  }

  @override
  String get clfDashboardTotalSavingsLabel => 'మొత్తం పొదుపు';

  @override
  String get clfDashboardFinancialOversightTrend => 'ఆర్థిక పర్యవేక్షణ';

  @override
  String get clfDashboardMonitorVillageOrgsTitle =>
      'గ్రామ సంస్థలను పర్యవేక్షించండి';

  @override
  String clfDashboardVillagesShgsSummary(int villageCount, int shgCount) {
    return '$villageCount గ్రామాలు · $shgCount SHGలు';
  }

  @override
  String get clfDashboardVillageWiseShgsTitle => 'గ్రామాల వారీగా SHGలు';

  @override
  String get clfDashboardFederationReportsAction => 'సమాఖ్య నివేదికలు';

  @override
  String get clfDashboardNoVillagesYet => 'ఇంకా గ్రామాలు లేవు';

  @override
  String clfDashboardShgChartSemanticLabel(String summary) {
    return 'గ్రామాల వారీగా SHGల బార్ చార్ట్: $summary';
  }

  @override
  String clfDashboardShgChartItemLabel(String village, int count) {
    return '$villageలో $count SHGలు';
  }

  @override
  String get clfDashboardFinancialOversightTitle => 'ఆర్థిక పర్యవేక్షణ';

  @override
  String get clfDashboardLoansDisbursedLabel => 'పంపిణీ చేసిన రుణాలు';

  @override
  String get clfDashboardRecoveryRateLabel => 'వసూలు రేటు';

  @override
  String get clfDashboardFullAnalyticsTitle => 'పూర్తి అనలిటిక్స్ డాష్‌బోర్డ్';

  @override
  String get clfDashboardFullAnalyticsSubtitle =>
      'KPIలు, ట్రెండ్‌లు & రికవరీ ఇన్‌సైట్‌లు';

  @override
  String get clfDashboardOpenAction => 'తెరవండి';

  @override
  String get crpDashboardShgsMonitoredLabel => 'పర్యవేక్షణలో ఉన్న SHGలు';

  @override
  String get crpDashboardNoShgsYetTrend => 'ఇంకా SHGలు లేవు';

  @override
  String get crpDashboardAvgHealthScoreLabel => 'సగటు హెల్త్ స్కోర్';

  @override
  String get crpDashboardAttendanceProxyTrend => 'హాజరు ఆధారంగా అంచనా';

  @override
  String get crpDashboardShgsUnderMonitoringTitle => 'పర్యవేక్షణలో ఉన్న SHGలు';

  @override
  String get crpDashboardViewAllAction => 'అన్నీ చూడండి';

  @override
  String get crpDashboardNoShgsToMonitorYet =>
      'పర్యవేక్షణ కోసం ఇంకా SHGలు లేవు';

  @override
  String crpDashboardShgVillageMembersSummary(String village, int count) {
    return '$village · $count మంది సభ్యులు';
  }

  @override
  String get crpDashboardTrainingCatalogTitle => 'శిక్షణ జాబితా';

  @override
  String get crpDashboardNoCoursesYet => 'ఇంకా కోర్సులు లేవు';

  @override
  String dashboardTopBarGreeting(String name) {
    return 'నమస్కారం, $name 🙏';
  }

  @override
  String dashboardTopBarUnreadAnnouncementsTooltip(int count) {
    return '$count చదవని ప్రకటనలు';
  }

  @override
  String get dashboardTopBarAnnouncementsTooltip => 'ప్రకటనలు';

  @override
  String get leaderDashboardGroupSavingsLabel => 'గ్రూప్ పొదుపు';

  @override
  String leaderDashboardMembersTrend(int count) {
    return '$count మంది సభ్యులు';
  }

  @override
  String get leaderDashboardLoansOutstandingLabel => 'బకాయి రుణాలు';

  @override
  String leaderDashboardOverdueTrend(int count) {
    return '$count గడువు మీరిన';
  }

  @override
  String get leaderDashboardMembersTile => 'సభ్యులు';

  @override
  String get leaderDashboardApprovalsTile => 'ఆమోదాలు';

  @override
  String leaderDashboardApprovalsPendingBadge(int count) {
    return 'ఆమోదాలు, $count పెండింగ్‌లో';
  }

  @override
  String get leaderDashboardScheduleTile => 'షెడ్యూల్';

  @override
  String get leaderDashboardReportsTile => 'నివేదికలు';

  @override
  String leaderDashboardDefaulterAlert(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'డిఫాల్టర్ హెచ్చరికలు',
      one: 'డిఫాల్టర్ హెచ్చరిక',
    );
    return '$count $_temp0';
  }

  @override
  String leaderDashboardEmiOverdueSinceDate(String name, String date) {
    return '$name — EMI $date నుండి గడువు మీరింది';
  }

  @override
  String leaderDashboardEmiOverdue(String name) {
    return '$name — EMI గడువు మీరింది';
  }

  @override
  String get leaderDashboardViewAction => 'చూడండి';

  @override
  String get leaderDashboardPendingApprovalsTitle =>
      'పెండింగ్‌లో ఉన్న రుణ ఆమోదాలు';

  @override
  String get leaderDashboardReviewAllAction => 'అన్నీ సమీక్షించండి';

  @override
  String get leaderDashboardNoPendingLoans => 'పెండింగ్‌లో రుణ అభ్యర్థనలు లేవు';

  @override
  String get leaderDashboardNextMeetingTitle => 'తదుపరి సమావేశం';

  @override
  String get leaderDashboardManageAction => 'నిర్వహించండి';

  @override
  String get leaderDashboardMeetingFallback => 'సమావేశం';

  @override
  String get leaderDashboardShgHealthTitle => 'SHG ఆరోగ్యం';

  @override
  String get leaderDashboardGradingLabel => 'గ్రేడింగ్';

  @override
  String get leaderDashboardAttendanceLabel => 'హాజరు';

  @override
  String get leaderDashboardRecoveryLabel => 'రికవరీ';

  @override
  String get memberDashboardMySavingsLabel => 'నా పొదుపు';

  @override
  String memberDashboardSavingsEntriesTrend(int count) {
    return '$count ఎంట్రీలు';
  }

  @override
  String get memberDashboardOutstandingLoanLabel => 'బకాయి రుణం';

  @override
  String memberDashboardNextEmiTrend(String date) {
    return 'తదుపరి EMI $date';
  }

  @override
  String get memberDashboardNoDuesTrend => 'బాకీలు లేవు';

  @override
  String get memberDashboardAddSavingsTile => 'పొదుపు జోడించండి';

  @override
  String get memberDashboardApplyLoanTile => 'రుణం కోసం దరఖాస్తు చేయండి';

  @override
  String get memberDashboardAttendanceLabel => 'హాజరు';

  @override
  String get memberDashboardSchemesTile => 'పథకాలు';

  @override
  String memberDashboardSchemesNewBadge(int count) {
    return 'పథకాలు, $count కొత్తవి';
  }

  @override
  String memberDashboardNewSchemesCount(int count) {
    return '$count కొత్తవి';
  }

  @override
  String get memberDashboardSchemesAvailableLabel => 'అందుబాటులో ఉన్న పథకాలు';

  @override
  String get memberDashboardSavingsSummaryTitle => 'పొదుపు సారాంశం';

  @override
  String get memberDashboardViewAllAction => 'అన్నీ చూడండి';

  @override
  String get memberDashboardLoanSummaryTitle => 'రుణ సారాంశం';

  @override
  String get memberDashboardTrackAction => 'ట్రాక్ చేయండి';

  @override
  String memberDashboardOfAmount(String amount) {
    return '₹$amountలో';
  }

  @override
  String memberDashboardEmiDueBadge(String amount, String date) {
    return 'EMI ₹$amount, $dateన చెల్లించాలి';
  }

  @override
  String memberDashboardEmiBadge(String amount) {
    return 'EMI ₹$amount';
  }

  @override
  String get memberDashboardPayNowAction => 'ఇప్పుడే చెల్లించండి';

  @override
  String get memberDashboardMeetingAlertLabel => 'సమావేశ హెచ్చరిక';

  @override
  String get memberDashboardMeetingFallback => 'సమావేశం';

  @override
  String get memberDashboardDetailsAction => 'వివరాలు';

  @override
  String get memberDashboardTrainingAlertLabel => 'శిక్షణ హెచ్చరిక';

  @override
  String get memberDashboardContinueAction => 'కొనసాగించండి';

  @override
  String get memberDashboardAiAdvisorTitle => 'AI ఆర్థిక సలహాదారు';

  @override
  String get memberDashboardAiAdvisorSubtitle =>
      'పొదుపు, రుణాలు & బడ్జెట్ గురించి అడగండి';

  @override
  String get memberDashboardViewAction => 'చూడండి';

  @override
  String get memberDashboardRecentAnnouncementsTitle => 'ఇటీవలి ప్రకటనలు';

  @override
  String get memberDashboardSeeAllAction => 'అన్నీ చూడండి';

  @override
  String get memberDashboardNoAnnouncementsYet => 'ఇంకా ప్రకటనలు లేదు';

  @override
  String get memberDashboardUnreadLabel => 'చదవని';

  @override
  String memberDashboardSavingsTrendChartSemanticLabel(String summary) {
    return 'పొదుపు ట్రెండ్ చార్ట్: $summary';
  }

  @override
  String get attendanceReportTitle => 'హాజరు నివేదిక';

  @override
  String get attendanceReportEmpty => 'ఇంకా ఏ సమావేశం పూర్తి కాలేదు';

  @override
  String get attendanceReportOverallLabel => 'మొత్తం హాజరు';

  @override
  String attendanceReportSummary(int present, int total) {
    return '$total సమావేశాల్లో $present సమావేశాలకు హాజరు';
  }

  @override
  String get federationGrowthTitle => 'పొదుపు వృద్ధి';

  @override
  String get federationGrowthEmpty => 'ఇంకా ఎలాంటి పొదుపు నమోదు కాలేదు';

  @override
  String get federationGrowthSubtitle => 'ప్రతి SHGలో నెలవారీ మొత్తం పొదుపు';

  @override
  String get federationRecoveryTitle => 'రుణ వసూలు';

  @override
  String get federationRecoveryLoansDisbursed => 'పంపిణీ చేసిన రుణాలు';

  @override
  String get federationRecoveryRateLabel => 'వసూలు రేటు';

  @override
  String get federationRecoveryRecoveredLabel => 'వసూలైంది';

  @override
  String get federationRecoveryFootnote =>
      'ప్రతి SHGలోని క్రియాశీల, బకాయి & మూసివేసిన రుణాలలో';

  @override
  String get federationReportsTitle => 'సమాఖ్య నివేదికలు';

  @override
  String get federationReportsVillagesTitle => 'గ్రామాల వారీగా SHGలు';

  @override
  String get federationReportsVillagesSubtitle =>
      'గ్రామానికి SHG సంఖ్య & పొదుపు';

  @override
  String get federationReportsRecoveryTitle => 'రుణ వసూలు';

  @override
  String get federationReportsRecoverySubtitle =>
      'ప్రతి SHGలో పంపిణీ చేసినది vs. తిరిగి చెల్లించినది';

  @override
  String get federationReportsGrowthTitle => 'పొదుపు వృద్ధి';

  @override
  String get federationReportsGrowthSubtitle =>
      'నెలవారీ పొదుపు ధోరణి, సమాఖ్య మొత్తంలో';

  @override
  String get federationVillagesTitle => 'గ్రామాల వారీగా SHGలు';

  @override
  String get federationVillagesEmpty => 'ఇంకా ఏ SHG నమోదు కాలేదు';

  @override
  String federationVillagesShgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SHGలు',
      one: 'SHG',
    );
    return '$count $_temp0';
  }

  @override
  String get loanStatementTitle => 'రుణ స్టేట్‌మెంట్';

  @override
  String get loanStatementEmpty => 'స్టేట్‌మెంట్ కోసం ఇంకా రుణాలు లేవు';

  @override
  String get loanStatementTotalOutstandingLabel => 'మొత్తం బాకీ';

  @override
  String loanStatementLoanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'రుణాలు',
      one: 'రుణం',
    );
    return '$count $_temp0';
  }

  @override
  String loanStatementRepaidAmount(String amount) {
    return 'తిరిగి చెల్లించినది ₹$amount';
  }

  @override
  String loanStatementAmountLabel(String amount) {
    return 'మొత్తం ₹$amount';
  }

  @override
  String loanStatementOutstandingAmount(String amount) {
    return 'బాకీ ₹$amount';
  }

  @override
  String loanStatementDisbursedOn(String date) {
    return 'పంపిణీ చేయబడింది $date';
  }

  @override
  String get memberReportTitle => 'నా నివేదికలు';

  @override
  String get memberReportTotalSavingsLabel => 'మొత్తం పొదుపు';

  @override
  String memberReportEntriesTrend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఎంట్రీలు',
      one: 'ఎంట్రీ',
    );
    return '$count $_temp0';
  }

  @override
  String get memberReportLoanOutstandingLabel => 'బాకీ రుణం';

  @override
  String memberReportActiveLoansTrend(int count) {
    return '$count క్రియాశీల';
  }

  @override
  String get memberReportSectionTitle => 'నివేదికలు';

  @override
  String get memberReportSavingsStatementTitle => 'పొదుపు స్టేట్‌మెంట్';

  @override
  String get memberReportSavingsStatementSubtitle =>
      'ప్రతి పొదుపు ఎంట్రీతో నడుస్తున్న బ్యాలెన్స్';

  @override
  String get memberReportLoanStatementTitle => 'రుణ స్టేట్‌మెంట్';

  @override
  String get memberReportLoanStatementSubtitle =>
      'ప్రతి రుణం, EMI షెడ్యూల్ & బాకీ మొత్తం';

  @override
  String get memberReportAttendanceTitle => 'హాజరు నివేదిక';

  @override
  String memberReportAttendanceSubtitle(String pct, int present, int total) {
    return '$pct% · $totalలో $present సమావేశాలు';
  }

  @override
  String get reportsHubTitle => 'నివేదికలు';

  @override
  String get reportsHubMyReportsTitle => 'నా నివేదికలు';

  @override
  String get reportsHubMyReportsSubtitle => 'మీ పొదుపు, రుణాలు & హాజరు సారాంశం';

  @override
  String get reportsHubShgReportsTitle => 'SHG నివేదికలు';

  @override
  String get reportsHubShgReportsSubtitle =>
      'గ్రూప్ మొత్తం పొదుపు, రుణాలు & హాజరు';

  @override
  String get reportsHubFederationReportsTitle => 'సమాఖ్య నివేదికలు';

  @override
  String get reportsHubFederationReportsSubtitle => 'ప్రతి SHG డేటా అంతా కలిపి';

  @override
  String get shgFinancialSummaryTitle => 'ఆర్థిక సారాంశం';

  @override
  String get shgFinancialSummaryMembersLabel => 'సభ్యులు';

  @override
  String get shgFinancialSummaryActiveLoansLabel => 'క్రియాశీల రుణాలు';

  @override
  String get shgFinancialSummaryTotalSavingsLabel => 'మొత్తం పొదుపు';

  @override
  String get shgFinancialSummaryLoanOutstandingLabel => 'బాకీ రుణం';

  @override
  String get shgFinancialSummaryAvgAttendanceLabel => 'సగటు హాజరు';

  @override
  String get shgPerformanceReportTitle => 'పనితీరు నివేదిక';

  @override
  String get shgPerformanceAvgAttendanceLabel => 'సగటు హాజరు';

  @override
  String get shgPerformanceActiveLoansLabel => 'క్రియాశీల రుణాలు';

  @override
  String get shgPerformanceAttendanceTrendLabel => 'హాజరు ధోరణి';

  @override
  String get shgPerformanceEmptyTrend => 'ఇంకా ఏ సమావేశం పూర్తి కాలేదు';

  @override
  String get shgReportsTitle => 'SHG నివేదికలు';

  @override
  String get shgReportsFinancialSummaryTitle => 'ఆర్థిక సారాంశం';

  @override
  String get shgReportsFinancialSummarySubtitle =>
      'ఒక చూపులో పొదుపు, రుణాలు & హాజరు';

  @override
  String get shgReportsAuditReportTitle => 'ఆడిట్ నివేదిక';

  @override
  String get shgReportsAuditReportSubtitle =>
      'అంతర్గత మరియు బాహ్య ఆడిట్ రికార్డు';

  @override
  String get shgReportsPerformanceReportTitle => 'పనితీరు నివేదిక';

  @override
  String get shgReportsPerformanceReportSubtitle =>
      'హాజరు ధోరణి & రుణ కార్యకలాపాలు';

  @override
  String get addProductTitle => 'ఉత్పత్తిని జోడించండి';

  @override
  String get addProductImageTooLarge =>
      'చిత్రం చాలా పెద్దదిగా ఉంది — దయచేసి 5 MB కంటే తక్కువ ఉన్నదాన్ని ఎంచుకోండి';

  @override
  String get addProductAddPhotoOptional => 'ఒక ఫోటో జోడించండి (ఐచ్ఛికం)';

  @override
  String get addProductNameLabel => 'ఉత్పత్తి పేరు';

  @override
  String get addProductNameHint => 'ఉదా: చేతితో నేసిన కాటన్ చీర';

  @override
  String get addProductDescriptionLabel => 'వివరణ';

  @override
  String get addProductDescriptionHint => 'మీ ఉత్పత్తి గురించి వివరించండి';

  @override
  String get addProductPriceLabel => 'ధర (₹)';

  @override
  String get addProductStockLabel => 'స్టాక్';

  @override
  String get addProductCategoryLabel => 'వర్గం';

  @override
  String get addProductNameRequired => 'ఉత్పత్తి పేరు నమోదు చేయండి';

  @override
  String get addProductInvalidPrice => 'సరైన ధరను నమోదు చేయండి';

  @override
  String get addProductPriceTooLarge =>
      'ధర అసాధారణంగా ఎక్కువగా ఉన్నట్టు అనిపిస్తోంది — దయచేసి తనిఖీ చేసి మళ్ళీ నమోదు చేయండి';

  @override
  String get addProductSubmitError =>
      'ఈ ఉత్పత్తిని జాబితా చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get addProductListedSuccess => 'ఉత్పత్తి జాబితా చేయబడింది';

  @override
  String get addProductDemoModeNotSaved =>
      'డెమో మోడ్ — ఉత్పత్తి సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get addProductListingInProgress => 'జాబితా చేస్తోంది…';

  @override
  String get addProductSubmitButton => 'ఉత్పత్తిని జాబితా చేయండి';

  @override
  String get marketplaceHomeTitle => 'మార్కెట్';

  @override
  String get marketplaceHomeAddProductTooltip => 'ఉత్పత్తిని జోడించండి';

  @override
  String get marketplaceHomeSellTile => 'అమ్మండి';

  @override
  String get marketplaceHomeOrdersTile => 'ఆర్డర్లు';

  @override
  String get marketplaceHomeReviewsTile => 'సమీక్షలు';

  @override
  String get marketplaceHomeBrowseProducts => 'ఉత్పత్తులను చూడండి';

  @override
  String get marketplaceHomeEmptyProducts => 'ఇంకా ఉత్పత్తులు జాబితా చేయబడలేదు';

  @override
  String get marketplaceOrdersTitle => 'ఆర్డర్లు';

  @override
  String get marketplaceOrdersEmpty => 'ఇంకా ఆర్డర్లు లేవు';

  @override
  String get marketplaceReviewsTitle => 'సమీక్షలు';

  @override
  String get marketplaceReviewsEmpty => 'మీ ఉత్పత్తులపై ఇంకా సమీక్షలు లేవు';

  @override
  String marketplaceReviewsFromCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'సమీక్షల',
      one: 'సమీక్ష',
    );
    return '$count $_temp0 ఆధారంగా';
  }

  @override
  String marketplaceReviewsRatingSemantics(int rating) {
    return '5లో $rating నక్షత్రాలు';
  }

  @override
  String get orderDetailTitle => 'ఆర్డర్ వివరాలు';

  @override
  String get orderDetailNotFound => 'ఈ ఆర్డర్ కనుగొనబడలేదు';

  @override
  String get orderDetailUpdateStatusError =>
      'ఆర్డర్ స్థితిని నవీకరించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get orderDetailUpdateStatusLabel => 'స్థితిని నవీకరించండి';

  @override
  String orderDetailBuyerLabel(String name) {
    return 'కొనుగోలుదారు: $name';
  }

  @override
  String orderDetailOrderedOn(String date) {
    return '$dateన ఆర్డర్ చేయబడింది';
  }

  @override
  String get productDetailTitle => 'ఉత్పత్తి';

  @override
  String get productDetailNotFound => 'ఈ ఉత్పత్తి కనుగొనబడలేదు';

  @override
  String get productDetailWriteReviewTitle => 'సమీక్ష రాయండి';

  @override
  String productDetailStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'నక్షత్రాలు',
      one: 'నక్షత్రం',
    );
    return '$count $_temp0';
  }

  @override
  String get productDetailReviewHint =>
      'ఈ ఉత్పత్తితో మీ అనుభవాన్ని పంచుకోండి (ఐచ్ఛికం)';

  @override
  String get productDetailReviewSubmitted => 'సమీక్ష సమర్పించబడింది';

  @override
  String get productDetailReviewDemoMode =>
      'డెమో మోడ్ — సమీక్ష సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get productDetailReviewSubmitError =>
      'మీ సమీక్షను సమర్పించలేకపోయాము. మీరు ముందుగా ఈ ఉత్పత్తిని కొనుగోలు చేయాల్సి రావచ్చు.';

  @override
  String get productDetailOrderPlaced => 'ఆర్డర్ చేయబడింది';

  @override
  String get productDetailOrderDemoMode =>
      'డెమో మోడ్ — ఆర్డర్ సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get productDetailOrderPlaceError =>
      'ఈ ఆర్డర్‌ను చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String productDetailBySeller(String name) {
    return '$name ద్వారా';
  }

  @override
  String productDetailInStock(int count) {
    return 'స్టాక్‌లో $count';
  }

  @override
  String get productDetailReviewsSection => 'సమీక్షలు';

  @override
  String get productDetailSubmittingAction => 'సమర్పిస్తోంది…';

  @override
  String get productDetailWriteReviewAction => 'సమీక్ష రాయండి';

  @override
  String get productDetailNoReviewsYet => 'ఇంకా సమీక్షలు లేవు';

  @override
  String productDetailReviewRatingSemantics(int rating) {
    return '5లో $rating నక్షత్రాలు';
  }

  @override
  String get productDetailPlacingInProgress => 'ఆర్డర్ చేస్తోంది…';

  @override
  String get productDetailPlaceOrderButton => 'ఆర్డర్ చేయండి';

  @override
  String get meetingsHomeTitle => 'సమావేశాలు';

  @override
  String get meetingsHomeScheduleTooltip => 'సమావేశాన్ని షెడ్యూల్ చేయండి';

  @override
  String get meetingsHomeCheckIn => 'చెక్-ఇన్';

  @override
  String get meetingsHomeScheduleLabel => 'షెడ్యూల్';

  @override
  String get meetingsHomeAttendanceLabel => 'హాజరు';

  @override
  String get meetingsHomeUpcoming => 'రాబోయే';

  @override
  String get meetingsHomePastMeetings => 'గత సమావేశాలు';

  @override
  String get meetingsHomeNoPastMeetings => 'ఇంకా గత సమావేశాలు లేవు';

  @override
  String get meetingsHomeDefaultTitle => 'సమావేశం';

  @override
  String get meetingDetailTitle => 'సమావేశ వివరాలు';

  @override
  String get meetingDetailNotFound => 'ఈ సమావేశం కనుగొనబడలేదు';

  @override
  String get meetingDetailDefaultTitle => 'సమావేశం';

  @override
  String get meetingDetailMinutesLabel => 'సమావేశ నివేదిక';

  @override
  String get meetingDetailCancelDialogTitle => 'సమావేశాన్ని రద్దు చేయాలా?';

  @override
  String meetingDetailCancelDialogContent(String date) {
    return 'ఇది $date సమావేశాన్ని రద్దుగా గుర్తిస్తుంది. సభ్యులకు ఇది రాబోయేదిగా కాకుండా రద్దైనదిగా కనిపిస్తుంది.';
  }

  @override
  String get meetingDetailKeepMeeting => 'సమావేశాన్ని ఉంచండి';

  @override
  String get meetingDetailCancelMeeting => 'సమావేశాన్ని రద్దు చేయండి';

  @override
  String get meetingDetailCancelling => 'రద్దు అవుతోంది…';

  @override
  String get meetingDetailCancelledSuccess => 'సమావేశం రద్దయింది';

  @override
  String get meetingDetailCancelledDemoMode =>
      'డెమో మోడ్ — ఈ సెషన్ మిగిలిన సమయానికి రద్దు చేయబడింది (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get meetingDetailCancelError =>
      'సమావేశాన్ని రద్దు చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get meetingDetailAttendanceSection => 'హాజరు';

  @override
  String get meetingDetailMarkAction => 'నమోదు చేయండి';

  @override
  String meetingDetailPresentCount(int present, int total) {
    return '$present / $total హాజరు';
  }

  @override
  String get meetingAttendanceTitle => 'హాజరు';

  @override
  String get meetingAttendanceNoMeetings =>
      'హాజరు నమోదు చేయడానికి సమావేశాలు లేవు';

  @override
  String get meetingAttendanceNoMembers => 'హాజరు నమోదు చేయడానికి సభ్యులు లేరు';

  @override
  String meetingAttendancePresentCount(int present, int total) {
    return '$present / $total హాజరు';
  }

  @override
  String get meetingAttendanceUpdateError =>
      'హాజరును నవీకరించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get meetingMomTitle => 'సమావేశ నివేదిక';

  @override
  String get meetingMomNotFound => 'ఈ సమావేశం కనుగొనబడలేదు';

  @override
  String get meetingMomDemoModeNotSaved =>
      'డెమో మోడ్ — సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get meetingMomSaveDecisionError =>
      'ఈ నిర్ణయాన్ని సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get meetingMomSaveActionItemError =>
      'ఈ పనిని సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get meetingMomDecisionsSection => 'నిర్ణయాలు';

  @override
  String get meetingMomNoDecisions => 'ఇంకా ఏ నిర్ణయం నమోదు కాలేదు';

  @override
  String get meetingMomAddDecisionHint => 'ఒక నిర్ణయాన్ని జోడించండి…';

  @override
  String get meetingMomAddDecisionTooltip => 'నిర్ణయం జోడించండి';

  @override
  String get meetingMomActionItemsSection => 'పనులు';

  @override
  String get meetingMomNoActionItems => 'ఇంకా ఏ పని లేదు';

  @override
  String get meetingMomUpdateActionItemError =>
      'ఈ పనిని నవీకరించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String meetingMomAssignedTo(String name) {
    return '$nameకి అప్పగించబడింది';
  }

  @override
  String meetingMomDueDate(String date) {
    return 'చివరి తేదీ: $date';
  }

  @override
  String get meetingMomAssignToLabel => 'అప్పగించండి';

  @override
  String get meetingMomUnassigned => 'ఎవరూ లేరు';

  @override
  String get meetingMomAddTaskHint => 'ఒక పనిని జోడించండి…';

  @override
  String get meetingMomAddActionItemTooltip => 'పని జోడించండి';

  @override
  String get meetingScheduleTitle => 'సమావేశాన్ని షెడ్యూల్ చేయండి';

  @override
  String get meetingScheduleSubmitting => 'షెడ్యూల్ అవుతోంది…';

  @override
  String get meetingScheduleEnterVenueError => 'వేదికను నమోదు చేయండి';

  @override
  String get meetingScheduleNoShgError =>
      'మీరు ఏ SHGకి అనుసంధానించబడలేదు, కాబట్టి ఈ సమావేశాన్ని షెడ్యూల్ చేయడానికి ఏమీ లేదు.';

  @override
  String get meetingScheduleSuccess => 'సమావేశం షెడ్యూల్ చేయబడింది';

  @override
  String get meetingScheduleDemoMode =>
      'డెమో మోడ్ — సమావేశం సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get meetingScheduleError =>
      'సమావేశాన్ని షెడ్యూల్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get meetingScheduleDateLabel => 'తేదీ';

  @override
  String get meetingScheduleTimeLabel => 'సమయం';

  @override
  String get meetingScheduleVenueLabel => 'వేదిక';

  @override
  String get meetingScheduleVenueHint => 'ఉదా. అంగన్‌వాడీ కేంద్రం, కొండాపూర్';

  @override
  String get meetingScheduleAgendaLabel => 'ఎజెండా';

  @override
  String get meetingScheduleAgendaHint =>
      'ఉదా. నెలవారీ పొదుపు సమీక్ష మరియు రుణ దరఖాస్తులు';

  @override
  String get savingsEntryTitle => 'పొదుపు జోడించండి';

  @override
  String get savingsEntryMemberLabel => 'సభ్యురాలు';

  @override
  String get savingsEntryNoMembersFound =>
      'మీ SHGలో ఇంకా సభ్యులు లేరు — ఈ ఎంట్రీని ఎవరి పేరు మీద నమోదు చేయాలో లేదు.';

  @override
  String get savingsEntrySelectMember => 'ఒక సభ్యురాలిని ఎంచుకోండి';

  @override
  String get savingsEntryAmountLabel => 'మొత్తం';

  @override
  String get savingsEntryAmountRequired => 'మొత్తాన్ని నమోదు చేయండి';

  @override
  String get savingsEntryAmountInvalid => 'సరైన సంఖ్యను నమోదు చేయండి';

  @override
  String get savingsEntryAmountZero => 'మొత్తం సున్నా కంటే ఎక్కువ ఉండాలి';

  @override
  String get savingsEntryAmountTooLarge =>
      'ఈ మొత్తం అసాధారణంగా ఎక్కువగా ఉంది — దయచేసి తనిఖీ చేసి మళ్ళీ నమోదు చేయండి';

  @override
  String get savingsEntryPaymentModeLabel => 'చెల్లింపు విధానం';

  @override
  String get savingsEntryFrequencyLabel => 'ఎంత తరచుగా';

  @override
  String get savingsEntryNoShgError =>
      'మీరు ఏ SHGకి అనుసంధానించబడలేదు, కాబట్టి ఈ ఎంట్రీని నమోదు చేయడానికి ఏమీ లేదు.';

  @override
  String get savingsEntrySubmittedMessage =>
      'పొదుపు ఎంట్రీ ధృవీకరణ కోసం పంపబడింది';

  @override
  String get savingsEntryDemoModeMessage =>
      'డెమో మోడ్ — ఎంట్రీ సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get savingsEntrySaveError =>
      'ఈ ఎంట్రీని సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get savingsEntrySaving => 'సేవ్ చేస్తోంది…';

  @override
  String get savingsEntrySubmit => 'ఎంట్రీని సమర్పించండి';

  @override
  String get savingsGroupReportTitle => 'గ్రూప్ పొదుపు నివేదిక';

  @override
  String get savingsGroupReportEmpty => 'ఇంకా గ్రూప్ పొదుపు డేటా లేదు';

  @override
  String get savingsGroupReportTotalLabel => 'గ్రూప్ మొత్తం';

  @override
  String savingsGroupReportSummary(int memberCount, int monthCount) {
    String _temp0 = intl.Intl.pluralLogic(
      monthCount,
      locale: localeName,
      other: 'నెలలు',
      one: 'నెల',
    );
    return '$memberCount మంది సభ్యులు సహకరిస్తున్నారు · $monthCount $_temp0 కార్యకలాపం';
  }

  @override
  String savingsGroupReportRank(int rank) {
    return 'ర్యాంక్ #$rank';
  }

  @override
  String get savingsHistoryTitle => 'పొదుపు చరిత్ర';

  @override
  String get savingsHistoryEmpty => 'ఇంకా పొదుపు చరిత్ర లేదు';

  @override
  String savingsFrequencyEntryTitle(String frequency) {
    return '$frequency పొదుపు';
  }

  @override
  String get savingsHomeTitle => 'పొదుపు';

  @override
  String get savingsHomeAddTooltip => 'పొదుపు జోడించండి';

  @override
  String get savingsHomeGroupSavingsLabel => 'గ్రూప్ పొదుపు';

  @override
  String get savingsHomeMySavingsLabel => 'నా పొదుపు';

  @override
  String savingsHomeEntriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఎంట్రీలు',
      one: 'ఎంట్రీ',
    );
    return '$count $_temp0';
  }

  @override
  String get savingsHomePendingVerificationLabel => 'పెండింగ్ ధృవీకరణ';

  @override
  String get savingsHomeNeedsReview => 'సమీక్ష అవసరం';

  @override
  String get savingsHomeAllCaughtUp => 'అన్నీ పూర్తయ్యాయి';

  @override
  String get savingsHomeAddSavingsTile => 'పొదుపు జోడించండి';

  @override
  String get savingsHomeHistoryTile => 'చరిత్ర';

  @override
  String get savingsHomeStatementTile => 'స్టేట్‌మెంట్';

  @override
  String get savingsHomeLedgerTile => 'లెడ్జర్';

  @override
  String get savingsHomeGroupTile => 'గ్రూప్';

  @override
  String get savingsHomeRecentEntriesTitle => 'ఇటీవలి ఎంట్రీలు';

  @override
  String get savingsHomeViewAllAction => 'అన్నీ చూడండి';

  @override
  String get savingsHomeEmpty => 'ఇంకా పొదుపు ఎంట్రీలు లేవు';

  @override
  String get savingsLedgerTitle => 'పొదుపు లెడ్జర్';

  @override
  String get savingsLedgerLiveLabel => 'ప్రత్యక్షం';

  @override
  String get savingsLedgerAddTooltip => 'పొదుపు జోడించండి';

  @override
  String get savingsLedgerEmpty => 'ఇంకా ఏ పొదుపు ఎంట్రీలు నమోదు కాలేదు';

  @override
  String get savingsLedgerVerifyError =>
      'ఈ ఎంట్రీని ధృవీకరించడం సాధ్యం కాలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get savingsLedgerVerifying => 'ధృవీకరిస్తోంది…';

  @override
  String savingsLedgerVerifyAction(String amount) {
    return '$amount · ధృవీకరించండి';
  }

  @override
  String get savingsLedgerVerifiedBadge => 'ధృవీకరించబడింది';

  @override
  String get savingsStatementTitle => 'పొదుపు స్టేట్‌మెంట్';

  @override
  String get savingsStatementEmpty => 'ఇంకా ఎంట్రీలు లేవు';

  @override
  String get savingsStatementClosingBalance => 'క్లోజింగ్ బ్యాలెన్స్';

  @override
  String savingsStatementTransactionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'లావాదేవీలు',
      one: 'లావాదేవీ',
    );
    return '$count $_temp0';
  }

  @override
  String get savingsStatementDateModeHeader => 'తేదీ / విధానం';

  @override
  String get savingsStatementAmountBalanceHeader => 'మొత్తం / బ్యాలెన్స్';

  @override
  String get schemeEligibilityTitle => 'అర్హత తనిఖీ';

  @override
  String get schemeEligibilityIntro =>
      'ఇది మీ SHG సభ్యత్వం, నమోదు వయస్సు మరియు గ్రేడ్ ఆధారంగా స్వయంచాలకంగా తనిఖీ చేయబడుతుంది. కొన్ని షరతులు — BPL స్థితి లేదా ఇంతకుముందు పొందిన సబ్సిడీ వంటివి — ఇప్పటికీ మాన్యువల్ ధృవీకరణ అవసరం; వాటి కోసం ప్రతి పథకం పూర్తి అర్హత జాబితాను చూడండి.';

  @override
  String get schemeEligibilityEmptyCatalog => 'ఇంకా జాబితాలో ఏ పథకాలు లేవు';

  @override
  String get schemeEligibilitySeeFullDetails => 'పూర్తి వివరాలు చూడండి';

  @override
  String get schemeEligibilityEligible => 'అర్హత ఉంది';

  @override
  String get schemeEligibilityNotEligible => 'అర్హత లేదు';

  @override
  String get schemeEligibilityNoCriteria =>
      'ఈ పథకానికి స్వయంచాలక అర్హత షరతులు ఏవీ సెట్ చేయలేదు — పూర్తి అవసరాలు చూడటానికి దీన్ని తెరవండి.';

  @override
  String get schemesHomeTitle => 'ప్రభుత్వ పథకాలు';

  @override
  String get schemesHomeEligibilityTile => 'అర్హత';

  @override
  String get schemesHomeTrackingTile => 'ట్రాకింగ్';

  @override
  String get schemesHomeApplicationsTile => 'దరఖాస్తులు';

  @override
  String get schemesHomeAllSchemesSection => 'అన్ని పథకాలు';

  @override
  String get schemesHomeEmptyState => 'ప్రస్తుతం ఏ పథకాలు అందుబాటులో లేవు';

  @override
  String get schemesHomeNotApplied => 'దరఖాస్తు చేయలేదు';

  @override
  String get schemeDetailApplicationSubmitted => 'దరఖాస్తు సమర్పించబడింది';

  @override
  String get schemeDetailApplyError =>
      'ఈ దరఖాస్తును సమర్పించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get schemeDetailTitle => 'పథకం వివరాలు';

  @override
  String get schemeDetailNotFound => 'ఈ పథకం కనుగొనబడలేదు';

  @override
  String get schemeDetailBenefitSection => 'ప్రయోజనం';

  @override
  String get schemeDetailEligibilitySection => 'అర్హత';

  @override
  String get schemeDetailApplicationStatusLabel => 'దరఖాస్తు స్థితి: ';

  @override
  String get schemeDetailDeadlinePassed =>
      'దరఖాస్తులు మూసివేయబడ్డాయి — ఈ పథకానికి గడువు ముగిసింది.';

  @override
  String get schemeDetailSubmitting => 'సమర్పిస్తోంది…';

  @override
  String get schemeDetailApplyNow => 'ఇప్పుడు దరఖాస్తు చేయండి';

  @override
  String schemeDetailDeadlineLabel(String date) {
    return 'గడువు తేదీ: $date';
  }

  @override
  String get schemeTrackingTitle => 'దరఖాస్తు ట్రాకింగ్';

  @override
  String get schemeTrackingEmptyState =>
      'మీరు ఇంకా ఏ పథకానికి దరఖాస్తు చేయలేదు';

  @override
  String get schemeApplicationsReviewApproved => 'దరఖాస్తు ఆమోదించబడింది';

  @override
  String get schemeApplicationsReviewRejected => 'దరఖాస్తు తిరస్కరించబడింది';

  @override
  String get schemeApplicationsReviewAlreadyDecided =>
      'ఈ దరఖాస్తుపై ఇప్పటికే వేరొకరు నిర్ణయం తీసుకున్నారు.';

  @override
  String get schemeApplicationsReviewSaveError =>
      'ఈ నిర్ణయాన్ని సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get schemeApplicationsReviewTitle => 'పథక దరఖాస్తులు';

  @override
  String get schemeApplicationsReviewEmptyState =>
      'పెండింగ్‌లో ఉన్న పథక దరఖాస్తులు లేవు';

  @override
  String schemeApplicationsReviewAppliedOn(String date) {
    return '$date న దరఖాస్తు చేశారు';
  }

  @override
  String get schemeApplicationsReviewReject => 'తిరస్కరించండి';

  @override
  String get schemeApplicationsReviewSaving => 'సేవ్ చేస్తోంది…';

  @override
  String get schemeApplicationsReviewApprove => 'ఆమోదించండి';

  @override
  String get supportStatusOpen => 'తెరిచి ఉంది';

  @override
  String get supportStatusInProgress => 'జరుగుతోంది';

  @override
  String get supportStatusResolved => 'పరిష్కారమైంది';

  @override
  String get supportStatusClosed => 'ముగిసింది';

  @override
  String get supportChatTitle => 'చాట్ సహాయం';

  @override
  String get supportChatEmptyMessage =>
      'ఇంకా ఎలాంటి సంభాషణలు లేవు — ప్రారంభించడానికి ఒక టికెట్ నమోదు చేయండి';

  @override
  String get supportFaqTitle => 'సాధారణ ప్రశ్నలు';

  @override
  String get supportHomeTitle => 'సహాయం';

  @override
  String get supportHomeMyTickets => 'నా టికెట్లు';

  @override
  String get supportHomeRaiseTicket => 'టికెట్ నమోదు చేయండి';

  @override
  String get supportHomeVoiceHelp => 'వాయిస్ సహాయం';

  @override
  String get supportHomeFaqs => 'సాధారణ ప్రశ్నలు';

  @override
  String get supportHomeAllTickets => 'అన్ని టికెట్లు';

  @override
  String get supportHomeViewAll => 'అన్నీ చూడండి';

  @override
  String get supportHomeEmptyMessage => 'ఇంకా ఎలాంటి సహాయ టికెట్లు లేవు';

  @override
  String get supportTicketDetailSendError =>
      'ఈ సందేశాన్ని పంపలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get supportTicketDetailStatusError =>
      'టికెట్ స్థితిని నవీకరించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get supportTicketDetailTitle => 'టికెట్';

  @override
  String get supportTicketDetailNotFound => 'ఈ టికెట్ కనుగొనబడలేదు';

  @override
  String get supportTicketDetailNoMessages => 'ఇంకా సందేశాలు లేవు';

  @override
  String get supportTicketDetailYou => 'మీరు';

  @override
  String get supportTicketDetailStaff => 'సిబ్బంది';

  @override
  String get supportTicketDetailComposerHint => 'సందేశం టైప్ చేయండి…';

  @override
  String get supportTicketDetailDemoModeHint =>
      'డెమో మోడ్ — రిప్లైలు నిలిపివేయబడ్డాయి';

  @override
  String get supportTicketDetailSendTooltip => 'సందేశం పంపండి';

  @override
  String get supportTicketFormTitle => 'టికెట్ నమోదు చేయండి';

  @override
  String get supportTicketFormSubjectLabel => 'విషయం';

  @override
  String get supportTicketFormSubjectHint => 'ఉదా: రుణం పంపిణీలో ఆలస్యం';

  @override
  String get supportTicketFormDescriptionLabel => 'మీ సమస్యను వివరించండి';

  @override
  String get supportTicketFormDescriptionHint =>
      'మీకు వీలైనంత వివరంగా చెప్పండి';

  @override
  String get supportTicketFormSubjectRequired =>
      'మీ సమస్యకు ఒక విషయం నమోదు చేయండి';

  @override
  String get supportTicketFormSubmitting => 'సమర్పిస్తోంది…';

  @override
  String get supportTicketFormSubmit => 'టికెట్ సమర్పించండి';

  @override
  String get supportTicketFormRaisedSuccess => 'టికెట్ నమోదు అయింది';

  @override
  String get supportTicketFormDemoModeMessage =>
      'డెమో మోడ్ — టికెట్ సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get supportTicketFormRaiseError =>
      'ఈ టికెట్‌ను నమోదు చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get supportVoiceTitle => 'వాయిస్ సహాయం';

  @override
  String get supportVoiceTapToAsk => 'ప్రశ్న అడగడానికి టాప్ చేయండి';

  @override
  String get supportVoiceListening => 'వింటోంది…';

  @override
  String get supportVoiceThinking => 'సమాధానం వెతుకుతోంది…';

  @override
  String get supportVoiceTapToAskAgain => 'మళ్ళీ అడగడానికి టాప్ చేయండి';

  @override
  String get supportVoiceError =>
      'క్షమించండి, ఏదో తప్పు జరిగింది. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get supportVoiceYouAsked => 'మీరు అడిగారు';

  @override
  String get supportVoiceAnswerLabel => 'సమాధానం';

  @override
  String get memberDetailTitle => 'సభ్యుని వివరాలు';

  @override
  String get memberDetailNotFound => 'ఈ సభ్యుడు కనుగొనబడలేదు';

  @override
  String get memberDetailTotalSavings => 'మొత్తం పొదుపు';

  @override
  String get memberDetailLoanOutstanding => 'బాకీ ఉన్న రుణం';

  @override
  String get memberDetailContactSection => 'సంప్రదింపు';

  @override
  String get memberDetailMobileLabel => 'మొబైల్';

  @override
  String get memberDetailVillageLabel => 'గ్రామం';

  @override
  String get shgHomeTitle => 'నా SHG';

  @override
  String get shgHomeNotLinked => 'మీరు ఇంకా ఏ SHGకి లింక్ కాలేదు';

  @override
  String shgHomeRegNumberLabel(String regNumber) {
    return 'రిజి. నం. $regNumber';
  }

  @override
  String get shgHomeMembersTile => 'సభ్యులు';

  @override
  String get shgHomeDocumentsTile => 'పత్రాలు';

  @override
  String get shgHomeFederationSection => 'సమాఖ్య';

  @override
  String get shgHomeVillageOrgLabel => 'గ్రామ సంస్థ';

  @override
  String get shgHomeClfLabel => 'CLF';

  @override
  String get shgHomeMandalLabel => 'మండలం';

  @override
  String get shgHomeFormedLabel => 'స్థాపన';

  @override
  String get shgHomeBankDetailsSection => 'బ్యాంక్ వివరాలు';

  @override
  String get shgHomeBankLabel => 'బ్యాంక్';

  @override
  String get shgHomeAccountLabel => 'ఖాతా';

  @override
  String get shgHomeIfscLabel => 'IFSC';

  @override
  String get shgDocumentsTitle => 'పత్రాలు';

  @override
  String get shgDocumentsAddTooltip => 'పత్రం జోడించండి';

  @override
  String get shgDocumentsEmpty => 'ఇంకా ఏ పత్రాలు అప్‌లోడ్ చేయలేదు';

  @override
  String get shgDocumentsAddDialogTitle => 'పత్రం జోడించండి';

  @override
  String get shgDocumentsNameHint => 'పత్రం పేరు';

  @override
  String get shgDocumentsChooseFile => 'ఫైల్ ఎంచుకోండి (PDF, JPG, PNG, WEBP)';

  @override
  String get shgDocumentsFileTooLarge =>
      'ఫైల్ చాలా పెద్దదిగా ఉంది — దయచేసి 10 MB కంటే చిన్నదాన్ని ఎంచుకోండి';

  @override
  String get shgDocumentsNameRequired => 'పత్రం పేరు అవసరం.';

  @override
  String get shgDocumentsFileRequired =>
      'దయచేసి అప్‌లోడ్ చేయడానికి ఒక ఫైల్‌ను ఎంచుకోండి.';

  @override
  String get shgDocumentsNotLinked =>
      'మీరు ఏ SHGకి లింక్ చేయబడలేదు, కాబట్టి ఈ పత్రాన్ని జోడించడానికి ఏమీ లేదు.';

  @override
  String get shgDocumentsAdded => 'పత్రం జోడించబడింది';

  @override
  String get shgDocumentsAddError =>
      'ఈ పత్రాన్ని జోడించడం సాధ్యం కాలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get shgDocumentsNoFileAttached => 'ఈ రికార్డుకు ఏ ఫైల్ జోడించబడలేదు.';

  @override
  String get shgDocumentsOpenError => 'ఈ పత్రాన్ని తెరవడం సాధ్యం కాలేదు.';

  @override
  String get shgJoinRequestsApproved => 'అభ్యర్థన ఆమోదించబడింది';

  @override
  String get shgJoinRequestsRejected => 'అభ్యర్థన తిరస్కరించబడింది';

  @override
  String get shgJoinRequestsDemoMode =>
      'డెమో మోడ్ — సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get shgJoinRequestsProcessError =>
      'ఈ అభ్యర్థనను ప్రాసెస్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get shgJoinRequestsTitle => 'చేరిక అభ్యర్థనలు';

  @override
  String get shgJoinRequestsEmpty =>
      'ప్రస్తుతం పెండింగ్‌లో ఉన్న చేరిక అభ్యర్థనలు లేవు';

  @override
  String get shgJoinRequestsMemberFallback => 'సభ్యురాలు';

  @override
  String shgJoinRequestsRequestedOn(String date) {
    return '$dateన అభ్యర్థించారు';
  }

  @override
  String get shgJoinRequestsReject => 'తిరస్కరించండి';

  @override
  String get shgJoinRequestsWorking => 'ప్రాసెస్ అవుతోంది…';

  @override
  String get shgJoinRequestsApprove => 'ఆమోదించండి';

  @override
  String get shgMembersTitle => 'సభ్యులు';

  @override
  String get shgMembersJoinRequestsTooltip => 'చేరిక అభ్యర్థనలు';

  @override
  String get shgMembersEmpty => 'సభ్యులు కనుగొనబడలేదు';

  @override
  String get certificatesTitle => 'సర్టిఫికెట్లు';

  @override
  String get certificatesEmptyState =>
      'ఇంకా ఏ సర్టిఫికెట్ రాలేదు — ఒకటి పొందడానికి కోర్సు క్విజ్ పూర్తి చేయండి';

  @override
  String certificatesCompletedOn(String topic, String date) {
    return '$topic · $dateన పూర్తయింది';
  }

  @override
  String get courseDetailTitle => 'కోర్సు వివరాలు';

  @override
  String get courseDetailProgressDemoMode =>
      'డెమో మోడ్ — పురోగతి సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get courseDetailProgressError =>
      'మీ పురోగతిని సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get courseDetailNotFound => 'ఈ కోర్సు కనుగొనబడలేదు';

  @override
  String get courseDetailCertifiedBadge => 'సర్టిఫైడ్';

  @override
  String courseDetailPercentComplete(int pct) {
    return '$pct% పూర్తయింది';
  }

  @override
  String get courseDetailSaving => 'సేవ్ చేస్తోంది…';

  @override
  String get courseDetailStartCourse => 'కోర్సు ప్రారంభించండి';

  @override
  String get courseDetailContinue => 'కొనసాగించండి';

  @override
  String get courseDetailTakeQuiz => 'క్విజ్ తీసుకుని సర్టిఫికెట్ పొందండి';

  @override
  String get courseDetailCertificateEarned =>
      'మీరు ఈ కోర్సు కోసం సర్టిఫికెట్ పొందారు!';

  @override
  String get courseQuizTitle => 'కోర్సు క్విజ్';

  @override
  String courseQuizScoreResult(int score, int total) {
    return 'మీకు $score/$total స్కోరు వచ్చింది. పాస్ అవ్వడానికి మళ్ళీ ప్రయత్నించండి.';
  }

  @override
  String get courseQuizPassed => 'పాస్ అయ్యారు! సర్టిఫికెట్ వచ్చింది.';

  @override
  String get courseQuizPassedDemoMode =>
      'పాస్ అయ్యారు! డెమో మోడ్ — సర్టిఫికెట్ సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get courseQuizSaveError =>
      'మీ సర్టిఫికెట్‌ను సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get courseQuizNotFound => 'ఈ కోర్సు కనుగొనబడలేదు';

  @override
  String get courseQuizNoQuizAvailable =>
      'ఈ కోర్సుకు ఇంకా క్విజ్ అందుబాటులో లేదు';

  @override
  String get courseQuizSubmitButton => 'క్విజ్ సమర్పించండి';

  @override
  String get courseQuizSubmitting => 'సమర్పిస్తోంది…';

  @override
  String get trainingHomeTitle => 'శిక్షణ';

  @override
  String get trainingHomeCertificatesTooltip => 'నా సర్టిఫికెట్లు';

  @override
  String get trainingHomeEmpty => 'ఇంకా కోర్సులు అందుబాటులో లేవు';

  @override
  String get trainingHomeCoursesSection => 'కోర్సులు';

  @override
  String get trainingHomeCertifiedBadge => 'సర్టిఫైడ్';

  @override
  String get loanApplyTitle => 'రుణం కోసం దరఖాస్తు చేయండి';

  @override
  String get loanApplyPurposeLabel => 'ప్రయోజనం';

  @override
  String get loanApplyPurposeHint =>
      'ఉదా. పాడి పరిశ్రమ — పాలు ఇచ్చే ఆవు కొనుగోలు';

  @override
  String get loanApplyAmountLabel => 'అడిగిన మొత్తం';

  @override
  String get loanApplyTenureLabel => 'వ్యవధి';

  @override
  String loanApplyTenureMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'నెలలు',
      one: 'నెల',
    );
    return '$months $_temp0';
  }

  @override
  String get loanApplySubmitting => 'సమర్పిస్తోంది…';

  @override
  String get loanApplySubmitButton => 'దరఖాస్తును సమర్పించండి';

  @override
  String get loanApplyPurposeRequiredError => 'రుణం దేని కోసమో వివరించండి';

  @override
  String get loanApplyInvalidAmountError => 'సరైన మొత్తాన్ని నమోదు చేయండి';

  @override
  String get loanApplyAmountTooLargeError =>
      'మొత్తం అసాధారణంగా ఎక్కువగా ఉంది — దయచేసి సరిచూసి మళ్ళీ నమోదు చేయండి';

  @override
  String get loanApplyNoShgError =>
      'మీరు ఏ SHGతోనూ అనుసంధానించబడలేదు, కాబట్టి ఈ రుణం కోసం దరఖాస్తు చేయడానికి ఏమీ లేదు.';

  @override
  String get loanApplySuccessMessage =>
      'రుణ దరఖాస్తు సమీక్ష కోసం సమర్పించబడింది';

  @override
  String get loanApplyDemoModeMessage =>
      'డెమో మోడ్ — దరఖాస్తు సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get loanApplySubmitError =>
      'ఈ దరఖాస్తును సమర్పించలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get loansHomeTitle => 'రుణాలు';

  @override
  String get loansHomeApplyTooltip => 'రుణం కోసం దరఖాస్తు చేయండి';

  @override
  String get loansHomeGroupOutstandingLabel => 'గ్రూప్ బకాయి';

  @override
  String get loansHomeMyOutstandingLabel => 'నా బకాయి';

  @override
  String loansHomeLoanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'రుణాలు',
      one: 'రుణం',
    );
    return '$count $_temp0';
  }

  @override
  String get loansHomePendingApprovalLabel => 'ఆమోదం పెండింగ్‌లో';

  @override
  String get loansHomeOverdueLabel => 'గడువు మీరిన';

  @override
  String get loansHomeNeedsReviewTrend => 'సమీక్ష అవసరం';

  @override
  String get loansHomeActionNeededTrend => 'చర్య అవసరం';

  @override
  String get loansHomeOnTrackTrend => 'సక్రమంగా ఉంది';

  @override
  String get loansHomeApplyLabel => 'దరఖాస్తు చేయండి';

  @override
  String get loansHomeTrackingLabel => 'ట్రాకింగ్';

  @override
  String get loansHomeApprovalsLabel => 'ఆమోదాలు';

  @override
  String loansHomeApprovalsBadgeSemanticLabel(int count) {
    return 'ఆమోదాలు, $count పెండింగ్‌లో';
  }

  @override
  String get loansHomeAllLoansTitle => 'అన్ని రుణాలు';

  @override
  String get loansHomeMyLoansTitle => 'నా రుణాలు';

  @override
  String get loansHomeEmptyMessage => 'ఇంకా రుణాలు లేవు';

  @override
  String loansHomeOutstandingOfAmount(String outstanding, String amount) {
    return '₹$amountలో ₹$outstanding బాకీ ఉంది';
  }

  @override
  String get loanTrackingTitle => 'రుణ ట్రాకింగ్';

  @override
  String get loanTrackingEmptyMessage =>
      'ట్రాక్ చేయడానికి యాక్టివ్ రుణాలు లేవు';

  @override
  String loanTrackingOfAmount(String amount) {
    return '₹$amountలో';
  }

  @override
  String loanTrackingEmiDueBadge(String emi, String dueDate) {
    return 'EMI ₹$emi, $dueDateన చెల్లించాలి';
  }

  @override
  String get loanTrackingDetailsLink => 'వివరాలు';

  @override
  String get analyticsDashboardTitle => 'అనలిటిక్స్';

  @override
  String get analyticsDashboardTotalShgs => 'మొత్తం SHGలు';

  @override
  String get analyticsDashboardActiveMembers => 'క్రియాశీల సభ్యులు';

  @override
  String get analyticsDashboardTotalSavings => 'మొత్తం పొదుపు';

  @override
  String get analyticsDashboardLoansDisbursed => 'పంపిణీ చేసిన రుణాలు';

  @override
  String get analyticsDashboardLoanRecoveryRate => 'రుణ వసూలు రేటు';

  @override
  String get analyticsDashboardMonitorShgs => 'SHGలను పర్యవేక్షించండి';

  @override
  String get analyticsDashboardPerGroupHealthScores =>
      'ప్రతి సమూహం ఆరోగ్య స్కోరు';

  @override
  String get analyticsDashboardChartsLabel => 'చార్టులు';

  @override
  String get analyticsDashboardSavingsTrends => 'పొదుపు ధోరణులు';

  @override
  String get analyticsDashboardLoanTrends => 'రుణాల ధోరణులు';

  @override
  String get analyticsDashboardRevenueTrends => 'ఆదాయ ధోరణులు';

  @override
  String get analyticsDashboardAttendanceTrends => 'హాజరు ధోరణులు';

  @override
  String get analyticsDashboardNoDataYet => 'ఇంకా డేటా లేదు';

  @override
  String get analyticsShgDetailTitle => 'SHG అనలిటిక్స్';

  @override
  String get analyticsShgDetailNotFound => 'ఈ SHG కనుగొనబడలేదు';

  @override
  String get analyticsShgDetailMembersLabel => 'సభ్యులు';

  @override
  String get analyticsShgDetailTotalSavings => 'మొత్తం పొదుపు';

  @override
  String get analyticsShgDetailHealthScore => 'ఆరోగ్య స్కోరు';

  @override
  String get analyticsShgDetailHealthScoreNote =>
      'పూర్తయిన సమావేశాల హాజరు రేటు ఆధారంగా';

  @override
  String get analyticsShgListTitle => 'SHG పర్యవేక్షణ';

  @override
  String get analyticsShgListEmptyState => 'పర్యవేక్షణ కోసం ఇంకా SHGలు లేవు';

  @override
  String analyticsShgListVillageMemberCount(String village, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'మంది సభ్యులు',
      one: 'సభ్యురాలు',
    );
    return '$village · $count $_temp0';
  }

  @override
  String get livelihoodEntryTitle => 'కార్యాచరణ జోడించండి';

  @override
  String get livelihoodEntryActivityTypeLabel => 'కార్యాచరణ రకం';

  @override
  String get livelihoodEntryTypeDairy => 'డెయిరీ';

  @override
  String get livelihoodEntryTypeTailoring => 'కుట్టు పని';

  @override
  String get livelihoodEntryTypeRetail => 'చిల్లర వ్యాపారం';

  @override
  String get livelihoodEntryTypePoultry => 'కోళ్ల పెంపకం';

  @override
  String get livelihoodEntryTypeAgriculture => 'వ్యవసాయం';

  @override
  String get livelihoodEntryTypeHandicrafts => 'హస్తకళలు';

  @override
  String get livelihoodEntryTypeOther => 'ఇతర';

  @override
  String get livelihoodEntryDescriptionLabel => 'వివరణ';

  @override
  String get livelihoodEntryDescriptionHint =>
      'ఉదా. పాడి ఆవుల పెంపకం — 2 ఆవులు';

  @override
  String get livelihoodEntryInvestmentLabel => 'ప్రారంభ పెట్టుబడి';

  @override
  String get livelihoodEntryDescribeRequired => 'కార్యాచరణను వివరించండి';

  @override
  String get livelihoodEntryInvalidInvestment =>
      'చెల్లుబాటు అయ్యే పెట్టుబడి మొత్తాన్ని నమోదు చేయండి';

  @override
  String get livelihoodEntryNoShg =>
      'మీరు ఏ SHGకి లింక్ చేయబడలేదు, కాబట్టి ఈ కార్యాచరణను నమోదు చేయడానికి ఏమీ లేదు.';

  @override
  String get livelihoodEntryAdded => 'కార్యాచరణ జోడించబడింది';

  @override
  String get livelihoodEntryDemoMode =>
      'డెమో మోడ్ — కార్యాచరణ సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String get livelihoodEntrySaveError =>
      'ఈ కార్యాచరణను సేవ్ చేయలేకపోయాము. దయచేసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get livelihoodEntrySaving => 'సేవ్ చేస్తోంది…';

  @override
  String get livelihoodHomeTitle => 'జీవనోపాధి';

  @override
  String get livelihoodHomeAddActivityTooltip => 'కార్యాచరణ జోడించండి';

  @override
  String get livelihoodHomeTotalInvestment => 'మొత్తం పెట్టుబడి';

  @override
  String get livelihoodHomeTotalRevenue => 'మొత్తం ఆదాయం';

  @override
  String get livelihoodHomeEmpty => 'ఇంకా జీవనోపాధి కార్యకలాపాలు లేవు';

  @override
  String livelihoodHomeNetAmount(String amount) {
    return 'నికర $amount';
  }

  @override
  String get paymentsHistoryTitle => 'చెల్లింపు చరిత్ర';

  @override
  String get paymentsHistoryEmpty => 'ఇంకా చెల్లింపులు లేవు';

  @override
  String paymentsHistoryModePayment(String mode) {
    return '$mode చెల్లింపు';
  }

  @override
  String get paymentsHomeTitle => 'డిజిటల్ చెల్లింపులు';

  @override
  String get paymentsHomeScanPay => 'స్కాన్ చేసి చెల్లించండి';

  @override
  String get paymentsHomeHistory => 'చరిత్ర';

  @override
  String get paymentsHomeRecentPayments => 'ఇటీవలి చెల్లింపులు';

  @override
  String get paymentsHomeViewAll => 'అన్నీ చూడండి';

  @override
  String get paymentsHomeEmpty => 'ఇంకా చెల్లింపులు లేవు';

  @override
  String get adminMonitoringTitle => 'సిస్టమ్ మానిటరింగ్';

  @override
  String get adminMonitoringTotalUsers => 'మొత్తం వినియోగదారులు';

  @override
  String get adminMonitoringTotalShgs => 'మొత్తం SHGలు';

  @override
  String get adminMonitoringSavingsEntries => 'పొదుపు ఎంట్రీలు';

  @override
  String get adminMonitoringLoansPending => 'రుణాలు (పెండింగ్‌లో)';

  @override
  String get adminMonitoringAiModerationBlocksLabel =>
      'AI సలహాదారు బ్లాక్‌లు (7 రోజులు)';

  @override
  String get adminMonitoringAiModerationMembersFlaggedLabel =>
      'ఫ్లాగ్ చేయబడిన సభ్యులు (7 రోజులు)';

  @override
  String get adminMonitoringPlaceholderLabel => 'ప్లేస్‌హోల్డర్ మెట్రిక్స్';

  @override
  String get adminMonitoringPlaceholderDescription =>
      'ఇవి కేవలం ప్రాథమిక రో కౌంట్‌లు మాత్రమే, నిజమైన ఇన్‌ఫ్రాస్ట్రక్చర్ మెట్రిక్స్ (అప్‌టైమ్, లేటెన్సీ, ఎర్రర్ రేట్) కాదు. నిజమైన మానిటరింగ్ కోసం ప్రత్యేక Edge Function లేదా బాహ్య సేవ అవసరం.';

  @override
  String adminMonitoringCheckedAt(String date) {
    return '$dateన తనిఖీ చేయబడింది';
  }

  @override
  String get aiHubTitle => 'AI సలహాదారులు';

  @override
  String get aiHubAskAdvisor => 'సలహాదారుని అడగండి';

  @override
  String get aiHubFinancialAdvisorTitle => 'ఆర్థిక సలహాదారు';

  @override
  String get aiHubFinancialAdvisorSubtitle =>
      'పొదుపు, రుణాలు & బడ్జెట్ మార్గదర్శకత్వం';

  @override
  String get aiHubSchemeRecommenderTitle => 'పథక సలహాదారు';

  @override
  String get aiHubSchemeRecommenderSubtitle =>
      'మీరు అర్హులైన ప్రభుత్వ పథకాలను కనుగొనండి';

  @override
  String get aiHubMarketAdvisorTitle => 'మార్కెట్ సలహాదారు';

  @override
  String get aiHubMarketAdvisorSubtitle =>
      'మీ ఉత్పత్తుల కోసం ధర & అమ్మకపు చిట్కాలు';

  @override
  String get aiHubVoiceAssistantTitle => 'వాయిస్ అసిస్టెంట్';

  @override
  String get aiHubVoiceAssistantSubtitle =>
      'తెలుగు, హిందీ లేదా ఇంగ్లీష్‌లో అడగండి — చేతులు వాడకుండా';

  @override
  String get announcementDetailTitle => 'ప్రకటన';

  @override
  String get announcementDetailNotFound => 'ఈ ప్రకటన కనుగొనబడలేదు';

  @override
  String get splashBrandName => 'NAVASAKHI';

  @override
  String get splashHeadline => 'మహిళా సాధికారత.\nసమాజ పరివర్తన.';

  @override
  String get splashSubtitle =>
      'పొదుపు, రుణాలు, సమావేశాలు, పథకాలు, మార్కెట్ మరియు మరెన్నో — మీ SHGకి కావాల్సినవన్నీ, ఒకే యాప్‌లో.';

  @override
  String get splashFeatureSavingsLoans => 'పొదుపు & రుణాలు';

  @override
  String get splashFeatureGroupManagement => 'గ్రూప్ నిర్వహణ';

  @override
  String get splashFeatureGovtSchemes => 'ప్రభుత్వ పథకాలు';

  @override
  String get splashFeatureLivelihoods => 'జీవనోపాధి';

  @override
  String get splashGetStarted => 'ప్రారంభించండి';

  @override
  String get splashAvailableLanguages =>
      'ఈ భాషల్లో అందుబాటులో ఉంది: English · తెలుగు · हिंदी';

  @override
  String get financialLedgerCashbookLabel => 'క్యాష్‌బుక్';

  @override
  String get financialLedgerLedgerLabel => 'లెడ్జర్';

  @override
  String get financialLedgerBankLabel => 'బ్యాంక్';

  @override
  String get financialLedgerAuditLabel => 'ఆడిట్';

  @override
  String get financialLedgerAddEntryTooltip => 'ఎంట్రీ జోడించండి';

  @override
  String get financialLedgerEntryAdded => 'ఎంట్రీ జోడించబడింది';

  @override
  String get financialLedgerDemoMode =>
      'డెమో మోడ్ — సేవ్ కాలేదు (శాశ్వతంగా సేవ్ చేయడానికి Supabaseని కనెక్ట్ చేయండి)';

  @override
  String financialLedgerEmpty(String title) {
    return 'ఇంకా $title ఎంట్రీలు లేవు';
  }

  @override
  String get servicesSavingsLabel => 'పొదుపు';

  @override
  String get servicesLoansLabel => 'రుణాలు';

  @override
  String get servicesMeetingsLabel => 'సమావేశాలు';

  @override
  String get servicesFinancialRecordsLabel => 'ఆర్థిక రికార్డులు';

  @override
  String get servicesLivelihoodsLabel => 'జీవనోపాధి';

  @override
  String get servicesMarketplaceLabel => 'మార్కెట్';

  @override
  String get servicesDigitalPaymentsLabel => 'డిజిటల్ చెల్లింపులు';

  @override
  String get servicesGovtSchemesLabel => 'ప్రభుత్వ పథకాలు';

  @override
  String get servicesTrainingLabel => 'శిక్షణ';

  @override
  String get servicesSupportLabel => 'సహాయం';

  @override
  String get servicesAiAdvisorsLabel => 'AI సలహాదారులు';

  @override
  String get servicesAnnouncementsLabel => 'ప్రకటనలు';

  @override
  String get servicesReportsLabel => 'నివేదికలు';

  @override
  String get servicesAnalyticsLabel => 'అనలిటిక్స్';

  @override
  String get servicesManageUsersLabel => 'వినియోగదారుల నిర్వహణ';

  @override
  String get servicesManageSchemesLabel => 'పథకాల నిర్వహణ';

  @override
  String get servicesSystemMonitoringLabel => 'సిస్టమ్ మానిటరింగ్';

  @override
  String get servicesShgManagementSection => 'SHG నిర్వహణ';

  @override
  String get servicesCommerceSection => 'వ్యాపారం';

  @override
  String get servicesLearningSupportSection => 'నేర్చుకోవడం & సహాయం';

  @override
  String get servicesInsightsSection => 'ఇన్‌సైట్స్';

  @override
  String get servicesAdminToolsSection => 'అడ్మిన్ టూల్స్';

  @override
  String get schemeEligibilityShgMembershipMet =>
      'SHG సభ్యత్వం — మీరు SHGకి అనుసంధానించబడ్డారు';

  @override
  String get schemeEligibilityShgMembershipUnmet =>
      'SHG సభ్యత్వం అవసరం — మీరు ఏ SHGకి అనుసంధానించబడలేదు';

  @override
  String schemeEligibilityAgeMet(int actual, int required) {
    return 'SHG $actual+ నెలలుగా నమోదు చేయబడింది (అవసరం $required+)';
  }

  @override
  String schemeEligibilityAgeUnmetNoShg(int required) {
    return 'SHG $required+ నెలలుగా నమోదు చేయబడి ఉండాలి — మీరు ఏ SHGకి అనుసంధానించబడలేదు';
  }

  @override
  String schemeEligibilityAgeUnmetNoRecord(int required) {
    return 'SHG $required+ నెలలుగా నమోదు చేయబడి ఉండాలి — మీ SHG నమోదు తేదీ నమోదు కాలేదు';
  }

  @override
  String schemeEligibilityAgeUnmet(int required, int actual) {
    return 'SHG $required+ నెలలుగా నమోదు చేయబడి ఉండాలి — మీ SHG కేవలం $actual నెలలుగా నమోదు చేయబడింది';
  }

  @override
  String schemeEligibilityGradeMet(String grade, String required) {
    return 'SHG గ్రేడ్ $grade, $required-లేదా-అంతకంటే-ఎక్కువ అవసరతను తీరుస్తుంది';
  }

  @override
  String schemeEligibilityGradeUnmetNoShg(String required) {
    return 'SHG గ్రేడ్ $required లేదా అంతకంటే ఎక్కువ అవసరం — మీరు ఏ SHGకి అనుసంధానించబడలేదు';
  }

  @override
  String schemeEligibilityGradeUnmetNoRecord(String required) {
    return 'SHG గ్రేడ్ $required లేదా అంతకంటే ఎక్కువ అవసరం — మీ SHG గ్రేడ్ నమోదు కాలేదు';
  }

  @override
  String schemeEligibilityGradeUnmet(String required, String grade) {
    return 'SHG గ్రేడ్ $required లేదా అంతకంటే ఎక్కువ అవసరం — మీ SHG గ్రేడ్ $grade';
  }

  @override
  String adminDashboardActivityNewUser(String name) {
    return 'కొత్త వినియోగదారు నమోదు — $name';
  }

  @override
  String adminDashboardActivityNewShg(String name) {
    return 'కొత్త SHG నమోదు — $name';
  }

  @override
  String adminDashboardActivityDocument(String name) {
    return 'పత్రం అప్‌లోడ్ చేయబడింది — $name';
  }

  @override
  String get aiAdvisorUpstreamUnavailable =>
      'సలహాదారు సేవ ప్రస్తుతం తాత్కాలికంగా అందుబాటులో లేదు. దయచేసి కొద్దిసేపటి తర్వాత మళ్లీ ప్రయత్నించండి.';
}
