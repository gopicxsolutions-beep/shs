// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'NavaSakhi';

  @override
  String get navHome => 'होम';

  @override
  String get navMySHG => 'मेरा SHG';

  @override
  String get navSHGs => 'SHGs';

  @override
  String get navServices => 'सेवाएं';

  @override
  String get navMarket => 'बाज़ार';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get actionSave => 'सेव करें';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionAdd => 'जोड़ें';

  @override
  String get actionEdit => 'संपादित करें';

  @override
  String get actionDelete => 'हटाएं';

  @override
  String get actionSubmit => 'सबमिट करें';

  @override
  String get actionRetry => 'फिर से कोशिश करें';

  @override
  String get actionSignOut => 'साइन आउट';

  @override
  String get actionCheckStatus => 'स्थिति जांचें';

  @override
  String get commonLoading => 'लोड हो रहा है…';

  @override
  String get commonError => 'कुछ गलत हो गया';

  @override
  String get commonBack => 'वापस';

  @override
  String get asyncErrorGeneric => 'कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String get asyncErrorNetwork =>
      'अपना इंटरनेट कनेक्शन जांचें और फिर से कोशिश करें।';

  @override
  String get discardChangesTitle => 'बदलाव छोड़ें?';

  @override
  String get discardChangesMessage =>
      'आपने इस पेज पर जो जानकारी भरी है वह अभी तक सेव नहीं हुई है। अभी जाने पर यह जानकारी खो जाएगी।';

  @override
  String get discardChangesKeepEditing => 'संपादन जारी रखें';

  @override
  String get discardChangesDiscard => 'छोड़ें';

  @override
  String get errorGoHome => 'होम पर जाएं';

  @override
  String get error404Title => 'पेज नहीं मिला';

  @override
  String get error404Message =>
      'आप जिस पेज को खोज रहे हैं वह मौजूद नहीं है या हट गया है।';

  @override
  String get profileLoadErrorTitle => 'आपकी प्रोफ़ाइल लोड नहीं हो सकी';

  @override
  String get qrPermissionDenied => 'कैमरा अनुमति अस्वीकार कर दी गई।';

  @override
  String get qrUnsupported => 'इस डिवाइस पर स्कैनिंग समर्थित नहीं है।';

  @override
  String get qrCameraUnavailable => 'कैमरा उपलब्ध नहीं है।';

  @override
  String get qrManualFallbackHint => 'आप अभी भी विवरण खुद दर्ज कर सकते हैं।';

  @override
  String get qrEnterManually => 'इसके बजाय खुद दर्ज करें';

  @override
  String get qrManualEntry => 'मैन्युअल एंट्री';

  @override
  String get qrTurnOffFlashlight => 'फ्लैशलाइट बंद करें';

  @override
  String get qrTurnOnFlashlight => 'फ्लैशलाइट चालू करें';

  @override
  String get qrTakingTooLong => 'कैमरा शुरू होने में बहुत समय ले रहा है।';

  @override
  String get qrScanToPayTitle => 'भुगतान के लिए स्कैन करें';

  @override
  String get qrScanToPayInstructions =>
      'अपने कैमरे को व्यापारी के UPI QR कोड पर पॉइंट करें';

  @override
  String get qrScanAttendanceTitle => 'उपस्थिति QR स्कैन करें';

  @override
  String get qrScanAttendanceInstructions =>
      'अपने कैमरे को स्थल पर दिखाए गए QR कोड पर पॉइंट करें';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String get profileEditProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get profileMobile => 'मोबाइल';

  @override
  String get profileVillage => 'गांव';

  @override
  String get profileSHG => 'SHG';

  @override
  String get profileName => 'नाम';

  @override
  String get profileUpdated => 'प्रोफ़ाइल अपडेट हो गई';

  @override
  String get profileUpdateDemoMode =>
      'डेमो मोड — सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get profileUpdateError =>
      'आपकी प्रोफ़ाइल अपडेट नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get profileNameRequired => 'नाम आवश्यक है।';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsNotifications => 'सूचनाएं';

  @override
  String get settingsNotifMeetingReminders => 'बैठक अनुस्मारक';

  @override
  String get settingsNotifPaymentAlerts => 'भुगतान अलर्ट';

  @override
  String get settingsNotifAnnouncements => 'घोषणाएं';

  @override
  String get settingsNotifLocalOnly =>
      'रिमाइंडर केवल इस डिवाइस पर शेड्यूल किए जाते हैं — किसी सर्वर से नहीं भेजे जाते। यदि आप कोई दूसरा फ़ोन इस्तेमाल करें या ऐप फिर से इंस्टॉल करें, तो ये आप तक नहीं पहुंचेंगे। यदि कोई बैठक रद्द कर दी जाती है, तो केवल इसी डिवाइस का रिमाइंडर तुरंत रद्द होता है — किसी अन्य सदस्य के फ़ोन पर पुराना रिमाइंडर तब तक दिख सकता है जब तक वह बैठक टैब फिर से न खोले।';

  @override
  String get settingsNotifPermissionDenied =>
      'आपके फ़ोन की सेटिंग्स में इस ऐप के लिए नोटिफिकेशन बंद हैं। रिमाइंडर पाने के लिए वहां उन्हें चालू करें।';

  @override
  String get settingsNotifCancelPendingError =>
      'इस डिवाइस पर ये रिमाइंडर बंद नहीं हो सके। हम स्वचालित रूप से फिर से कोशिश करते रहेंगे — कृपया अपना कनेक्शन जांचें, या दोबारा कोशिश करें।';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsPreviewAs => 'इस रूप में देखें';

  @override
  String get settingsAppVersion => 'ऐप संस्करण';

  @override
  String get settingsGeneralSection => 'सामान्य';

  @override
  String get settingsPreviewRoleDescription =>
      'यह ऐप आपको हर भूमिका का डैशबोर्ड देखने देता है — कभी भी बदल सकते हैं।';

  @override
  String get settingsPreferenceError =>
      'यह प्राथमिकता सेव नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get settingsRoleSwitchError =>
      'भूमिका नहीं बदली जा सकी। कृपया फिर से कोशिश करें।';

  @override
  String get languageTitle => 'भाषा';

  @override
  String get languageSubtitle => 'ऐप के लिए अपनी पसंदीदा भाषा चुनें';

  @override
  String get languageEnglish => 'अंग्रेज़ी';

  @override
  String get languageTelugu => 'తెలుగు';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get servicesTitle => 'सेवाएं';

  @override
  String get loginTitle => 'वापसी पर स्वागत है';

  @override
  String get loginSubtitle =>
      'जारी रखने के लिए अपना पंजीकृत मोबाइल नंबर दर्ज करें';

  @override
  String get loginSending => 'भेजा जा रहा है…';

  @override
  String get loginSendOtp => 'OTP भेजें';

  @override
  String get loginOtpError =>
      'OTP नहीं भेजा जा सका। कृपया नंबर जांचें और फिर से कोशिश करें।';

  @override
  String get loginDataProtected =>
      'आपका डेटा DAY-NRLM दिशानिर्देशों के तहत सुरक्षित है। हम आपके आधार विवरण कभी साझा नहीं करते।';

  @override
  String get loginTermsAgreement =>
      'जारी रखने पर आप सेवा की शर्तों और गोपनीयता नीति से सहमत होते हैं';

  @override
  String get otpTitle => 'OTP सत्यापित करें';

  @override
  String get otpHint => 'अपने फोन पर भेजा गया 6-अंकों का कोड दर्ज करें';

  @override
  String get otpVerify => 'सत्यापित करें';

  @override
  String get otpSentTo => 'हमने 6-अंकों का कोड भेजा है ';

  @override
  String get otpVerifyContinue => 'सत्यापित करें और जारी रखें';

  @override
  String get otpVerifying => 'सत्यापित हो रहा है…';

  @override
  String get otpResendIn => 'OTP दोबारा भेजें ';

  @override
  String get otpResend => 'OTP दोबारा भेजें';

  @override
  String get otpDidntReceive => 'कोड नहीं मिला? अपना SMS इनबॉक्स जांचें।';

  @override
  String get otpVerifyError =>
      'गलत या समय-सीमा समाप्त कोड। कृपया फिर से कोशिश करें।';

  @override
  String get otpResendError =>
      'कोड फिर से नहीं भेजा जा सका। कृपया फिर से कोशिश करें।';

  @override
  String otpDigitLabel(int position) {
    return 'OTP अंक $position, 6 में से';
  }

  @override
  String get profileSetupTitle => 'अपनी प्रोफ़ाइल बनाएं';

  @override
  String get profileSetupSubtitle =>
      'शुरू करने के लिए अपने बारे में थोड़ा बताएं';

  @override
  String get fieldFullName => 'पूरा नाम';

  @override
  String get fieldMandal => 'मंडल';

  @override
  String get fieldDistrict => 'ज़िला';

  @override
  String get yourShg => 'आपका SHG (वैकल्पिक)';

  @override
  String get searchSelectShg => 'अपना SHG खोजें और चुनें';

  @override
  String get changeShg => 'बदलें';

  @override
  String get profileSetupSaving => 'सेव हो रहा है…';

  @override
  String get profileSetupContinue => 'जारी रखें';

  @override
  String get findYourShg => 'अपना SHG खोजें';

  @override
  String get searchShgHint => 'SHG नाम से खोजें';

  @override
  String get noShgsFound => 'कोई SHG नहीं मिला';

  @override
  String get roleSelectTitle => 'इस रूप में जारी रखें';

  @override
  String get roleSelectSubtitle =>
      'अनुकूलित अनुभव देखने के लिए SHG तंत्र में अपनी भूमिका चुनें';

  @override
  String get roleSelectSaveError =>
      'आपकी भूमिका सेव नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get dashboardGreeting => 'वापसी पर स्वागत है';

  @override
  String get shgApprovalWaitingTitle => 'अनुमोदन का इंतज़ार है';

  @override
  String get shgApprovalWaitingMessage =>
      'आपका जुड़ने का अनुरोध आपके SHG लीडर को भेज दिया गया है। स्वीकृति मिलते ही आपको पहुंच मिल जाएगी।';

  @override
  String get shgApprovalRejectedTitle => 'अनुरोध स्वीकृत नहीं हुआ';

  @override
  String get shgApprovalRejectedMessage =>
      'आपके SHG लीडर ने इस अनुरोध को स्वीकृत नहीं किया। आप कोई दूसरा SHG चुनकर फिर से कोशिश कर सकते हैं।';

  @override
  String get unknownShg => 'अज्ञात SHG';

  @override
  String get chooseDifferentShg => 'दूसरा SHG चुनें';

  @override
  String get checkingStatus => 'जांच हो रही है…';

  @override
  String get shgApprovalCheckError =>
      'स्थिति जांच नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get voiceNoLoans => 'आपके नाम कोई ऋण नहीं है।';

  @override
  String voiceNoActiveLoans(int count) {
    return 'आपके नाम कुल $count ऋण हैं, लेकिन उनमें से कोई भी अभी सक्रिय नहीं है।';
  }

  @override
  String voiceLoanActive(String purpose, String amount, String outstanding) {
    return '$purpose: ₹$amount ऋण, ₹$outstanding अभी भी बकाया है।';
  }

  @override
  String voiceSavingsThisMonth(String amount, int count) {
    return 'इस महीने आपने $count बार बचत की, कुल ₹$amount।';
  }

  @override
  String get voiceNoAnnouncements => 'आपके लिए कोई घोषणा नहीं है।';

  @override
  String get voiceOpeningSavingsForm =>
      'आपके लिए बचत प्रविष्टि फ़ॉर्म खोला जा रहा है।';

  @override
  String get voiceUnknownCommand => 'माफ़ कीजिए, मुझे वह समझ नहीं आया।';

  @override
  String get aiDisclaimer =>
      'यह सलाह AI द्वारा तैयार की गई है और गलत हो सकती है। यह पेशेवर वित्तीय, कानूनी या चिकित्सा सलाह नहीं है; महत्वपूर्ण निर्णय लेने से पहले अपने SHG लीडर या किसी योग्य सलाहकार से पुष्टि करें।';

  @override
  String get adminDashboardJustNow => 'अभी';

  @override
  String adminDashboardMinutesAgo(int count) {
    return '$count मिनट पहले';
  }

  @override
  String adminDashboardHoursAgo(int count) {
    return '$count घंटे पहले';
  }

  @override
  String adminDashboardDaysAgo(int count) {
    return '$count दिन पहले';
  }

  @override
  String adminDashboardMonthsAgo(int count) {
    return '$count महीने पहले';
  }

  @override
  String get adminDashboardTotalShgsLabel => 'कुल SHGs';

  @override
  String adminDashboardActiveMembersTrend(int count) {
    return '$count सदस्य';
  }

  @override
  String get adminDashboardSystemUptimeLabel => 'सिस्टम अपटाइम';

  @override
  String get adminDashboardHeartbeatHealthy => 'स्वस्थ';

  @override
  String get adminDashboardHeartbeatStale => 'पुराना';

  @override
  String adminDashboardHeartbeatTrend(String time) {
    return 'हार्टबीट: $time';
  }

  @override
  String get adminDashboardHeartbeatPending =>
      'अभी तक कोई हार्टबीट दर्ज नहीं हुई';

  @override
  String get adminDashboardUsersTile => 'उपयोगकर्ता';

  @override
  String get adminDashboardShgsTile => 'SHGs';

  @override
  String get adminDashboardSchemesTile => 'योजनाएं';

  @override
  String get adminDashboardMonitoringTile => 'निगरानी';

  @override
  String get adminDashboardReportsTile => 'रिपोर्ट';

  @override
  String adminDashboardPendingReviewCount(int count) {
    return '$count योजना आवेदन समीक्षा हेतु लंबित हैं';
  }

  @override
  String get adminDashboardAwaitingReviewSubtitle =>
      'स्टाफ की स्वीकृति या अस्वीकृति का इंतज़ार है';

  @override
  String get adminDashboardReviewAction => 'समीक्षा करें';

  @override
  String get adminDashboardPlatformSnapshotTitle => 'प्लेटफ़ॉर्म स्नैपशॉट';

  @override
  String get adminDashboardAnalyticsAction => 'एनालिटिक्स';

  @override
  String get adminDashboardLoansDisbursedLabel => 'वितरित ऋण';

  @override
  String get adminDashboardTrainingCompletionLabel => 'प्रशिक्षण पूर्णता';

  @override
  String get adminDashboardRecentActivityTitle => 'हाल की सिस्टम गतिविधि';

  @override
  String get adminDashboardNoRecentActivity => 'अभी तक कोई हाल की गतिविधि नहीं';

  @override
  String get clfDashboardVillageOrgsLabel => 'ग्राम संगठन';

  @override
  String clfDashboardShgsTotalTrend(int count) {
    return 'कुल $count SHGs';
  }

  @override
  String get clfDashboardTotalSavingsLabel => 'कुल बचत';

  @override
  String get clfDashboardFinancialOversightTrend => 'वित्तीय निगरानी';

  @override
  String get clfDashboardMonitorVillageOrgsTitle =>
      'ग्राम संगठनों की निगरानी करें';

  @override
  String clfDashboardVillagesShgsSummary(int villageCount, int shgCount) {
    return '$villageCount गांव · $shgCount SHGs';
  }

  @override
  String get clfDashboardVillageWiseShgsTitle => 'गांव-वार SHGs';

  @override
  String get clfDashboardFederationReportsAction => 'फेडरेशन रिपोर्ट';

  @override
  String get clfDashboardNoVillagesYet => 'अभी तक कोई गांव नहीं';

  @override
  String clfDashboardShgChartSemanticLabel(String summary) {
    return 'गांव-वार SHGs बार चार्ट: $summary';
  }

  @override
  String clfDashboardShgChartItemLabel(String village, int count) {
    return '$village में $count SHGs';
  }

  @override
  String get clfDashboardFinancialOversightTitle => 'वित्तीय निगरानी';

  @override
  String get clfDashboardLoansDisbursedLabel => 'वितरित ऋण';

  @override
  String get clfDashboardRecoveryRateLabel => 'रिकवरी दर';

  @override
  String get clfDashboardFullAnalyticsTitle => 'पूर्ण एनालिटिक्स डैशबोर्ड';

  @override
  String get clfDashboardFullAnalyticsSubtitle =>
      'KPI, ट्रेंड और रिकवरी इनसाइट्स';

  @override
  String get clfDashboardOpenAction => 'खोलें';

  @override
  String get crpDashboardShgsMonitoredLabel => 'निगरानी में SHGs';

  @override
  String get crpDashboardNoShgsYetTrend => 'अभी तक कोई SHG नहीं';

  @override
  String get crpDashboardAvgHealthScoreLabel => 'औसत हेल्थ स्कोर';

  @override
  String get crpDashboardAttendanceProxyTrend => 'उपस्थिति के आधार पर अनुमान';

  @override
  String get crpDashboardShgsUnderMonitoringTitle => 'निगरानी में ली गई SHGs';

  @override
  String get crpDashboardViewAllAction => 'सभी देखें';

  @override
  String get crpDashboardNoShgsToMonitorYet =>
      'निगरानी के लिए अभी तक कोई SHG नहीं';

  @override
  String crpDashboardShgVillageMembersSummary(String village, int count) {
    return '$village · $count सदस्य';
  }

  @override
  String get crpDashboardTrainingCatalogTitle => 'प्रशिक्षण सूची';

  @override
  String get crpDashboardNoCoursesYet => 'अभी तक कोई कोर्स नहीं';

  @override
  String dashboardTopBarGreeting(String name) {
    return 'नमस्ते, $name 🙏';
  }

  @override
  String dashboardTopBarUnreadAnnouncementsTooltip(int count) {
    return '$count अपठित घोषणाएं';
  }

  @override
  String get dashboardTopBarAnnouncementsTooltip => 'घोषणाएं';

  @override
  String get leaderDashboardGroupSavingsLabel => 'समूह बचत';

  @override
  String leaderDashboardMembersTrend(int count) {
    return '$count सदस्य';
  }

  @override
  String get leaderDashboardLoansOutstandingLabel => 'बकाया ऋण';

  @override
  String leaderDashboardOverdueTrend(int count) {
    return '$count अतिदेय';
  }

  @override
  String get leaderDashboardMembersTile => 'सदस्य';

  @override
  String get leaderDashboardApprovalsTile => 'स्वीकृतियां';

  @override
  String leaderDashboardApprovalsPendingBadge(int count) {
    return 'स्वीकृतियां, $count लंबित';
  }

  @override
  String get leaderDashboardScheduleTile => 'शेड्यूल';

  @override
  String get leaderDashboardReportsTile => 'रिपोर्ट';

  @override
  String leaderDashboardDefaulterAlert(int count) {
    return '$count डिफॉल्टर अलर्ट';
  }

  @override
  String leaderDashboardEmiOverdueSinceDate(String name, String date) {
    return '$name — EMI $date से अतिदेय है';
  }

  @override
  String leaderDashboardEmiOverdue(String name) {
    return '$name — EMI अतिदेय है';
  }

  @override
  String get leaderDashboardViewAction => 'देखें';

  @override
  String get leaderDashboardPendingApprovalsTitle => 'लंबित ऋण स्वीकृतियां';

  @override
  String get leaderDashboardReviewAllAction => 'सभी की समीक्षा करें';

  @override
  String get leaderDashboardNoPendingLoans => 'कोई लंबित ऋण अनुरोध नहीं';

  @override
  String get leaderDashboardNextMeetingTitle => 'अगली बैठक';

  @override
  String get leaderDashboardManageAction => 'प्रबंधित करें';

  @override
  String get leaderDashboardMeetingFallback => 'बैठक';

  @override
  String get leaderDashboardShgHealthTitle => 'SHG स्वास्थ्य';

  @override
  String get leaderDashboardGradingLabel => 'ग्रेडिंग';

  @override
  String get leaderDashboardAttendanceLabel => 'उपस्थिति';

  @override
  String get leaderDashboardRecoveryLabel => 'रिकवरी';

  @override
  String get memberDashboardMySavingsLabel => 'मेरी बचत';

  @override
  String memberDashboardSavingsEntriesTrend(int count) {
    return '$count प्रविष्टियां';
  }

  @override
  String get memberDashboardOutstandingLoanLabel => 'बकाया ऋण';

  @override
  String memberDashboardNextEmiTrend(String date) {
    return 'अगली EMI $date';
  }

  @override
  String get memberDashboardNoDuesTrend => 'कोई बकाया नहीं';

  @override
  String get memberDashboardAddSavingsTile => 'बचत जोड़ें';

  @override
  String get memberDashboardApplyLoanTile => 'ऋण के लिए आवेदन करें';

  @override
  String get memberDashboardAttendanceLabel => 'उपस्थिति';

  @override
  String get memberDashboardSchemesTile => 'योजनाएं';

  @override
  String memberDashboardSchemesNewBadge(int count) {
    return 'योजनाएं, $count नई';
  }

  @override
  String memberDashboardNewSchemesCount(int count) {
    return '$count नई';
  }

  @override
  String get memberDashboardSchemesAvailableLabel => 'उपलब्ध योजनाएं';

  @override
  String get memberDashboardSavingsSummaryTitle => 'बचत सारांश';

  @override
  String get memberDashboardViewAllAction => 'सभी देखें';

  @override
  String get memberDashboardLoanSummaryTitle => 'ऋण सारांश';

  @override
  String get memberDashboardTrackAction => 'ट्रैक करें';

  @override
  String memberDashboardOfAmount(String amount) {
    return '₹$amount में से';
  }

  @override
  String memberDashboardEmiDueBadge(String amount, String date) {
    return 'EMI ₹$amount, $date को देय';
  }

  @override
  String memberDashboardEmiBadge(String amount) {
    return 'EMI ₹$amount';
  }

  @override
  String get memberDashboardPayNowAction => 'अभी भुगतान करें';

  @override
  String get memberDashboardMeetingAlertLabel => 'बैठक अलर्ट';

  @override
  String get memberDashboardMeetingFallback => 'बैठक';

  @override
  String get memberDashboardDetailsAction => 'विवरण';

  @override
  String get memberDashboardTrainingAlertLabel => 'प्रशिक्षण अलर्ट';

  @override
  String get memberDashboardContinueAction => 'जारी रखें';

  @override
  String get memberDashboardAiAdvisorTitle => 'AI वित्तीय सलाहकार';

  @override
  String get memberDashboardAiAdvisorSubtitle =>
      'बचत, ऋण और बजट के बारे में पूछें';

  @override
  String get memberDashboardViewAction => 'देखें';

  @override
  String get memberDashboardRecentAnnouncementsTitle => 'हाल की घोषणाएं';

  @override
  String get memberDashboardSeeAllAction => 'सभी देखें';

  @override
  String get memberDashboardNoAnnouncementsYet => 'अभी तक कोई घोषणा नहीं';

  @override
  String get memberDashboardUnreadLabel => 'अपठित';

  @override
  String memberDashboardSavingsTrendChartSemanticLabel(String summary) {
    return 'बचत ट्रेंड चार्ट: $summary';
  }

  @override
  String get attendanceReportTitle => 'उपस्थिति रिपोर्ट';

  @override
  String get attendanceReportEmpty => 'अभी तक कोई बैठक पूरी नहीं हुई';

  @override
  String get attendanceReportOverallLabel => 'कुल उपस्थिति';

  @override
  String attendanceReportSummary(int present, int total) {
    return '$total में से $present बैठकों में उपस्थित';
  }

  @override
  String get federationGrowthTitle => 'बचत वृद्धि';

  @override
  String get federationGrowthEmpty => 'अभी तक कोई बचत दर्ज नहीं हुई';

  @override
  String get federationGrowthSubtitle => 'हर SHG की मासिक कुल बचत';

  @override
  String get federationRecoveryTitle => 'ऋण वसूली';

  @override
  String get federationRecoveryLoansDisbursed => 'वितरित ऋण';

  @override
  String get federationRecoveryRateLabel => 'वसूली दर';

  @override
  String get federationRecoveryRecoveredLabel => 'वसूल किया गया';

  @override
  String get federationRecoveryFootnote =>
      'हर SHG के सक्रिय, बकाया और बंद ऋणों में';

  @override
  String get federationReportsTitle => 'फेडरेशन रिपोर्ट्स';

  @override
  String get federationReportsVillagesTitle => 'गांव-वार SHGs';

  @override
  String get federationReportsVillagesSubtitle =>
      'प्रति गांव SHG संख्या और बचत';

  @override
  String get federationReportsRecoveryTitle => 'ऋण वसूली';

  @override
  String get federationReportsRecoverySubtitle =>
      'हर SHG में वितरित बनाम चुकाई गई राशि';

  @override
  String get federationReportsGrowthTitle => 'बचत वृद्धि';

  @override
  String get federationReportsGrowthSubtitle =>
      'मासिक बचत रुझान, पूरे फेडरेशन में';

  @override
  String get federationVillagesTitle => 'गांव-वार SHGs';

  @override
  String get federationVillagesEmpty => 'अभी तक कोई SHG पंजीकृत नहीं है';

  @override
  String federationVillagesShgCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SHGs',
      one: 'SHG',
    );
    return '$count $_temp0';
  }

  @override
  String get loanStatementTitle => 'ऋण स्टेटमेंट';

  @override
  String get loanStatementEmpty => 'अभी स्टेटमेंट के लिए कोई ऋण नहीं है';

  @override
  String get loanStatementTotalOutstandingLabel => 'कुल बकाया';

  @override
  String loanStatementLoanCount(int count) {
    return '$count ऋण';
  }

  @override
  String loanStatementRepaidAmount(String amount) {
    return 'चुकाया ₹$amount';
  }

  @override
  String loanStatementAmountLabel(String amount) {
    return 'राशि ₹$amount';
  }

  @override
  String loanStatementOutstandingAmount(String amount) {
    return 'बकाया ₹$amount';
  }

  @override
  String loanStatementDisbursedOn(String date) {
    return 'वितरित $date';
  }

  @override
  String get memberReportTitle => 'मेरी रिपोर्ट्स';

  @override
  String get memberReportTotalSavingsLabel => 'कुल बचत';

  @override
  String memberReportEntriesTrend(int count) {
    return '$count एंट्री';
  }

  @override
  String get memberReportLoanOutstandingLabel => 'बकाया ऋण';

  @override
  String memberReportActiveLoansTrend(int count) {
    return '$count सक्रिय';
  }

  @override
  String get memberReportSectionTitle => 'रिपोर्ट्स';

  @override
  String get memberReportSavingsStatementTitle => 'बचत स्टेटमेंट';

  @override
  String get memberReportSavingsStatementSubtitle =>
      'हर बचत एंट्री के साथ चालू शेष राशि';

  @override
  String get memberReportLoanStatementTitle => 'ऋण स्टेटमेंट';

  @override
  String get memberReportLoanStatementSubtitle =>
      'हर ऋण, EMI शेड्यूल और बकाया राशि';

  @override
  String get memberReportAttendanceTitle => 'उपस्थिति रिपोर्ट';

  @override
  String memberReportAttendanceSubtitle(String pct, int present, int total) {
    return '$pct% · $total में से $present बैठकें';
  }

  @override
  String get reportsHubTitle => 'रिपोर्ट्स';

  @override
  String get reportsHubMyReportsTitle => 'मेरी रिपोर्ट्स';

  @override
  String get reportsHubMyReportsSubtitle =>
      'आपकी बचत, ऋण और उपस्थिति का सारांश';

  @override
  String get reportsHubShgReportsTitle => 'SHG रिपोर्ट्स';

  @override
  String get reportsHubShgReportsSubtitle => 'पूरे समूह की बचत, ऋण और उपस्थिति';

  @override
  String get reportsHubFederationReportsTitle => 'फेडरेशन रिपोर्ट्स';

  @override
  String get reportsHubFederationReportsSubtitle =>
      'सभी SHG का कुल मिलाकर डेटा';

  @override
  String get shgFinancialSummaryTitle => 'वित्तीय सारांश';

  @override
  String get shgFinancialSummaryMembersLabel => 'सदस्य';

  @override
  String get shgFinancialSummaryActiveLoansLabel => 'सक्रिय ऋण';

  @override
  String get shgFinancialSummaryTotalSavingsLabel => 'कुल बचत';

  @override
  String get shgFinancialSummaryLoanOutstandingLabel => 'बकाया ऋण';

  @override
  String get shgFinancialSummaryAvgAttendanceLabel => 'औसत उपस्थिति';

  @override
  String get shgPerformanceReportTitle => 'प्रदर्शन रिपोर्ट';

  @override
  String get shgPerformanceAvgAttendanceLabel => 'औसत उपस्थिति';

  @override
  String get shgPerformanceActiveLoansLabel => 'सक्रिय ऋण';

  @override
  String get shgPerformanceAttendanceTrendLabel => 'उपस्थिति रुझान';

  @override
  String get shgPerformanceEmptyTrend => 'अभी तक कोई बैठक पूरी नहीं हुई';

  @override
  String get shgReportsTitle => 'SHG रिपोर्ट्स';

  @override
  String get shgReportsFinancialSummaryTitle => 'वित्तीय सारांश';

  @override
  String get shgReportsFinancialSummarySubtitle =>
      'एक नज़र में बचत, ऋण और उपस्थिति';

  @override
  String get shgReportsAuditReportTitle => 'ऑडिट रिपोर्ट';

  @override
  String get shgReportsAuditReportSubtitle => 'आंतरिक और बाहरी ऑडिट का रिकॉर्ड';

  @override
  String get shgReportsPerformanceReportTitle => 'प्रदर्शन रिपोर्ट';

  @override
  String get shgReportsPerformanceReportSubtitle =>
      'उपस्थिति रुझान और ऋण गतिविधि';

  @override
  String get addProductTitle => 'उत्पाद जोड़ें';

  @override
  String get addProductImageTooLarge =>
      'इमेज बहुत बड़ी है — कृपया 5 MB से कम की कोई इमेज चुनें';

  @override
  String get addProductAddPhotoOptional => 'एक फोटो जोड़ें (वैकल्पिक)';

  @override
  String get addProductNameLabel => 'उत्पाद का नाम';

  @override
  String get addProductNameHint => 'उदाहरण: हाथ से बुनी कॉटन साड़ी';

  @override
  String get addProductDescriptionLabel => 'विवरण';

  @override
  String get addProductDescriptionHint => 'अपने उत्पाद के बारे में बताएं';

  @override
  String get addProductPriceLabel => 'कीमत (₹)';

  @override
  String get addProductStockLabel => 'स्टॉक';

  @override
  String get addProductCategoryLabel => 'श्रेणी';

  @override
  String get addProductNameRequired => 'उत्पाद का नाम दर्ज करें';

  @override
  String get addProductInvalidPrice => 'एक सही कीमत दर्ज करें';

  @override
  String get addProductPriceTooLarge =>
      'कीमत असामान्य रूप से ज़्यादा लग रही है — कृपया जांचकर फिर से दर्ज करें';

  @override
  String get addProductSubmitError =>
      'इस उत्पाद को सूचीबद्ध नहीं किया जा सका। कृपया फिर से कोशिश करें।';

  @override
  String get addProductListedSuccess => 'उत्पाद सूचीबद्ध हो गया';

  @override
  String get addProductDemoModeNotSaved =>
      'डेमो मोड — उत्पाद सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get addProductListingInProgress => 'सूचीबद्ध हो रहा है…';

  @override
  String get addProductSubmitButton => 'उत्पाद सूचीबद्ध करें';

  @override
  String get marketplaceHomeTitle => 'बाज़ार';

  @override
  String get marketplaceHomeAddProductTooltip => 'उत्पाद जोड़ें';

  @override
  String get marketplaceHomeSellTile => 'बेचें';

  @override
  String get marketplaceHomeOrdersTile => 'ऑर्डर';

  @override
  String get marketplaceHomeReviewsTile => 'समीक्षाएं';

  @override
  String get marketplaceHomeBrowseProducts => 'उत्पाद देखें';

  @override
  String get marketplaceHomeEmptyProducts =>
      'अभी तक कोई उत्पाद सूचीबद्ध नहीं है';

  @override
  String get marketplaceOrdersTitle => 'ऑर्डर';

  @override
  String get marketplaceOrdersEmpty => 'अभी तक कोई ऑर्डर नहीं है';

  @override
  String get marketplaceReviewsTitle => 'समीक्षाएं';

  @override
  String get marketplaceReviewsEmpty =>
      'आपके उत्पादों पर अभी तक कोई समीक्षा नहीं है';

  @override
  String marketplaceReviewsFromCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'समीक्षाओं',
      one: 'समीक्षा',
    );
    return '$count $_temp0 के आधार पर';
  }

  @override
  String marketplaceReviewsRatingSemantics(int rating) {
    return '5 में से $rating सितारे';
  }

  @override
  String get orderDetailTitle => 'ऑर्डर विवरण';

  @override
  String get orderDetailNotFound => 'यह ऑर्डर नहीं मिल सका';

  @override
  String get orderDetailUpdateStatusError =>
      'ऑर्डर की स्थिति अपडेट नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get orderDetailUpdateStatusLabel => 'स्थिति अपडेट करें';

  @override
  String orderDetailBuyerLabel(String name) {
    return 'खरीदार: $name';
  }

  @override
  String orderDetailOrderedOn(String date) {
    return 'ऑर्डर किया गया $date';
  }

  @override
  String get productDetailTitle => 'उत्पाद';

  @override
  String get productDetailNotFound => 'यह उत्पाद नहीं मिल सका';

  @override
  String get productDetailWriteReviewTitle => 'समीक्षा लिखें';

  @override
  String productDetailStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सितारे',
      one: 'सितारा',
    );
    return '$count $_temp0';
  }

  @override
  String get productDetailReviewHint =>
      'इस उत्पाद के साथ अपना अनुभव साझा करें (वैकल्पिक)';

  @override
  String get productDetailReviewSubmitted => 'समीक्षा सबमिट हो गई';

  @override
  String get productDetailReviewDemoMode =>
      'डेमो मोड — समीक्षा सेव नहीं हुई (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get productDetailReviewSubmitError =>
      'आपकी समीक्षा सबमिट नहीं हो सकी। हो सकता है आपको पहले यह उत्पाद खरीदना पड़े।';

  @override
  String get productDetailOrderPlaced => 'ऑर्डर दिया गया';

  @override
  String get productDetailOrderDemoMode =>
      'डेमो मोड — ऑर्डर सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get productDetailOrderPlaceError =>
      'यह ऑर्डर नहीं दिया जा सका। कृपया फिर से कोशिश करें।';

  @override
  String productDetailBySeller(String name) {
    return '$name द्वारा';
  }

  @override
  String productDetailInStock(int count) {
    return 'स्टॉक में $count';
  }

  @override
  String get productDetailReviewsSection => 'समीक्षाएं';

  @override
  String get productDetailSubmittingAction => 'सबमिट हो रहा है…';

  @override
  String get productDetailWriteReviewAction => 'समीक्षा लिखें';

  @override
  String get productDetailNoReviewsYet => 'अभी तक कोई समीक्षा नहीं है';

  @override
  String productDetailReviewRatingSemantics(int rating) {
    return '5 में से $rating सितारे';
  }

  @override
  String get productDetailPlacingInProgress => 'ऑर्डर दिया जा रहा है…';

  @override
  String get productDetailPlaceOrderButton => 'ऑर्डर करें';

  @override
  String get meetingsHomeTitle => 'बैठकें';

  @override
  String get meetingsHomeScheduleTooltip => 'बैठक शेड्यूल करें';

  @override
  String get meetingsHomeCheckIn => 'चेक-इन';

  @override
  String get meetingsHomeScheduleLabel => 'शेड्यूल';

  @override
  String get meetingsHomeAttendanceLabel => 'उपस्थिति';

  @override
  String get meetingsHomeUpcoming => 'आने वाली';

  @override
  String get meetingsHomePastMeetings => 'पिछली बैठकें';

  @override
  String get meetingsHomeNoPastMeetings => 'अभी तक कोई पिछली बैठक नहीं';

  @override
  String get meetingsHomeDefaultTitle => 'बैठक';

  @override
  String get meetingDetailTitle => 'बैठक विवरण';

  @override
  String get meetingDetailNotFound => 'यह बैठक नहीं मिली';

  @override
  String get meetingDetailDefaultTitle => 'बैठक';

  @override
  String get meetingDetailMinutesLabel => 'बैठक का ब्यौरा';

  @override
  String get meetingDetailCancelDialogTitle => 'बैठक रद्द करें?';

  @override
  String meetingDetailCancelDialogContent(String date) {
    return 'यह $date की बैठक को रद्द के रूप में चिह्नित कर देगा। सदस्यों को यह आने वाली की जगह रद्द दिखाई देगी।';
  }

  @override
  String get meetingDetailKeepMeeting => 'बैठक रखें';

  @override
  String get meetingDetailCancelMeeting => 'बैठक रद्द करें';

  @override
  String get meetingDetailCancelling => 'रद्द हो रहा है…';

  @override
  String get meetingDetailCancelledSuccess => 'बैठक रद्द हो गई';

  @override
  String get meetingDetailCancelledDemoMode =>
      'डेमो मोड — इस सत्र के बाकी समय के लिए रद्द (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get meetingDetailCancelError =>
      'बैठक रद्द नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get meetingDetailAttendanceSection => 'उपस्थिति';

  @override
  String get meetingDetailMarkAction => 'दर्ज करें';

  @override
  String meetingDetailPresentCount(int present, int total) {
    return '$present / $total उपस्थित';
  }

  @override
  String get meetingAttendanceTitle => 'उपस्थिति';

  @override
  String get meetingAttendanceNoMeetings =>
      'उपस्थिति दर्ज करने के लिए कोई बैठक नहीं है';

  @override
  String get meetingAttendanceNoMembers =>
      'उपस्थिति दर्ज करने के लिए कोई सदस्य नहीं है';

  @override
  String meetingAttendancePresentCount(int present, int total) {
    return '$present / $total उपस्थित';
  }

  @override
  String get meetingAttendanceUpdateError =>
      'उपस्थिति अपडेट नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get meetingMomTitle => 'बैठक का ब्यौरा';

  @override
  String get meetingMomNotFound => 'यह बैठक नहीं मिली';

  @override
  String get meetingMomDemoModeNotSaved =>
      'डेमो मोड — सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get meetingMomSaveDecisionError =>
      'यह निर्णय सेव नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get meetingMomSaveActionItemError =>
      'यह कार्य सेव नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get meetingMomDecisionsSection => 'निर्णय';

  @override
  String get meetingMomNoDecisions => 'अभी तक कोई निर्णय दर्ज नहीं हुआ';

  @override
  String get meetingMomAddDecisionHint => 'एक निर्णय जोड़ें…';

  @override
  String get meetingMomAddDecisionTooltip => 'निर्णय जोड़ें';

  @override
  String get meetingMomActionItemsSection => 'कार्य';

  @override
  String get meetingMomNoActionItems => 'अभी तक कोई कार्य नहीं है';

  @override
  String get meetingMomUpdateActionItemError =>
      'यह कार्य अपडेट नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String meetingMomAssignedTo(String name) {
    return '$name को सौंपा गया';
  }

  @override
  String meetingMomDueDate(String date) {
    return 'अंतिम तिथि: $date';
  }

  @override
  String get meetingMomAssignToLabel => 'सौंपें';

  @override
  String get meetingMomUnassigned => 'कोई नहीं';

  @override
  String get meetingMomAddTaskHint => 'एक कार्य जोड़ें…';

  @override
  String get meetingMomAddActionItemTooltip => 'कार्य जोड़ें';

  @override
  String get meetingScheduleTitle => 'बैठक शेड्यूल करें';

  @override
  String get meetingScheduleSubmitting => 'शेड्यूल हो रहा है…';

  @override
  String get meetingScheduleEnterVenueError => 'स्थल दर्ज करें';

  @override
  String get meetingScheduleNoShgError =>
      'आप किसी SHG से जुड़े नहीं हैं, इसलिए इस बैठक को शेड्यूल करने के लिए कुछ नहीं है।';

  @override
  String get meetingScheduleSuccess => 'बैठक शेड्यूल हो गई';

  @override
  String get meetingScheduleDemoMode =>
      'डेमो मोड — बैठक सेव नहीं हुई (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get meetingScheduleError =>
      'बैठक शेड्यूल नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get meetingScheduleDateLabel => 'तारीख';

  @override
  String get meetingScheduleTimeLabel => 'समय';

  @override
  String get meetingScheduleVenueLabel => 'स्थल';

  @override
  String get meetingScheduleVenueHint => 'जैसे, आंगनवाड़ी केंद्र, कोंडापुर';

  @override
  String get meetingScheduleAgendaLabel => 'एजेंडा';

  @override
  String get meetingScheduleAgendaHint => 'जैसे, मासिक बचत समीक्षा और ऋण आवेदन';

  @override
  String get savingsEntryTitle => 'बचत जोड़ें';

  @override
  String get savingsEntryMemberLabel => 'सदस्य';

  @override
  String get savingsEntryNoMembersFound =>
      'आपके SHG में अभी तक कोई सदस्य नहीं है — इस एंट्री को किसी के नाम दर्ज करने के लिए कोई नहीं है।';

  @override
  String get savingsEntrySelectMember => 'एक सदस्य चुनें';

  @override
  String get savingsEntryAmountLabel => 'राशि';

  @override
  String get savingsEntryAmountRequired => 'राशि दर्ज करें';

  @override
  String get savingsEntryAmountInvalid => 'एक सही संख्या दर्ज करें';

  @override
  String get savingsEntryAmountZero => 'राशि शून्य से अधिक होनी चाहिए';

  @override
  String get savingsEntryAmountTooLarge =>
      'यह राशि असामान्य रूप से बड़ी लग रही है — कृपया जांचें और फिर से दर्ज करें';

  @override
  String get savingsEntryPaymentModeLabel => 'भुगतान का तरीका';

  @override
  String get savingsEntryFrequencyLabel => 'कितनी बार';

  @override
  String get savingsEntryNoShgError =>
      'आप किसी SHG से जुड़े नहीं हैं, इसलिए इस एंट्री को दर्ज करने के लिए कुछ नहीं है।';

  @override
  String get savingsEntrySubmittedMessage =>
      'बचत एंट्री सत्यापन के लिए भेज दी गई है';

  @override
  String get savingsEntryDemoModeMessage =>
      'डेमो मोड — एंट्री सेव नहीं हुई (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get savingsEntrySaveError =>
      'यह एंट्री सेव नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get savingsEntrySaving => 'सेव हो रहा है…';

  @override
  String get savingsEntrySubmit => 'एंट्री सबमिट करें';

  @override
  String get savingsGroupReportTitle => 'समूह बचत रिपोर्ट';

  @override
  String get savingsGroupReportEmpty => 'अभी तक कोई समूह बचत डेटा नहीं है';

  @override
  String get savingsGroupReportTotalLabel => 'समूह की कुल राशि';

  @override
  String savingsGroupReportSummary(int memberCount, int monthCount) {
    String _temp0 = intl.Intl.pluralLogic(
      monthCount,
      locale: localeName,
      other: 'महीनों की गतिविधि',
      one: 'महीने की गतिविधि',
    );
    return '$memberCount सदस्य योगदान दे रहे हैं · $monthCount $_temp0';
  }

  @override
  String savingsGroupReportRank(int rank) {
    return 'रैंक #$rank';
  }

  @override
  String get savingsHistoryTitle => 'बचत इतिहास';

  @override
  String get savingsHistoryEmpty => 'अभी तक कोई बचत इतिहास नहीं है';

  @override
  String savingsFrequencyEntryTitle(String frequency) {
    return '$frequency बचत';
  }

  @override
  String get savingsHomeTitle => 'बचत';

  @override
  String get savingsHomeAddTooltip => 'बचत जोड़ें';

  @override
  String get savingsHomeGroupSavingsLabel => 'समूह बचत';

  @override
  String get savingsHomeMySavingsLabel => 'मेरी बचत';

  @override
  String savingsHomeEntriesCount(int count) {
    return '$count एंट्री';
  }

  @override
  String get savingsHomePendingVerificationLabel => 'पेंडिंग सत्यापन';

  @override
  String get savingsHomeNeedsReview => 'समीक्षा बाकी';

  @override
  String get savingsHomeAllCaughtUp => 'सब कुछ निपटा दिया गया';

  @override
  String get savingsHomeAddSavingsTile => 'बचत जोड़ें';

  @override
  String get savingsHomeHistoryTile => 'इतिहास';

  @override
  String get savingsHomeStatementTile => 'स्टेटमेंट';

  @override
  String get savingsHomeLedgerTile => 'लेजर';

  @override
  String get savingsHomeGroupTile => 'समूह';

  @override
  String get savingsHomeRecentEntriesTitle => 'हाल की एंट्रियां';

  @override
  String get savingsHomeViewAllAction => 'सभी देखें';

  @override
  String get savingsHomeEmpty => 'अभी तक कोई बचत एंट्री नहीं है';

  @override
  String get savingsStatementTitle => 'बचत स्टेटमेंट';

  @override
  String get savingsStatementEmpty => 'अभी तक कोई एंट्री नहीं है';

  @override
  String get savingsStatementClosingBalance => 'क्लोजिंग बैलेंस';

  @override
  String savingsStatementTransactionsCount(int count) {
    return '$count लेनदेन';
  }

  @override
  String get savingsStatementDateModeHeader => 'तारीख / तरीका';

  @override
  String get savingsStatementAmountBalanceHeader => 'राशि / बैलेंस';

  @override
  String get schemeEligibilityTitle => 'पात्रता जांच';

  @override
  String get schemeEligibilityIntro =>
      'यह आपके SHG की सदस्यता, पंजीकरण की उम्र और ग्रेड के आधार पर स्वचालित रूप से जांचा जाता है। कुछ शर्तें — जैसे BPL स्थिति या पहले ली गई सब्सिडी — अभी भी मैन्युअल जांच की ज़रूरत रखती हैं; उनके लिए हर योजना की पूरी पात्रता सूची देखें।';

  @override
  String get schemeEligibilityEmptyCatalog =>
      'अभी तक सूची में कोई योजना नहीं है';

  @override
  String get schemeEligibilitySeeFullDetails => 'पूरी जानकारी देखें';

  @override
  String get schemeEligibilityEligible => 'पात्र';

  @override
  String get schemeEligibilityNotEligible => 'अपात्र';

  @override
  String get schemeEligibilityNoCriteria =>
      'इस योजना के लिए कोई स्वचालित पात्रता शर्तें तय नहीं हैं — पूरी शर्तें देखने के लिए इसे खोलें।';

  @override
  String get schemesHomeTitle => 'सरकारी योजनाएं';

  @override
  String get schemesHomeEligibilityTile => 'पात्रता';

  @override
  String get schemesHomeTrackingTile => 'ट्रैकिंग';

  @override
  String get schemesHomeApplicationsTile => 'आवेदन';

  @override
  String get schemesHomeAllSchemesSection => 'सभी योजनाएं';

  @override
  String get schemesHomeEmptyState => 'अभी कोई योजना उपलब्ध नहीं है';

  @override
  String get schemesHomeNotApplied => 'आवेदन नहीं किया';

  @override
  String get schemeDetailApplicationSubmitted => 'आवेदन जमा किया गया';

  @override
  String get schemeDetailApplyError =>
      'यह आवेदन जमा नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get schemeDetailTitle => 'योजना विवरण';

  @override
  String get schemeDetailNotFound => 'यह योजना नहीं मिली';

  @override
  String get schemeDetailBenefitSection => 'लाभ';

  @override
  String get schemeDetailEligibilitySection => 'पात्रता';

  @override
  String get schemeDetailApplicationStatusLabel => 'आवेदन की स्थिति: ';

  @override
  String get schemeDetailDeadlinePassed =>
      'आवेदन बंद हैं — इस योजना की अंतिम तिथि निकल चुकी है।';

  @override
  String get schemeDetailSubmitting => 'सबमिट हो रहा है…';

  @override
  String get schemeDetailApplyNow => 'अभी आवेदन करें';

  @override
  String schemeDetailDeadlineLabel(String date) {
    return 'अंतिम तिथि: $date';
  }

  @override
  String get schemeTrackingTitle => 'आवेदन ट्रैकिंग';

  @override
  String get schemeTrackingEmptyState =>
      'आपने अभी तक किसी योजना के लिए आवेदन नहीं किया है';

  @override
  String get schemeApplicationsReviewApproved => 'आवेदन स्वीकृत किया गया';

  @override
  String get schemeApplicationsReviewRejected => 'आवेदन अस्वीकृत किया गया';

  @override
  String get schemeApplicationsReviewAlreadyDecided =>
      'इस आवेदन पर पहले ही किसी और ने निर्णय ले लिया है।';

  @override
  String get schemeApplicationsReviewSaveError =>
      'यह निर्णय सेव नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get schemeApplicationsReviewTitle => 'योजना आवेदन';

  @override
  String get schemeApplicationsReviewEmptyState => 'कोई लंबित योजना आवेदन नहीं';

  @override
  String schemeApplicationsReviewAppliedOn(String date) {
    return '$date को आवेदन किया';
  }

  @override
  String get schemeApplicationsReviewReject => 'अस्वीकार करें';

  @override
  String get schemeApplicationsReviewSaving => 'सेव हो रहा है…';

  @override
  String get schemeApplicationsReviewApprove => 'स्वीकृत करें';

  @override
  String get supportStatusOpen => 'खुला';

  @override
  String get supportStatusInProgress => 'चल रहा है';

  @override
  String get supportStatusResolved => 'सुलझा';

  @override
  String get supportStatusClosed => 'बंद';

  @override
  String get supportChatTitle => 'चैट सहायता';

  @override
  String get supportChatEmptyMessage =>
      'अभी तक कोई बातचीत नहीं — शुरू करने के लिए एक टिकट दर्ज करें';

  @override
  String get supportFaqTitle => 'सामान्य सवाल';

  @override
  String get supportHomeTitle => 'सहायता';

  @override
  String get supportHomeMyTickets => 'मेरे टिकट';

  @override
  String get supportHomeRaiseTicket => 'टिकट दर्ज करें';

  @override
  String get supportHomeVoiceHelp => 'आवाज़ सहायता';

  @override
  String get supportHomeFaqs => 'सामान्य सवाल';

  @override
  String get supportHomeAllTickets => 'सभी टिकट';

  @override
  String get supportHomeViewAll => 'सभी देखें';

  @override
  String get supportHomeEmptyMessage => 'अभी तक कोई सहायता टिकट नहीं है';

  @override
  String get supportTicketDetailSendError =>
      'यह संदेश नहीं भेजा जा सका। कृपया फिर से कोशिश करें।';

  @override
  String get supportTicketDetailStatusError =>
      'टिकट की स्थिति अपडेट नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get supportTicketDetailTitle => 'टिकट';

  @override
  String get supportTicketDetailNotFound => 'यह टिकट नहीं मिल सका';

  @override
  String get supportTicketDetailNoMessages => 'अभी तक कोई संदेश नहीं';

  @override
  String get supportTicketDetailYou => 'आप';

  @override
  String get supportTicketDetailStaff => 'स्टाफ';

  @override
  String get supportTicketDetailComposerHint => 'संदेश टाइप करें…';

  @override
  String get supportTicketDetailDemoModeHint => 'डेमो मोड — जवाब देना बंद है';

  @override
  String get supportTicketDetailSendTooltip => 'संदेश भेजें';

  @override
  String get supportTicketFormTitle => 'टिकट दर्ज करें';

  @override
  String get supportTicketFormSubjectLabel => 'विषय';

  @override
  String get supportTicketFormSubjectHint => 'जैसे: ऋण वितरण में देरी';

  @override
  String get supportTicketFormDescriptionLabel => 'अपनी समस्या बताएं';

  @override
  String get supportTicketFormDescriptionHint => 'जितना हो सके उतना विवरण दें';

  @override
  String get supportTicketFormSubjectRequired =>
      'अपनी समस्या का विषय दर्ज करें';

  @override
  String get supportTicketFormSubmitting => 'सबमिट हो रहा है…';

  @override
  String get supportTicketFormSubmit => 'टिकट सबमिट करें';

  @override
  String get supportTicketFormRaisedSuccess => 'टिकट दर्ज हो गया';

  @override
  String get supportTicketFormDemoModeMessage =>
      'डेमो मोड — टिकट सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get supportTicketFormRaiseError =>
      'यह टिकट दर्ज नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get supportVoiceTitle => 'आवाज़ सहायता';

  @override
  String get supportVoiceTapToAsk => 'सवाल पूछने के लिए टैप करें';

  @override
  String get supportVoiceListening => 'सुन रहा है…';

  @override
  String get supportVoiceThinking => 'जवाब ढूंढ रहे हैं…';

  @override
  String get supportVoiceTapToAskAgain => 'फिर से पूछने के लिए टैप करें';

  @override
  String get supportVoiceError =>
      'माफ़ कीजिए, कुछ गलत हो गया। कृपया फिर से कोशिश करें।';

  @override
  String get supportVoiceYouAsked => 'आपने पूछा';

  @override
  String get supportVoiceAnswerLabel => 'जवाब';

  @override
  String get memberDetailTitle => 'सदस्य विवरण';

  @override
  String get memberDetailNotFound => 'यह सदस्य नहीं मिल सका';

  @override
  String get memberDetailTotalSavings => 'कुल बचत';

  @override
  String get memberDetailLoanOutstanding => 'बकाया ऋण';

  @override
  String get memberDetailContactSection => 'संपर्क';

  @override
  String get memberDetailMobileLabel => 'मोबाइल';

  @override
  String get memberDetailVillageLabel => 'गांव';

  @override
  String get shgHomeTitle => 'मेरा SHG';

  @override
  String get shgHomeNotLinked => 'आप अभी तक किसी SHG से जुड़े नहीं हैं';

  @override
  String shgHomeRegNumberLabel(String regNumber) {
    return 'रजि. नं. $regNumber';
  }

  @override
  String get shgHomeMembersTile => 'सदस्य';

  @override
  String get shgHomeDocumentsTile => 'दस्तावेज़';

  @override
  String get shgHomeFederationSection => 'फेडरेशन';

  @override
  String get shgHomeVillageOrgLabel => 'ग्राम संगठन';

  @override
  String get shgHomeClfLabel => 'CLF';

  @override
  String get shgHomeMandalLabel => 'मंडल';

  @override
  String get shgHomeFormedLabel => 'स्थापना';

  @override
  String get shgHomeBankDetailsSection => 'बैंक विवरण';

  @override
  String get shgHomeBankLabel => 'बैंक';

  @override
  String get shgHomeAccountLabel => 'खाता';

  @override
  String get shgHomeIfscLabel => 'IFSC';

  @override
  String get shgDocumentsTitle => 'दस्तावेज़';

  @override
  String get shgDocumentsAddTooltip => 'दस्तावेज़ जोड़ें';

  @override
  String get shgDocumentsEmpty => 'अभी तक कोई दस्तावेज़ अपलोड नहीं किया गया';

  @override
  String get shgDocumentsAddDialogTitle => 'दस्तावेज़ जोड़ें';

  @override
  String get shgDocumentsNameHint => 'दस्तावेज़ का नाम';

  @override
  String get shgDocumentsChooseFile => 'फ़ाइल चुनें (PDF, JPG, PNG, WEBP)';

  @override
  String get shgDocumentsFileTooLarge =>
      'फ़ाइल बहुत बड़ी है — कृपया 10 MB से छोटी फ़ाइल चुनें';

  @override
  String get shgDocumentsNameRequired => 'दस्तावेज़ का नाम आवश्यक है।';

  @override
  String get shgDocumentsFileRequired =>
      'कृपया अपलोड करने के लिए एक फ़ाइल चुनें।';

  @override
  String get shgDocumentsNotLinked =>
      'आप किसी SHG से जुड़े नहीं हैं, इसलिए इस दस्तावेज़ को जोड़ने के लिए कुछ नहीं है।';

  @override
  String get shgDocumentsAdded => 'दस्तावेज़ जोड़ा गया';

  @override
  String get shgDocumentsAddError =>
      'यह दस्तावेज़ जोड़ा नहीं जा सका। कृपया पुनः प्रयास करें।';

  @override
  String get shgDocumentsNoFileAttached =>
      'इस रिकॉर्ड से कोई फ़ाइल जुड़ी नहीं है।';

  @override
  String get shgDocumentsOpenError => 'यह दस्तावेज़ खोला नहीं जा सका।';

  @override
  String get shgJoinRequestsApproved => 'अनुरोध स्वीकृत हो गया';

  @override
  String get shgJoinRequestsRejected => 'अनुरोध अस्वीकृत हो गया';

  @override
  String get shgJoinRequestsDemoMode =>
      'डेमो मोड — सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get shgJoinRequestsProcessError =>
      'यह अनुरोध पूरा नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get shgJoinRequestsTitle => 'जुड़ने के अनुरोध';

  @override
  String get shgJoinRequestsEmpty =>
      'फ़िलहाल जुड़ने का कोई अनुरोध लंबित नहीं है';

  @override
  String get shgJoinRequestsMemberFallback => 'सदस्य';

  @override
  String shgJoinRequestsRequestedOn(String date) {
    return '$date को अनुरोध किया गया';
  }

  @override
  String get shgJoinRequestsReject => 'अस्वीकार करें';

  @override
  String get shgJoinRequestsWorking => 'प्रोसेस हो रहा है…';

  @override
  String get shgJoinRequestsApprove => 'स्वीकार करें';

  @override
  String get shgMembersTitle => 'सदस्य';

  @override
  String get shgMembersJoinRequestsTooltip => 'जुड़ने के अनुरोध';

  @override
  String get shgMembersEmpty => 'कोई सदस्य नहीं मिला';

  @override
  String get certificatesTitle => 'सर्टिफिकेट';

  @override
  String get certificatesEmptyState =>
      'अभी तक कोई सर्टिफिकेट नहीं मिला — एक पाने के लिए कोर्स क्विज़ पूरा करें';

  @override
  String certificatesCompletedOn(String topic, String date) {
    return '$topic · $date को पूरा हुआ';
  }

  @override
  String get courseDetailTitle => 'कोर्स विवरण';

  @override
  String get courseDetailProgressDemoMode =>
      'डेमो मोड — प्रगति सेव नहीं हुई (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get courseDetailProgressError =>
      'आपकी प्रगति सेव नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get courseDetailNotFound => 'यह कोर्स नहीं मिल सका';

  @override
  String get courseDetailCertifiedBadge => 'सर्टिफाइड';

  @override
  String courseDetailPercentComplete(int pct) {
    return '$pct% पूरा';
  }

  @override
  String get courseDetailSaving => 'सेव हो रहा है…';

  @override
  String get courseDetailStartCourse => 'कोर्स शुरू करें';

  @override
  String get courseDetailContinue => 'जारी रखें';

  @override
  String get courseDetailTakeQuiz => 'क्विज़ लें और सर्टिफिकेट पाएं';

  @override
  String get courseDetailCertificateEarned =>
      'आपने इस कोर्स के लिए सर्टिफिकेट पा लिया है!';

  @override
  String get courseQuizTitle => 'कोर्स क्विज़';

  @override
  String courseQuizScoreResult(int score, int total) {
    return 'आपको $score/$total अंक मिले। पास करने के लिए फिर से कोशिश करें।';
  }

  @override
  String get courseQuizPassed => 'पास हो गए! सर्टिफिकेट मिल गया।';

  @override
  String get courseQuizPassedDemoMode =>
      'पास हो गए! डेमो मोड — सर्टिफिकेट सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get courseQuizSaveError =>
      'आपका सर्टिफिकेट सेव नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get courseQuizNotFound => 'यह कोर्स नहीं मिल सका';

  @override
  String get courseQuizNoQuizAvailable =>
      'अभी इस कोर्स के लिए कोई क्विज़ उपलब्ध नहीं है';

  @override
  String get courseQuizSubmitButton => 'क्विज़ सबमिट करें';

  @override
  String get courseQuizSubmitting => 'सबमिट हो रहा है…';

  @override
  String get trainingHomeTitle => 'प्रशिक्षण';

  @override
  String get trainingHomeCertificatesTooltip => 'मेरे सर्टिफिकेट';

  @override
  String get trainingHomeEmpty => 'अभी तक कोई कोर्स उपलब्ध नहीं है';

  @override
  String get trainingHomeCoursesSection => 'कोर्स';

  @override
  String get trainingHomeCertifiedBadge => 'सर्टिफाइड';

  @override
  String get loanApplyTitle => 'ऋण के लिए आवेदन करें';

  @override
  String get loanApplyPurposeLabel => 'उद्देश्य';

  @override
  String get loanApplyPurposeHint => 'जैसे — डेयरी: दुधारू गाय खरीदना';

  @override
  String get loanApplyAmountLabel => 'मांगी गई राशि';

  @override
  String get loanApplyTenureLabel => 'अवधि';

  @override
  String loanApplyTenureMonths(int months) {
    return '$months महीने';
  }

  @override
  String get loanApplySubmitting => 'सबमिट हो रहा है…';

  @override
  String get loanApplySubmitButton => 'आवेदन सबमिट करें';

  @override
  String get loanApplyPurposeRequiredError => 'ऋण किस लिए है, यह बताएं';

  @override
  String get loanApplyInvalidAmountError => 'एक सही राशि दर्ज करें';

  @override
  String get loanApplyAmountTooLargeError =>
      'राशि असामान्य रूप से अधिक लग रही है — कृपया जांचकर फिर से दर्ज करें';

  @override
  String get loanApplyNoShgError =>
      'आप किसी SHG से जुड़े नहीं हैं, इसलिए इस ऋण के लिए आवेदन करने का कोई आधार नहीं है।';

  @override
  String get loanApplySuccessMessage => 'ऋण आवेदन समीक्षा के लिए भेज दिया गया';

  @override
  String get loanApplyDemoModeMessage =>
      'डेमो मोड — आवेदन सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get loanApplySubmitError =>
      'यह आवेदन सबमिट नहीं हो सका। कृपया फिर से कोशिश करें।';

  @override
  String get loansHomeTitle => 'ऋण';

  @override
  String get loansHomeApplyTooltip => 'ऋण के लिए आवेदन करें';

  @override
  String get loansHomeGroupOutstandingLabel => 'समूह की बकाया राशि';

  @override
  String get loansHomeMyOutstandingLabel => 'मेरी बकाया राशि';

  @override
  String loansHomeLoanCount(int count) {
    return '$count ऋण';
  }

  @override
  String get loansHomePendingApprovalLabel => 'अनुमोदन लंबित';

  @override
  String get loansHomeOverdueLabel => 'अतिदेय';

  @override
  String get loansHomeNeedsReviewTrend => 'समीक्षा जरूरी';

  @override
  String get loansHomeActionNeededTrend => 'कार्रवाई जरूरी';

  @override
  String get loansHomeOnTrackTrend => 'समय पर';

  @override
  String get loansHomeApplyLabel => 'आवेदन करें';

  @override
  String get loansHomeTrackingLabel => 'ट्रैकिंग';

  @override
  String get loansHomeApprovalsLabel => 'अनुमोदन';

  @override
  String loansHomeApprovalsBadgeSemanticLabel(int count) {
    return 'अनुमोदन, $count लंबित';
  }

  @override
  String get loansHomeAllLoansTitle => 'सभी ऋण';

  @override
  String get loansHomeMyLoansTitle => 'मेरे ऋण';

  @override
  String get loansHomeEmptyMessage => 'अभी तक कोई ऋण नहीं';

  @override
  String loansHomeOutstandingOfAmount(String outstanding, String amount) {
    return '₹$amount में से ₹$outstanding बकाया';
  }

  @override
  String get loanTrackingTitle => 'ऋण ट्रैकिंग';

  @override
  String get loanTrackingEmptyMessage =>
      'ट्रैक करने के लिए कोई सक्रिय ऋण नहीं है';

  @override
  String loanTrackingOfAmount(String amount) {
    return '₹$amount में से';
  }

  @override
  String loanTrackingEmiDueBadge(String emi, String dueDate) {
    return 'EMI ₹$emi, $dueDate को देय';
  }

  @override
  String get loanTrackingDetailsLink => 'विवरण';

  @override
  String get analyticsDashboardTitle => 'एनालिटिक्स';

  @override
  String get analyticsDashboardTotalShgs => 'कुल SHGs';

  @override
  String get analyticsDashboardActiveMembers => 'सक्रिय सदस्य';

  @override
  String get analyticsDashboardTotalSavings => 'कुल बचत';

  @override
  String get analyticsDashboardLoansDisbursed => 'वितरित ऋण';

  @override
  String get analyticsDashboardLoanRecoveryRate => 'ऋण वसूली दर';

  @override
  String get analyticsDashboardMonitorShgs => 'SHG की निगरानी करें';

  @override
  String get analyticsDashboardPerGroupHealthScores =>
      'प्रत्येक समूह का स्वास्थ्य स्कोर';

  @override
  String get analyticsDashboardChartsLabel => 'चार्ट';

  @override
  String get analyticsDashboardSavingsTrends => 'बचत का रुझान';

  @override
  String get analyticsDashboardLoanTrends => 'ऋण का रुझान';

  @override
  String get analyticsDashboardRevenueTrends => 'राजस्व का रुझान';

  @override
  String get analyticsDashboardAttendanceTrends => 'उपस्थिति का रुझान';

  @override
  String get analyticsDashboardNoDataYet => 'अभी तक कोई डेटा नहीं';

  @override
  String get analyticsShgDetailTitle => 'SHG एनालिटिक्स';

  @override
  String get analyticsShgDetailNotFound => 'यह SHG नहीं मिल सका';

  @override
  String get analyticsShgDetailMembersLabel => 'सदस्य';

  @override
  String get analyticsShgDetailTotalSavings => 'कुल बचत';

  @override
  String get analyticsShgDetailHealthScore => 'स्वास्थ्य स्कोर';

  @override
  String get analyticsShgDetailHealthScoreNote =>
      'समाप्त हुई बैठकों की उपस्थिति दर के आधार पर';

  @override
  String get analyticsShgListTitle => 'SHG निगरानी';

  @override
  String get analyticsShgListEmptyState => 'निगरानी के लिए अभी कोई SHG नहीं है';

  @override
  String analyticsShgListVillageMemberCount(String village, int count) {
    return '$village · $count सदस्य';
  }

  @override
  String get livelihoodEntryTitle => 'गतिविधि जोड़ें';

  @override
  String get livelihoodEntryActivityTypeLabel => 'गतिविधि प्रकार';

  @override
  String get livelihoodEntryTypeDairy => 'डेयरी';

  @override
  String get livelihoodEntryTypeTailoring => 'सिलाई';

  @override
  String get livelihoodEntryTypeRetail => 'खुदरा';

  @override
  String get livelihoodEntryTypePoultry => 'मुर्गी पालन';

  @override
  String get livelihoodEntryTypeAgriculture => 'कृषि';

  @override
  String get livelihoodEntryTypeHandicrafts => 'हस्तशिल्प';

  @override
  String get livelihoodEntryTypeOther => 'अन्य';

  @override
  String get livelihoodEntryDescriptionLabel => 'विवरण';

  @override
  String get livelihoodEntryDescriptionHint =>
      'जैसे, दुधारू गाय पालन — 2 गायें';

  @override
  String get livelihoodEntryInvestmentLabel => 'शुरुआती निवेश';

  @override
  String get livelihoodEntryDescribeRequired => 'गतिविधि का विवरण दें';

  @override
  String get livelihoodEntryInvalidInvestment => 'मान्य निवेश राशि दर्ज करें';

  @override
  String get livelihoodEntryNoShg =>
      'आप किसी SHG से जुड़े नहीं हैं, इसलिए इस गतिविधि को दर्ज करने के लिए कुछ नहीं है।';

  @override
  String get livelihoodEntryAdded => 'गतिविधि जोड़ी गई';

  @override
  String get livelihoodEntryDemoMode =>
      'डेमो मोड — गतिविधि सेव नहीं हुई (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String get livelihoodEntrySaveError =>
      'यह गतिविधि सेव नहीं हो सकी। कृपया फिर से कोशिश करें।';

  @override
  String get livelihoodEntrySaving => 'सेव हो रहा है…';

  @override
  String get livelihoodHomeTitle => 'आजीविका';

  @override
  String get livelihoodHomeAddActivityTooltip => 'गतिविधि जोड़ें';

  @override
  String get livelihoodHomeTotalInvestment => 'कुल निवेश';

  @override
  String get livelihoodHomeTotalRevenue => 'कुल राजस्व';

  @override
  String get livelihoodHomeEmpty => 'अभी तक कोई आजीविका गतिविधि नहीं';

  @override
  String livelihoodHomeNetAmount(String amount) {
    return 'नेट $amount';
  }

  @override
  String get paymentsHistoryTitle => 'भुगतान इतिहास';

  @override
  String get paymentsHistoryEmpty => 'अभी तक कोई भुगतान नहीं';

  @override
  String paymentsHistoryModePayment(String mode) {
    return '$mode भुगतान';
  }

  @override
  String get paymentsHomeTitle => 'डिजिटल भुगतान';

  @override
  String get paymentsHomeScanPay => 'स्कैन करें और भुगतान करें';

  @override
  String get paymentsHomeHistory => 'इतिहास';

  @override
  String get paymentsHomeRecentPayments => 'हाल के भुगतान';

  @override
  String get paymentsHomeViewAll => 'सभी देखें';

  @override
  String get paymentsHomeEmpty => 'अभी तक कोई भुगतान नहीं';

  @override
  String get adminMonitoringTitle => 'सिस्टम मॉनिटरिंग';

  @override
  String get adminMonitoringTotalUsers => 'कुल उपयोगकर्ता';

  @override
  String get adminMonitoringTotalShgs => 'कुल SHGs';

  @override
  String get adminMonitoringSavingsEntries => 'बचत एंट्रियां';

  @override
  String get adminMonitoringLoansPending => 'ऋण (लंबित)';

  @override
  String get adminMonitoringAiModerationBlocksLabel =>
      'AI सलाहकार अवरोध (7 दिन)';

  @override
  String get adminMonitoringAiModerationMembersFlaggedLabel =>
      'फ़्लैग किए गए सदस्य (7 दिन)';

  @override
  String get adminMonitoringPlaceholderLabel => 'प्लेसहोल्डर मेट्रिक्स';

  @override
  String get adminMonitoringPlaceholderDescription =>
      'ये सिर्फ बुनियादी रो काउंट हैं, असली इन्फ्रास्ट्रक्चर मेट्रिक्स (अपटाइम, लेटेंसी, एरर रेट) नहीं। असली मॉनिटरिंग जोड़ने के लिए एक अलग Edge Function या बाहरी सेवा की ज़रूरत होगी।';

  @override
  String adminMonitoringCheckedAt(String date) {
    return '$date को जांचा गया';
  }

  @override
  String get aiHubTitle => 'AI सलाहकार';

  @override
  String get aiHubAskAdvisor => 'किसी सलाहकार से पूछें';

  @override
  String get aiHubFinancialAdvisorTitle => 'वित्तीय सलाहकार';

  @override
  String get aiHubFinancialAdvisorSubtitle => 'बचत, ऋण और बजट पर मार्गदर्शन';

  @override
  String get aiHubSchemeRecommenderTitle => 'योजना सलाहकार';

  @override
  String get aiHubSchemeRecommenderSubtitle =>
      'वे सरकारी योजनाएं खोजें जिनके लिए आप योग्य हैं';

  @override
  String get aiHubMarketAdvisorTitle => 'बाज़ार सलाहकार';

  @override
  String get aiHubMarketAdvisorSubtitle =>
      'आपके उत्पादों के लिए मूल्य और बिक्री के सुझाव';

  @override
  String get aiHubVoiceAssistantTitle => 'वॉइस असिस्टेंट';

  @override
  String get aiHubVoiceAssistantSubtitle =>
      'तेलुगु, हिंदी या अंग्रेज़ी में पूछें — हाथों का उपयोग किए बिना';

  @override
  String get announcementDetailTitle => 'घोषणा';

  @override
  String get announcementDetailNotFound => 'यह घोषणा नहीं मिली';

  @override
  String get splashBrandName => 'NAVASAKHI';

  @override
  String get splashHeadline => 'महिलाओं का सशक्तिकरण।\nसमुदायों में बदलाव।';

  @override
  String get splashSubtitle =>
      'बचत, ऋण, बैठकें, योजनाएं, बाज़ार और भी बहुत कुछ — आपके SHG की हर ज़रूरत, एक ही ऐप में।';

  @override
  String get splashFeatureSavingsLoans => 'बचत और ऋण';

  @override
  String get splashFeatureGroupManagement => 'समूह प्रबंधन';

  @override
  String get splashFeatureGovtSchemes => 'सरकारी योजनाएं';

  @override
  String get splashFeatureLivelihoods => 'आजीविका';

  @override
  String get splashGetStarted => 'शुरू करें';

  @override
  String get splashAvailableLanguages =>
      'इन भाषाओं में उपलब्ध: English · తెలుగు · हिंदी';

  @override
  String get financialLedgerCashbookLabel => 'कैशबुक';

  @override
  String get financialLedgerLedgerLabel => 'लेजर';

  @override
  String get financialLedgerBankLabel => 'बैंक';

  @override
  String get financialLedgerAuditLabel => 'ऑडिट';

  @override
  String get financialLedgerAddEntryTooltip => 'एंट्री जोड़ें';

  @override
  String get financialLedgerEntryAdded => 'एंट्री जोड़ी गई';

  @override
  String get financialLedgerDemoMode =>
      'डेमो मोड — सेव नहीं हुआ (स्थायी रूप से सेव करने के लिए Supabase से जोड़ें)';

  @override
  String financialLedgerEmpty(String title) {
    return 'अभी तक कोई $title एंट्री नहीं';
  }

  @override
  String get servicesSavingsLabel => 'बचत';

  @override
  String get servicesLoansLabel => 'ऋण';

  @override
  String get servicesMeetingsLabel => 'बैठकें';

  @override
  String get servicesFinancialRecordsLabel => 'वित्तीय रिकॉर्ड';

  @override
  String get servicesLivelihoodsLabel => 'आजीविका';

  @override
  String get servicesMarketplaceLabel => 'बाज़ार';

  @override
  String get servicesDigitalPaymentsLabel => 'डिजिटल भुगतान';

  @override
  String get servicesGovtSchemesLabel => 'सरकारी योजनाएं';

  @override
  String get servicesTrainingLabel => 'प्रशिक्षण';

  @override
  String get servicesSupportLabel => 'सहायता';

  @override
  String get servicesAiAdvisorsLabel => 'AI सलाहकार';

  @override
  String get servicesAnnouncementsLabel => 'घोषणाएं';

  @override
  String get servicesReportsLabel => 'रिपोर्ट';

  @override
  String get servicesAnalyticsLabel => 'एनालिटिक्स';

  @override
  String get servicesManageUsersLabel => 'उपयोगकर्ता प्रबंधन';

  @override
  String get servicesManageSchemesLabel => 'योजना प्रबंधन';

  @override
  String get servicesSystemMonitoringLabel => 'सिस्टम मॉनिटरिंग';

  @override
  String get servicesShgManagementSection => 'SHG प्रबंधन';

  @override
  String get servicesCommerceSection => 'कारोबार';

  @override
  String get servicesLearningSupportSection => 'सीखना और सहायता';

  @override
  String get servicesInsightsSection => 'इनसाइट्स';

  @override
  String get servicesAdminToolsSection => 'एडमिन टूल्स';

  @override
  String get schemeEligibilityShgMembershipMet =>
      'SHG सदस्यता — आप SHG से जुड़े हैं';

  @override
  String get schemeEligibilityShgMembershipUnmet =>
      'SHG सदस्यता आवश्यक है — आप किसी SHG से जुड़े नहीं हैं';

  @override
  String schemeEligibilityAgeMet(int actual, int required) {
    return 'SHG $actual+ महीने से पंजीकृत है (आवश्यकता $required+)';
  }

  @override
  String schemeEligibilityAgeUnmetNoShg(int required) {
    return 'SHG को $required+ महीने पंजीकृत होना चाहिए — आप किसी SHG से जुड़े नहीं हैं';
  }

  @override
  String schemeEligibilityAgeUnmetNoRecord(int required) {
    return 'SHG को $required+ महीने पंजीकृत होना चाहिए — आपकी SHG की पंजीकरण तारीख दर्ज नहीं है';
  }

  @override
  String schemeEligibilityAgeUnmet(int required, int actual) {
    return 'SHG को $required+ महीने पंजीकृत होना चाहिए — आपकी SHG केवल $actual महीने से पंजीकृत है';
  }

  @override
  String schemeEligibilityGradeMet(String grade, String required) {
    return 'SHG ग्रेड $grade, $required-या-उससे-ऊपर की आवश्यकता को पूरा करता है';
  }

  @override
  String schemeEligibilityGradeUnmetNoShg(String required) {
    return 'SHG ग्रेड $required या उससे ऊपर आवश्यक है — आप किसी SHG से जुड़े नहीं हैं';
  }

  @override
  String schemeEligibilityGradeUnmetNoRecord(String required) {
    return 'SHG ग्रेड $required या उससे ऊपर आवश्यक है — आपकी SHG का ग्रेड दर्ज नहीं है';
  }

  @override
  String schemeEligibilityGradeUnmet(String required, String grade) {
    return 'SHG ग्रेड $required या उससे ऊपर आवश्यक है — आपकी SHG का ग्रेड $grade है';
  }

  @override
  String adminDashboardActivityNewUser(String name) {
    return 'नया उपयोगकर्ता पंजीकृत — $name';
  }

  @override
  String adminDashboardActivityNewShg(String name) {
    return 'नई SHG पंजीकृत — $name';
  }

  @override
  String adminDashboardActivityDocument(String name) {
    return 'दस्तावेज़ अपलोड किया गया — $name';
  }

  @override
  String get aiAdvisorUpstreamUnavailable =>
      'सलाहकार सेवा अभी अस्थायी रूप से उपलब्ध नहीं है। कृपया थोड़ी देर बाद फिर से प्रयास करें।';
}
