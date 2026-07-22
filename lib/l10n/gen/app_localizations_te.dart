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
  String get settingsNotifComingSoon =>
      'ఈ ప్రాధాన్యతలు సేవ్ అవుతాయి, కానీ యాప్ యొక్క ఈ వెర్షన్‌లో పుష్/లోకల్ రిమైండర్‌లు ఇంకా పంపబడవు.';

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
}
