// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NavaSakhi';

  @override
  String get navHome => 'Home';

  @override
  String get navMySHG => 'My SHG';

  @override
  String get navSHGs => 'SHGs';

  @override
  String get navServices => 'Services';

  @override
  String get navMarket => 'Market';

  @override
  String get navProfile => 'Profile';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSignOut => 'Sign Out';

  @override
  String get profileSigningOut => 'Signing out…';

  @override
  String get actionCheckStatus => 'Check Status';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonBack => 'Back';

  @override
  String get commonStaffNoShgMessage =>
      'Your role isn\'t linked to a specific SHG — this view doesn\'t apply';

  @override
  String get commonLeaderNoShgMessage =>
      'Your account isn\'t linked to an SHG yet. Contact an Admin to get set up.';

  @override
  String get asyncErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get asyncErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get asyncErrorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get actionSignInAgain => 'Sign In Again';

  @override
  String get discardChangesTitle => 'Discard changes?';

  @override
  String get discardChangesMessage =>
      'You\'ve entered information on this page that hasn\'t been saved yet. Leaving now will lose it.';

  @override
  String get discardChangesKeepEditing => 'Keep Editing';

  @override
  String get discardChangesDiscard => 'Discard';

  @override
  String get errorGoHome => 'Go to Home';

  @override
  String get error404Title => 'Page not found';

  @override
  String get error404Message =>
      'The page you\'re looking for doesn\'t exist or may have moved.';

  @override
  String get profileLoadErrorTitle => 'Couldn\'t load your profile';

  @override
  String get accountDeactivatedTitle => 'Account deactivated';

  @override
  String get accountDeactivatedMessage =>
      'Your account has been deactivated. Contact your CRP or SHG federation admin if you believe this is a mistake.';

  @override
  String get qrPermissionDenied => 'Camera permission was denied.';

  @override
  String get qrUnsupported => 'Scanning isn\'t supported on this device.';

  @override
  String get qrCameraUnavailable => 'Camera not available.';

  @override
  String get qrManualFallbackHint => 'You can still enter details manually.';

  @override
  String get qrEnterManually => 'Enter manually instead';

  @override
  String get qrManualEntry => 'Manual entry';

  @override
  String get qrTurnOffFlashlight => 'Turn off flashlight';

  @override
  String get qrTurnOnFlashlight => 'Turn on flashlight';

  @override
  String get qrTakingTooLong => 'Camera is taking too long to start.';

  @override
  String get qrScanToPayTitle => 'Scan to Pay';

  @override
  String get qrScanToPayInstructions =>
      'Point your camera at the merchant\'s UPI QR code';

  @override
  String get qrScanAttendanceTitle => 'Scan Attendance QR';

  @override
  String get qrScanAttendanceInstructions =>
      'Point your camera at the QR code displayed at the venue';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEditProfile => 'Edit Profile';

  @override
  String get profileMobile => 'Mobile';

  @override
  String get profileVillage => 'Village';

  @override
  String get profileSHG => 'SHG';

  @override
  String get profileShgNotYetApproved => 'Not yet approved';

  @override
  String get profileShgNotApplicable => 'Not applicable';

  @override
  String get profileName => 'Name';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileUpdateDemoMode =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get profileUpdateError =>
      'Could not update your profile. Please try again.';

  @override
  String get profileNameRequired => 'Name is required.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotifMeetingReminders => 'Meeting reminders';

  @override
  String get settingsNotifPaymentAlerts => 'Payment alerts';

  @override
  String get settingsNotifAnnouncements => 'Announcements';

  @override
  String get settingsNotifLocalOnly =>
      'Reminders are scheduled on this device only — not sent by a server. They won\'t reach you if you use a different phone or reinstall the app, and restarting your phone can clear them too — reopening the Meetings or Loans tab brings them back in line. If a meeting is cancelled, only this device\'s own reminder is cancelled right away — another member\'s phone may still show a stale reminder for it until she reopens the Meetings tab. Same for a loan: if your leader records your final payment on her own phone, your due-date reminder on your phone only clears once you reopen the Loans tab.';

  @override
  String get notificationMeetingReminderTitle => 'Meeting reminder';

  @override
  String get notificationMeetingReminderBodyNoVenue =>
      'Your SHG meeting starts in about an hour.';

  @override
  String notificationMeetingReminderBodyWithVenue(String venue) {
    return 'Your SHG meeting starts in about an hour at $venue.';
  }

  @override
  String get notificationLoanDueTitle => 'Loan payment due tomorrow';

  @override
  String get notificationLoanDueBodyNoAmount => 'Your EMI is due tomorrow.';

  @override
  String notificationLoanDueBodyWithAmount(String amount) {
    return 'Your EMI of ₹$amount is due tomorrow.';
  }

  @override
  String get notificationNewAnnouncementTitle => 'New announcement';

  @override
  String get settingsNotifPermissionDenied =>
      'Notifications are turned off for this app in your phone\'s settings. Turn them on there to actually receive reminders.';

  @override
  String get settingsNotifCancelPendingError =>
      'Couldn\'t turn off these reminders on this device. We\'ll keep retrying automatically — please check your connection, or try again.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsPreviewAs => 'Preview as';

  @override
  String get settingsAppVersion => 'App version';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsPreviewRoleDescription =>
      'This app lets you preview every role\'s dashboard — switch anytime.';

  @override
  String get settingsPreferenceError =>
      'Could not save this preference. Please try again.';

  @override
  String get settingsRoleSwitchError =>
      'Could not switch role. Please try again.';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Choose your preferred language for the app';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTelugu => 'తెలుగు';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get servicesTitle => 'Services';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Enter your registered mobile number to continue';

  @override
  String get loginSending => 'Sending…';

  @override
  String get loginSendOtp => 'Send OTP';

  @override
  String get loginOtpError =>
      'Could not send OTP. Please check the number and try again.';

  @override
  String get loginDataProtected =>
      'Your data is protected under DAY-NRLM guidelines. We never share your Aadhaar details.';

  @override
  String get loginTermsAgreement =>
      'By continuing you agree to the Terms of Service & Privacy Policy';

  @override
  String get otpTitle => 'Verify OTP';

  @override
  String get otpHint => 'Enter the 6-digit code sent to your phone';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpSentTo => 'We\'ve sent a 6-digit code to ';

  @override
  String get otpVerifyContinue => 'Verify & Continue';

  @override
  String get otpVerifying => 'Verifying…';

  @override
  String get otpResendIn => 'Resend OTP in ';

  @override
  String get otpResend => 'Resend OTP';

  @override
  String get otpDidntReceive =>
      'Didn\'t receive the code? Check your SMS inbox.';

  @override
  String get otpVerifyError => 'Incorrect or expired code. Please try again.';

  @override
  String get otpResendError => 'Could not resend the code. Please try again.';

  @override
  String get otpMissingPhoneError =>
      'Your phone number wasn\'t found. Please sign in again.';

  @override
  String otpDigitLabel(int position) {
    return 'OTP digit $position of 6';
  }

  @override
  String get profileSetupTitle => 'Create your profile';

  @override
  String get profileSetupSubtitle =>
      'Tell us a bit about yourself to get started';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldMandal => 'Mandal';

  @override
  String get fieldDistrict => 'District';

  @override
  String get yourShg => 'Your SHG';

  @override
  String get searchSelectShg => 'Search & select your SHG';

  @override
  String get changeShg => 'Change';

  @override
  String get profileSetupSaving => 'Saving…';

  @override
  String get profileSetupContinue => 'Continue';

  @override
  String get findYourShg => 'Find your SHG';

  @override
  String get searchShgHint => 'Search by SHG name';

  @override
  String get noShgsFound => 'No SHGs found';

  @override
  String get shgSearchLoadError => 'Could not load SHGs. Please try again.';

  @override
  String get roleSelectTitle => 'Continue as';

  @override
  String get roleSelectSubtitle =>
      'Choose your role in the SHG ecosystem to see a tailored experience';

  @override
  String get roleSelectSaveError =>
      'Could not save your role. Please try again.';

  @override
  String get dashboardGreeting => 'Welcome back';

  @override
  String get shgApprovalWaitingTitle => 'Waiting for approval';

  @override
  String get shgApprovalWaitingMessage =>
      'Your request to join has been sent to your SHG leader. You will get access once it is approved.';

  @override
  String get shgApprovalRejectedTitle => 'Request not approved';

  @override
  String get shgApprovalRejectedMessage =>
      'Your SHG leader did not approve this request. You can pick a different SHG and try again.';

  @override
  String get shgApprovalNoneTitle => 'No SHG selected yet';

  @override
  String get shgApprovalNoneMessage =>
      'You don\'t currently have a pending request to join an SHG. Choose one to get started.';

  @override
  String get unknownShg => 'Unknown SHG';

  @override
  String get chooseDifferentShg => 'Choose a different SHG';

  @override
  String get chooseAnShg => 'Choose an SHG';

  @override
  String get checkingStatus => 'Checking…';

  @override
  String get shgApprovalCheckError =>
      'Could not check status. Please try again.';

  @override
  String get shgApprovalWithdrawButton => 'Withdraw request';

  @override
  String get shgApprovalWithdrawing => 'Withdrawing…';

  @override
  String get shgApprovalWithdrawConfirmTitle => 'Withdraw request?';

  @override
  String get shgApprovalWithdrawConfirmMessage =>
      'This cancels your pending request. You can choose an SHG again anytime.';

  @override
  String get shgApprovalWithdrawError =>
      'Could not withdraw the request. Please try again.';

  @override
  String get voiceNoLoans => 'You have no loans on record.';

  @override
  String voiceNoActiveLoans(int count) {
    return 'You have no active loans out of $count on record.';
  }

  @override
  String voiceLoanActive(String purpose, String amount, String outstanding) {
    return '$purpose: ₹$amount loan, ₹$outstanding still outstanding.';
  }

  @override
  String voiceSavingsThisMonth(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'entries',
      one: 'entry',
    );
    return 'You have saved ₹$amount this month across $count $_temp0.';
  }

  @override
  String get voiceNoAnnouncements => 'You have no announcements.';

  @override
  String get voiceOpeningSavingsForm =>
      'Opening the savings entry form for you.';

  @override
  String get voiceUnknownCommand => 'Sorry, I didn\'t understand that.';

  @override
  String get voiceAssistantTitle => 'Voice Assistant';

  @override
  String get voiceAssistantTapToSpeak => 'Tap to speak a command';

  @override
  String get voiceAssistantListening => 'Listening…';

  @override
  String get voiceAssistantThinking => 'Finding an answer…';

  @override
  String get voiceAssistantTapToAskAgain => 'Tap to ask again';

  @override
  String get voiceAssistantYouSaid => 'You said';

  @override
  String get voiceAssistantLabel => 'Assistant';

  @override
  String get voiceAssistantTrySaying => 'Try saying';

  @override
  String get voiceAssistantMicUnavailableError =>
      'Speech recognition isn\'t available on this device. Check microphone permission in your phone\'s Settings.';

  @override
  String get voiceAssistantNoSpeechError =>
      'Sorry, I couldn\'t hear anything. Please try again.';

  @override
  String get aiDisclaimer =>
      'AI-generated guidance — may be inaccurate. Not professional financial, legal, or medical advice; confirm important decisions with your SHG leader or a qualified advisor.';

  @override
  String get adminDashboardJustNow => 'Just now';

  @override
  String adminDashboardMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String adminDashboardHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String adminDashboardDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String adminDashboardMonthsAgo(int count) {
    return '${count}mo ago';
  }

  @override
  String get adminDashboardTotalShgsLabel => 'Total SHGs';

  @override
  String adminDashboardActiveMembersTrend(int count) {
    return '$count members';
  }

  @override
  String get adminDashboardSystemUptimeLabel => 'Scheduler Status';

  @override
  String get adminDashboardHeartbeatHealthy => 'Healthy';

  @override
  String get adminDashboardHeartbeatStale => 'Stale';

  @override
  String adminDashboardHeartbeatTrend(String time) {
    return 'Heartbeat: $time';
  }

  @override
  String get adminDashboardHeartbeatPending => 'No heartbeat recorded yet';

  @override
  String get adminDashboardUsersTile => 'Users';

  @override
  String get adminDashboardShgsTile => 'SHGs';

  @override
  String get adminDashboardSchemesTile => 'Schemes';

  @override
  String get adminDashboardMonitoringTile => 'Monitoring';

  @override
  String get adminDashboardReportsTile => 'Reports';

  @override
  String get adminDashboardAuditLogTile => 'Audit Log';

  @override
  String adminDashboardPendingReviewCount(int count) {
    return '$count scheme applications pending review';
  }

  @override
  String get adminDashboardAwaitingReviewSubtitle =>
      'Awaiting staff approval or rejection';

  @override
  String get adminDashboardReviewAction => 'Review';

  @override
  String dashboardPendingJoinRequestsCount(int count) {
    return '$count join requests pending';
  }

  @override
  String get dashboardPendingJoinRequestsSubtitle =>
      'New members waiting to join an SHG';

  @override
  String get dashboardPendingJoinRequestsAction => 'Review';

  @override
  String get adminDashboardPlatformSnapshotTitle => 'Platform Snapshot';

  @override
  String get adminDashboardAnalyticsAction => 'Analytics';

  @override
  String get adminDashboardLoansDisbursedLabel => 'Loans Disbursed';

  @override
  String get adminDashboardTrainingCompletionLabel => 'Training Completion';

  @override
  String get adminDashboardRecentActivityTitle => 'Recent System Activity';

  @override
  String get adminDashboardNoRecentActivity => 'No recent activity yet';

  @override
  String get clfDashboardVillageOrgsLabel => 'Village Orgs';

  @override
  String clfDashboardShgsTotalTrend(int count) {
    return '$count SHGs total';
  }

  @override
  String get clfDashboardTotalSavingsLabel => 'Total Savings';

  @override
  String get clfDashboardFinancialOversightTrend => 'Financial oversight';

  @override
  String get clfDashboardMonitorVillageOrgsTitle =>
      'Monitor Village Organisations';

  @override
  String clfDashboardVillagesShgsSummary(int villageCount, int shgCount) {
    return '$villageCount villages · $shgCount SHGs';
  }

  @override
  String get clfDashboardVillageWiseShgsTitle => 'Village-wise SHGs';

  @override
  String get clfDashboardFederationReportsAction => 'Federation reports';

  @override
  String get clfDashboardNoVillagesYet => 'No villages yet';

  @override
  String clfDashboardShgChartSemanticLabel(String summary) {
    return 'Village-wise SHGs bar chart: $summary';
  }

  @override
  String clfDashboardShgChartItemLabel(String village, int count) {
    return '$village $count SHGs';
  }

  @override
  String get clfDashboardFinancialOversightTitle => 'Financial Oversight';

  @override
  String get clfDashboardLoansDisbursedLabel => 'Loans Disbursed';

  @override
  String get clfDashboardRecoveryRateLabel => 'Recovery Rate';

  @override
  String get clfDashboardFullAnalyticsTitle => 'Full Analytics Dashboard';

  @override
  String get clfDashboardFullAnalyticsSubtitle =>
      'KPIs, trends & recovery insights';

  @override
  String get clfDashboardOpenAction => 'Open';

  @override
  String get crpDashboardShgsMonitoredLabel => 'SHGs Monitored';

  @override
  String get crpDashboardNoShgsYetTrend => 'No SHGs yet';

  @override
  String get crpDashboardAvgHealthScoreLabel => 'Avg. Health Score';

  @override
  String get crpDashboardAttendanceProxyTrend => 'Attendance-based proxy';

  @override
  String crpDashboardAvgHealthPartialTrend(int count) {
    return 'Attendance-based proxy · first $count SHGs';
  }

  @override
  String get crpDashboardTrainingCompletionLabel => 'Training Completion';

  @override
  String get crpDashboardTrainingCompletionTrend => 'Platform-wide average';

  @override
  String get crpDashboardShgsUnderMonitoringTitle => 'SHGs Under Monitoring';

  @override
  String get crpDashboardViewAllAction => 'View all';

  @override
  String get crpDashboardNoShgsToMonitorYet => 'No SHGs to monitor yet';

  @override
  String crpDashboardShgVillageMembersSummary(String village, int count) {
    return '$village · $count members';
  }

  @override
  String get crpDashboardTrainingCatalogTitle => 'Training Catalog';

  @override
  String get crpDashboardNoCoursesYet => 'No courses yet';

  @override
  String dashboardTopBarGreeting(String name) {
    return 'Namaste, $name 🙏';
  }

  @override
  String dashboardTopBarUnreadAnnouncementsTooltip(int count) {
    return '$count unread announcements';
  }

  @override
  String get dashboardTopBarAnnouncementsTooltip => 'Announcements';

  @override
  String get leaderDashboardGroupSavingsLabel => 'Group Savings';

  @override
  String leaderDashboardMembersTrend(int count) {
    return '$count members';
  }

  @override
  String get leaderDashboardLoansOutstandingLabel => 'Loans Outstanding';

  @override
  String leaderDashboardOverdueTrend(int count) {
    return '$count overdue';
  }

  @override
  String get leaderDashboardMembersTile => 'Members';

  @override
  String get leaderDashboardApprovalsTile => 'Approvals';

  @override
  String leaderDashboardApprovalsPendingBadge(int count) {
    return 'Approvals, $count pending';
  }

  @override
  String get leaderDashboardScheduleTile => 'Schedule';

  @override
  String get leaderDashboardReportsTile => 'Reports';

  @override
  String leaderDashboardDefaulterAlert(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Defaulter Alerts',
      one: 'Defaulter Alert',
    );
    return '$count $_temp0';
  }

  @override
  String leaderDashboardEmiOverdueSinceDate(String name, String date) {
    return '$name — EMI overdue since $date';
  }

  @override
  String leaderDashboardEmiOverdue(String name) {
    return '$name — EMI overdue';
  }

  @override
  String get leaderDashboardViewAction => 'View';

  @override
  String get leaderDashboardPendingApprovalsTitle => 'Pending Loan Approvals';

  @override
  String get leaderDashboardReviewAllAction => 'Review all';

  @override
  String get leaderDashboardNoPendingLoans => 'No pending loan requests';

  @override
  String get leaderDashboardJoinRequestsTitle => 'Pending Join Requests';

  @override
  String get leaderDashboardNoPendingJoinRequests => 'No pending join requests';

  @override
  String get leaderDashboardNextMeetingTitle => 'Next Meeting';

  @override
  String get leaderDashboardManageAction => 'Manage';

  @override
  String get leaderDashboardMeetingFallback => 'Meeting';

  @override
  String get leaderDashboardShgHealthTitle => 'SHG Health';

  @override
  String get leaderDashboardGradingLabel => 'Grading';

  @override
  String get leaderDashboardAttendanceLabel => 'Attendance';

  @override
  String get leaderDashboardRecoveryLabel => 'On-time Loans';

  @override
  String get memberDashboardMySavingsLabel => 'My Savings';

  @override
  String memberDashboardSavingsEntriesTrend(int count) {
    return '$count entries';
  }

  @override
  String get memberDashboardOutstandingLoanLabel => 'Outstanding Loan';

  @override
  String memberDashboardNextEmiTrend(String date) {
    return 'Next EMI $date';
  }

  @override
  String get memberDashboardNoDuesTrend => 'No dues';

  @override
  String get memberDashboardAddSavingsTile => 'Add Savings';

  @override
  String get memberDashboardApplyLoanTile => 'Apply Loan';

  @override
  String get memberDashboardAttendanceLabel => 'Attendance';

  @override
  String get memberDashboardSchemesTile => 'Schemes';

  @override
  String memberDashboardSchemesNewBadge(int count) {
    return 'Schemes, $count new';
  }

  @override
  String memberDashboardNewSchemesCount(int count) {
    return '$count new';
  }

  @override
  String get memberDashboardSchemesAvailableLabel => 'Schemes available';

  @override
  String get memberDashboardSavingsSummaryTitle => 'Savings Summary';

  @override
  String get memberDashboardViewAllAction => 'View all';

  @override
  String get memberDashboardLoanSummaryTitle => 'Loan Summary';

  @override
  String get memberDashboardTrackAction => 'Track';

  @override
  String memberDashboardOfAmount(String amount) {
    return 'of ₹$amount';
  }

  @override
  String memberDashboardEmiDueBadge(String amount, String date) {
    return 'EMI ₹$amount due $date';
  }

  @override
  String memberDashboardEmiBadge(String amount) {
    return 'EMI ₹$amount';
  }

  @override
  String get memberDashboardPayNowAction => 'Pay now';

  @override
  String get memberDashboardMeetingAlertLabel => 'MEETING ALERT';

  @override
  String get memberDashboardMeetingFallback => 'Meeting';

  @override
  String get memberDashboardDetailsAction => 'Details';

  @override
  String get memberDashboardTrainingAlertLabel => 'TRAINING ALERT';

  @override
  String get memberDashboardContinueAction => 'Continue';

  @override
  String get memberDashboardAiAdvisorTitle => 'AI Financial Advisor';

  @override
  String get memberDashboardAiAdvisorSubtitle =>
      'Ask about savings, loans & budgeting';

  @override
  String get memberDashboardViewAction => 'View';

  @override
  String get memberDashboardRecentAnnouncementsTitle => 'Recent Announcements';

  @override
  String get memberDashboardSeeAllAction => 'See all';

  @override
  String get memberDashboardNoAnnouncementsYet => 'No announcements yet';

  @override
  String get memberDashboardUnreadLabel => 'Unread';

  @override
  String memberDashboardSavingsTrendChartSemanticLabel(String summary) {
    return 'Savings trend chart: $summary';
  }

  @override
  String get attendanceReportTitle => 'Attendance Report';

  @override
  String get attendanceReportEmpty => 'No completed meetings yet';

  @override
  String get attendanceReportOverallLabel => 'Overall Attendance';

  @override
  String attendanceReportSummary(int present, int total) {
    return '$present of $total meetings attended';
  }

  @override
  String get federationGrowthTitle => 'Savings Growth';

  @override
  String get federationGrowthEmpty => 'No savings recorded yet';

  @override
  String get federationGrowthSubtitle =>
      'Monthly total savings across every SHG';

  @override
  String get federationRecoveryTitle => 'Loan Recovery';

  @override
  String get federationRecoveryLoansDisbursed => 'Loans Disbursed';

  @override
  String get federationRecoveryRateLabel => 'Recovery Rate';

  @override
  String get federationRecoveryRecoveredLabel => 'Recovered';

  @override
  String get federationRecoveryFootnote =>
      'Across active, overdue & closed loans in every SHG';

  @override
  String get federationReportsTitle => 'Federation Reports';

  @override
  String get federationReportsVillagesTitle => 'Village-wise SHGs';

  @override
  String get federationReportsVillagesSubtitle =>
      'SHG count & savings per village';

  @override
  String get federationReportsRecoveryTitle => 'Loan Recovery';

  @override
  String get federationReportsRecoverySubtitle =>
      'Disbursed vs. repaid across every SHG';

  @override
  String get federationReportsGrowthTitle => 'Savings Growth';

  @override
  String get federationReportsGrowthSubtitle =>
      'Monthly savings trend, federation-wide';

  @override
  String get federationVillagesTitle => 'Village-wise SHGs';

  @override
  String get federationVillagesEmpty => 'No SHGs registered yet';

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
  String get loanStatementTitle => 'Loan Statement';

  @override
  String get loanStatementEmpty => 'No loans to statement yet';

  @override
  String get loanStatementTotalOutstandingLabel => 'Total Outstanding';

  @override
  String loanStatementLoanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loans',
      one: 'loan',
    );
    return '$count $_temp0';
  }

  @override
  String loanStatementRepaidAmount(String amount) {
    return 'Repaid ₹$amount';
  }

  @override
  String loanStatementAmountLabel(String amount) {
    return 'Amount ₹$amount';
  }

  @override
  String loanStatementOutstandingAmount(String amount) {
    return 'Outstanding ₹$amount';
  }

  @override
  String loanStatementDisbursedOn(String date) {
    return 'Disbursed $date';
  }

  @override
  String get memberReportTitle => 'My Reports';

  @override
  String get reportPeriodAllTime => 'All time';

  @override
  String get memberReportTotalSavingsLabel => 'Total Savings';

  @override
  String memberReportEntriesTrend(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'entries',
      one: 'entry',
    );
    return '$count $_temp0';
  }

  @override
  String get memberReportLoanOutstandingLabel => 'Loan Outstanding';

  @override
  String memberReportActiveLoansTrend(int count) {
    return '$count active';
  }

  @override
  String get memberReportSectionTitle => 'Reports';

  @override
  String get memberReportSavingsStatementTitle => 'Savings Statement';

  @override
  String get memberReportSavingsStatementSubtitle =>
      'Running balance across every savings entry';

  @override
  String get memberReportLoanStatementTitle => 'Loan Statement';

  @override
  String get memberReportLoanStatementSubtitle =>
      'Every loan, EMI schedule & outstanding balance';

  @override
  String get memberReportAttendanceTitle => 'Attendance Report';

  @override
  String memberReportAttendanceSubtitle(String pct, int present, int total) {
    return '$pct% · $present of $total meetings';
  }

  @override
  String get reportsHubTitle => 'Reports';

  @override
  String get reportsHubMyReportsTitle => 'My Reports';

  @override
  String get reportsHubMyReportsSubtitle =>
      'Your savings, loans & attendance summary';

  @override
  String get reportsHubShgReportsTitle => 'SHG Reports';

  @override
  String get reportsHubShgReportsSubtitle =>
      'Group-wide savings, loans & attendance';

  @override
  String get reportsHubFederationReportsTitle => 'Federation Reports';

  @override
  String get reportsHubFederationReportsSubtitle =>
      'Aggregated across every SHG';

  @override
  String get shgFinancialSummaryTitle => 'Financial Summary';

  @override
  String get shgFinancialSummaryMembersLabel => 'Members';

  @override
  String get shgFinancialSummaryActiveLoansLabel => 'Active Loans';

  @override
  String get shgFinancialSummaryTotalSavingsLabel => 'Total Savings';

  @override
  String get shgFinancialSummaryLoanOutstandingLabel => 'Loan Outstanding';

  @override
  String get shgFinancialSummaryAvgAttendanceLabel =>
      'Average Attendance (last 6 months)';

  @override
  String get shgPerformanceReportTitle => 'Performance Report';

  @override
  String get shgPerformanceAvgAttendanceLabel =>
      'Avg. Attendance (last 6 months)';

  @override
  String get shgPerformanceActiveLoansLabel => 'Active Loans';

  @override
  String get shgPerformanceAttendanceTrendLabel => 'Attendance Trend';

  @override
  String get shgPerformanceEmptyTrend => 'No completed meetings yet';

  @override
  String get shgReportsTitle => 'SHG Reports';

  @override
  String get shgReportsFinancialSummaryTitle => 'Financial Summary';

  @override
  String get shgReportsFinancialSummarySubtitle =>
      'Savings, loans & attendance at a glance';

  @override
  String get shgReportsAuditReportTitle => 'Audit Report';

  @override
  String get shgReportsAuditReportSubtitle => 'Internal & external audit trail';

  @override
  String get shgReportsPerformanceReportTitle => 'Performance Report';

  @override
  String get shgReportsPerformanceReportSubtitle =>
      'Attendance trend & loan activity';

  @override
  String get addProductTitle => 'Add Product';

  @override
  String get addProductImageTooLarge =>
      'Image is too large — please choose one under 5 MB';

  @override
  String get addProductAddPhotoOptional => 'Add a photo (optional)';

  @override
  String get addProductRemovePhotoTooltip => 'Remove photo';

  @override
  String get addProductNameLabel => 'Product name';

  @override
  String get addProductNameHint => 'e.g. Handwoven Cotton Saree';

  @override
  String get addProductDescriptionLabel => 'Description';

  @override
  String get addProductDescriptionHint => 'Describe your product';

  @override
  String get addProductPriceLabel => 'Price (₹)';

  @override
  String get addProductStockLabel => 'Stock';

  @override
  String get addProductCategoryLabel => 'Category';

  @override
  String get addProductNameRequired => 'Enter a product name';

  @override
  String get addProductInvalidPrice => 'Enter a valid price';

  @override
  String get addProductPriceTooLarge =>
      'Price seems unusually large — please check and re-enter';

  @override
  String get addProductSubmitError =>
      'Could not list this product. Please try again.';

  @override
  String get addProductListedSuccess => 'Product listed';

  @override
  String get addProductDemoModeNotSaved =>
      'Demo mode — product not saved (connect Supabase to persist)';

  @override
  String get addProductListingInProgress => 'Listing…';

  @override
  String get addProductSubmitButton => 'List Product';

  @override
  String get marketplaceHomeTitle => 'Marketplace';

  @override
  String get marketplaceHomeAddProductTooltip => 'Add product';

  @override
  String get marketplaceHomeSellTile => 'Sell';

  @override
  String get marketplaceHomeOrdersTile => 'Orders';

  @override
  String get marketplaceHomeReviewsTile => 'Reviews';

  @override
  String get marketplaceHomeBrowseProducts => 'Browse Products';

  @override
  String get marketplaceHomeEmptyProducts => 'No products listed yet';

  @override
  String get marketplaceHomeSearchHint => 'Search products';

  @override
  String get marketplaceHomeCategoryAll => 'All';

  @override
  String get marketplaceHomeNoSearchResults => 'No products match your search';

  @override
  String get marketplaceOrdersTitle => 'Orders';

  @override
  String get marketplaceOrdersEmpty => 'No orders yet';

  @override
  String get marketplaceOrdersMyPurchasesTab => 'My Purchases';

  @override
  String get marketplaceOrdersMySalesTab => 'My Sales';

  @override
  String get marketplaceOrdersBuyerEmpty =>
      'You haven\'t bought anything from the marketplace yet';

  @override
  String get marketplaceReviewsTitle => 'Reviews';

  @override
  String get marketplaceReviewsEmpty => 'No reviews on your products yet';

  @override
  String marketplaceReviewsFromCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'reviews',
      one: 'review',
    );
    return 'from $count $_temp0';
  }

  @override
  String marketplaceReviewsRatingSemantics(int rating) {
    return '$rating out of 5 stars';
  }

  @override
  String get orderDetailTitle => 'Order Detail';

  @override
  String get orderDetailNotFound => 'This order could not be found';

  @override
  String get orderDetailUpdateStatusError =>
      'Could not update the order status. Please try again.';

  @override
  String get orderDetailUpdateStatusLabel => 'Update status';

  @override
  String orderDetailBuyerLabel(String name) {
    return 'Buyer: $name';
  }

  @override
  String orderDetailOrderedOn(String date) {
    return 'Ordered $date';
  }

  @override
  String get productDetailTitle => 'Product';

  @override
  String get productDetailNotFound => 'This product could not be found';

  @override
  String get productDetailWriteReviewTitle => 'Write a review';

  @override
  String productDetailStarTooltip(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'stars',
      one: 'star',
    );
    return '$count $_temp0';
  }

  @override
  String get productDetailReviewHint =>
      'Share your experience with this product (optional)';

  @override
  String get productDetailReviewSubmitted => 'Review submitted';

  @override
  String get productDetailReviewDemoMode =>
      'Demo mode — review not saved (connect Supabase to persist)';

  @override
  String get productDetailReviewSubmitError =>
      'Could not submit your review. You may need to purchase this product first.';

  @override
  String get productDetailOrderPlaced => 'Order placed';

  @override
  String get productDetailOrderDemoMode =>
      'Demo mode — order not saved (connect Supabase to persist)';

  @override
  String get productDetailOrderPlaceError =>
      'Could not place this order. Please try again.';

  @override
  String productDetailBySeller(String name) {
    return 'by $name';
  }

  @override
  String productDetailInStock(int count) {
    return '$count in stock';
  }

  @override
  String get productDetailReviewsSection => 'Reviews';

  @override
  String get productDetailSubmittingAction => 'Submitting…';

  @override
  String get productDetailWriteReviewAction => 'Write a Review';

  @override
  String get productDetailNoReviewsYet => 'No reviews yet';

  @override
  String productDetailReviewRatingSemantics(int rating) {
    return '$rating out of 5 stars';
  }

  @override
  String get productDetailPlacingInProgress => 'Placing…';

  @override
  String get productDetailPlaceOrderButton => 'Place Order';

  @override
  String get meetingsHomeTitle => 'Meetings';

  @override
  String get meetingsHomeScheduleTooltip => 'Schedule meeting';

  @override
  String get meetingsHomeCheckIn => 'Check In';

  @override
  String get meetingsHomeScheduleLabel => 'Schedule';

  @override
  String get meetingsHomeAttendanceLabel => 'Attendance';

  @override
  String get meetingsHomeUpcoming => 'Upcoming';

  @override
  String get meetingsHomePastMeetings => 'Past Meetings';

  @override
  String get meetingsHomeNoPastMeetings => 'No past meetings yet';

  @override
  String get meetingsHomeDefaultTitle => 'Meeting';

  @override
  String meetingsHomeShgName(String shg) {
    return 'SHG: $shg';
  }

  @override
  String get meetingDetailTitle => 'Meeting Detail';

  @override
  String get meetingDetailNotFound => 'This meeting could not be found';

  @override
  String get meetingDetailDefaultTitle => 'Meeting';

  @override
  String get meetingDetailMinutesLabel => 'Minutes of Meeting';

  @override
  String get meetingDetailCancelDialogTitle => 'Cancel meeting?';

  @override
  String meetingDetailCancelDialogContent(String date) {
    return 'This marks the $date meeting as cancelled. Members will see it as cancelled instead of upcoming.';
  }

  @override
  String get meetingDetailKeepMeeting => 'Keep Meeting';

  @override
  String get meetingDetailCancelMeeting => 'Cancel Meeting';

  @override
  String get meetingDetailCancelling => 'Cancelling…';

  @override
  String get meetingDetailCancelledSuccess => 'Meeting cancelled';

  @override
  String get meetingDetailCancelledDemoMode =>
      'Demo mode — cancelled for the rest of this session (connect Supabase to persist)';

  @override
  String get meetingDetailCancelError =>
      'Could not cancel this meeting. Please try again.';

  @override
  String get meetingDetailAttendanceSection => 'Attendance';

  @override
  String get meetingDetailMarkAction => 'Mark';

  @override
  String meetingDetailPresentCount(int present, int total) {
    return '$present / $total present';
  }

  @override
  String get meetingAttendanceTitle => 'Attendance';

  @override
  String meetingAttendanceShgName(String shg) {
    return 'SHG: $shg';
  }

  @override
  String get meetingAttendanceNoMeetings =>
      'No meetings to mark attendance for';

  @override
  String get meetingAttendanceNoMembers => 'No members to mark attendance for';

  @override
  String meetingAttendancePresentCount(int present, int total) {
    return '$present / $total present';
  }

  @override
  String get meetingAttendanceUpdateError =>
      'Could not update attendance. Please try again.';

  @override
  String meetingAttendanceFutureMeetingNotice(String date) {
    return 'This meeting hasn\'t happened yet — attendance can be marked on or after $date.';
  }

  @override
  String get meetingMomTitle => 'Minutes of Meeting';

  @override
  String get meetingMomNotFound => 'This meeting could not be found';

  @override
  String get meetingMomDemoModeNotSaved =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get meetingMomSaveDecisionError =>
      'Could not save this decision. Please try again.';

  @override
  String get meetingMomSaveActionItemError =>
      'Could not save this action item. Please try again.';

  @override
  String get meetingMomDecisionsSection => 'Decisions';

  @override
  String get meetingMomNoDecisions => 'No decisions recorded yet';

  @override
  String get meetingMomAddDecisionHint => 'Add a decision…';

  @override
  String get meetingMomAddDecisionTooltip => 'Add decision';

  @override
  String get meetingMomActionItemsSection => 'Action Items';

  @override
  String get meetingMomNoActionItems => 'No action items yet';

  @override
  String get meetingMomUpdateActionItemError =>
      'Could not update this action item. Please try again.';

  @override
  String meetingMomAssignedTo(String name) {
    return 'Assigned to $name';
  }

  @override
  String meetingMomDueDate(String date) {
    return 'Due $date';
  }

  @override
  String get meetingMomAssignToLabel => 'Assign to';

  @override
  String get meetingMomDueByLabel => 'Due by';

  @override
  String get meetingMomUnassigned => 'Unassigned';

  @override
  String get meetingMomAddTaskHint => 'Add a task…';

  @override
  String get meetingMomAddActionItemTooltip => 'Add action item';

  @override
  String get meetingScheduleTitle => 'Schedule Meeting';

  @override
  String get meetingScheduleSubmitting => 'Scheduling…';

  @override
  String get meetingScheduleEnterVenueError => 'Enter a venue';

  @override
  String get meetingScheduleNoShgError =>
      'You\'re not linked to an SHG, so there\'s nothing to schedule this meeting for.';

  @override
  String get meetingScheduleSuccess => 'Meeting scheduled';

  @override
  String get meetingScheduleDemoMode =>
      'Demo mode — meeting not saved (connect Supabase to persist)';

  @override
  String get meetingScheduleDuplicateConfirmTitle =>
      'Meeting already scheduled?';

  @override
  String meetingScheduleDuplicateConfirmMessage(String date) {
    return 'Your SHG already has a meeting scheduled on $date. Schedule another one for the same day?';
  }

  @override
  String get meetingScheduleDuplicateConfirmButton => 'Schedule Anyway';

  @override
  String get meetingScheduleError =>
      'Could not schedule this meeting. Please try again.';

  @override
  String get meetingScheduleDateLabel => 'Date';

  @override
  String get meetingScheduleTimeLabel => 'Time';

  @override
  String get meetingScheduleVenueLabel => 'Venue';

  @override
  String get meetingScheduleVenueHint => 'e.g. Anganwadi Centre, Kondapur';

  @override
  String get meetingScheduleAgendaLabel => 'Agenda';

  @override
  String get meetingScheduleAgendaHint =>
      'e.g. Monthly savings review & loan applications';

  @override
  String get meetingQrTitle => 'Meeting Check-In';

  @override
  String get meetingQrDemoModeMessage =>
      'Demo mode — check-in not saved (connect Supabase to persist)';

  @override
  String get meetingQrCheckInError =>
      'Could not check you in. Please try again.';

  @override
  String get meetingQrNoMeetingMessage =>
      'No meeting scheduled to check in to right now';

  @override
  String get meetingQrCheckedInMessage => 'You\'re checked in!';

  @override
  String get meetingQrCheckInPrompt => 'Check in to this meeting';

  @override
  String get meetingQrDefaultAgenda => 'Meeting';

  @override
  String get meetingQrScanningButton => 'Scanning…';

  @override
  String get meetingQrScanButton => 'Scan QR to Check In';

  @override
  String get meetingQrCheckingInButton => 'Checking in…';

  @override
  String get meetingQrCheckInWithoutScanningButton =>
      'Check In Without Scanning';

  @override
  String get savingsEntryTitle => 'Add Savings';

  @override
  String get savingsEntryMemberLabel => 'Member';

  @override
  String get savingsEntryNoMembersFound =>
      'No members found in your SHG yet — there\'s no one to record this entry against.';

  @override
  String get savingsEntrySelectMember => 'Select a member';

  @override
  String get savingsEntryAmountLabel => 'Amount';

  @override
  String get savingsEntryAmountRequired => 'Enter an amount';

  @override
  String get savingsEntryAmountInvalid => 'Enter a valid number';

  @override
  String get savingsEntryAmountZero => 'Amount must be greater than zero';

  @override
  String get savingsEntryAmountTooLarge =>
      'Amount seems unusually large — please check and re-enter';

  @override
  String get savingsEntryPaymentModeLabel => 'Payment mode';

  @override
  String get savingsEntryFrequencyLabel => 'Frequency';

  @override
  String get savingsEntryNoShgError =>
      'You\'re not linked to an SHG, so there\'s nothing to record this entry against.';

  @override
  String get savingsEntrySubmittedMessage =>
      'Savings entry submitted for verification';

  @override
  String get savingsEntryDemoModeMessage =>
      'Demo mode — entry not saved (connect Supabase to persist)';

  @override
  String get savingsEntrySaveError =>
      'Could not save this entry. Please try again.';

  @override
  String get savingsEntrySaving => 'Saving…';

  @override
  String get savingsEntrySubmit => 'Submit Entry';

  @override
  String get savingsGroupReportTitle => 'Group Savings Report';

  @override
  String get savingsGroupReportEmpty => 'No group savings data yet';

  @override
  String get savingsGroupReportTotalLabel => 'Group Total';

  @override
  String savingsGroupReportSummary(int memberCount, int monthCount) {
    String _temp0 = intl.Intl.pluralLogic(
      memberCount,
      locale: localeName,
      other: 'members',
      one: 'member',
    );
    String _temp1 = intl.Intl.pluralLogic(
      monthCount,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$memberCount contributing $_temp0 · $monthCount $_temp1 of activity';
  }

  @override
  String savingsGroupReportRank(int rank) {
    return 'Rank #$rank';
  }

  @override
  String get savingsHistoryTitle => 'Savings History';

  @override
  String get savingsHistoryEmpty => 'No savings history yet';

  @override
  String get savingsHistoryDeleteTooltip => 'Delete this pending entry';

  @override
  String get savingsHistoryDeleteConfirmTitle => 'Delete this entry?';

  @override
  String get savingsHistoryDeleteConfirmMessage =>
      'This pending entry will be permanently removed. This cannot be undone.';

  @override
  String get savingsHistoryDeletedMessage => 'Entry deleted';

  @override
  String get savingsHistoryDeleteError =>
      'Could not delete this entry. Please try again.';

  @override
  String savingsFrequencyEntryTitle(String frequency) {
    return '$frequency savings';
  }

  @override
  String get savingsHomeTitle => 'Savings';

  @override
  String get savingsHomeAddTooltip => 'Add savings';

  @override
  String get savingsHomeGroupSavingsLabel => 'Group Savings';

  @override
  String get savingsHomeMySavingsLabel => 'My Savings';

  @override
  String get savingsHomePlatformSavingsLabel => 'Platform Savings';

  @override
  String savingsHomeEntriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'entries',
      one: 'entry',
    );
    return '$count $_temp0';
  }

  @override
  String get savingsHomePendingVerificationLabel => 'Pending Verification';

  @override
  String get savingsHomeNeedsReview => 'Needs review';

  @override
  String get savingsHomeAllCaughtUp => 'All caught up';

  @override
  String get savingsHomeAddSavingsTile => 'Add Savings';

  @override
  String get savingsHomeHistoryTile => 'History';

  @override
  String get savingsHomeStatementTile => 'Statement';

  @override
  String get savingsHomeLedgerTile => 'Ledger';

  @override
  String get savingsHomeGroupTile => 'Group';

  @override
  String get savingsHomeRecentEntriesTitle => 'Recent Entries';

  @override
  String get savingsHomeAllShgsEntriesTitle => 'Recent Entries (All SHGs)';

  @override
  String get savingsHomeViewAllAction => 'View all';

  @override
  String get savingsHomeEmpty => 'No savings entries yet';

  @override
  String savingsHomeDateModeShg(String date, String mode, String shg) {
    return '$date · $mode · $shg';
  }

  @override
  String get savingsLedgerTitle => 'Savings Ledger';

  @override
  String get savingsLedgerLiveLabel => 'Live';

  @override
  String get savingsLedgerAddTooltip => 'Add savings';

  @override
  String get savingsLedgerEmpty => 'No savings entries recorded yet';

  @override
  String savingsLedgerShgName(String shg) {
    return 'SHG: $shg';
  }

  @override
  String get savingsLedgerVerifyError =>
      'Could not verify this entry. Please try again.';

  @override
  String get savingsLedgerRejectAction => 'Reject';

  @override
  String get savingsLedgerRejectConfirmTitle => 'Reject this entry?';

  @override
  String get savingsLedgerRejectConfirmMessage =>
      'This pending entry will be permanently removed. This cannot be undone.';

  @override
  String get savingsLedgerRejectConfirmButton => 'Reject';

  @override
  String get savingsLedgerRejectError =>
      'Could not reject this entry. Please try again.';

  @override
  String get savingsLedgerVerifying => 'Verifying…';

  @override
  String savingsLedgerVerifyAction(String amount) {
    return '$amount · Verify';
  }

  @override
  String get savingsLedgerVerifiedBadge => 'verified';

  @override
  String get savingsStatementTitle => 'Savings Statement';

  @override
  String get savingsStatementEmpty => 'No entries to statement yet';

  @override
  String get savingsStatementClosingBalance => 'Closing Balance';

  @override
  String savingsStatementTransactionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'transactions',
      one: 'transaction',
    );
    return '$count $_temp0';
  }

  @override
  String get savingsStatementDateModeHeader => 'DATE / MODE';

  @override
  String get savingsStatementAmountBalanceHeader => 'AMOUNT / BALANCE';

  @override
  String get schemeEligibilityTitle => 'Eligibility Checker';

  @override
  String get schemeEligibilityIntro =>
      'Checked automatically against your SHG\'s membership, registration age and grade. Some requirements — like BPL status or prior subsidy history — still need manual verification; see each scheme\'s full eligibility list for those.';

  @override
  String get schemeEligibilityEmptyCatalog => 'No schemes in the catalog yet';

  @override
  String get schemeEligibilitySeeFullDetails => 'See full details';

  @override
  String get schemeEligibilityEligible => 'Eligible';

  @override
  String get schemeEligibilityNotEligible => 'Not eligible';

  @override
  String get schemeEligibilityNoCriteria =>
      'No automatic eligibility criteria set for this scheme — open it to see the full requirements.';

  @override
  String get schemesHomeTitle => 'Government Schemes';

  @override
  String get schemesHomeEligibilityTile => 'Eligibility';

  @override
  String get schemesHomeTrackingTile => 'Tracking';

  @override
  String get schemesHomeApplicationsTile => 'Applications';

  @override
  String get schemesHomeAllSchemesSection => 'All Schemes';

  @override
  String get schemesHomeEmptyState => 'No schemes available right now';

  @override
  String get schemesHomeNotApplied => 'not applied';

  @override
  String get schemeDetailApplicationSubmitted => 'Application submitted';

  @override
  String get schemeDetailApplyError =>
      'Could not submit this application. Please try again.';

  @override
  String get schemeDetailTitle => 'Scheme Detail';

  @override
  String get schemeDetailNotFound => 'This scheme could not be found';

  @override
  String get schemeDetailBenefitSection => 'Benefit';

  @override
  String get schemeDetailEligibilitySection => 'Eligibility';

  @override
  String get schemeDetailApplicationStatusLabel => 'Application status: ';

  @override
  String get schemeDetailDeadlinePassed =>
      'Applications closed — the deadline for this scheme has passed.';

  @override
  String get schemeDetailIneligibleMessage =>
      'You don\'t meet all the eligibility criteria below yet, so this application would be rejected.';

  @override
  String get schemeDetailViewEligibilityLink => 'View full eligibility check';

  @override
  String get schemeDetailSubmitting => 'Submitting…';

  @override
  String get schemeDetailApplyNow => 'Apply Now';

  @override
  String schemeDetailDeadlineLabel(String date) {
    return 'Deadline: $date';
  }

  @override
  String get schemeTrackingTitle => 'Application Tracking';

  @override
  String get schemeTrackingEmptyState =>
      'You haven\'t applied to any schemes yet';

  @override
  String schemeTrackingDecidedBy(String name) {
    return 'Decided by $name';
  }

  @override
  String get schemeApplicationsReviewApproved => 'Application approved';

  @override
  String get schemeApplicationsReviewRejected => 'Application rejected';

  @override
  String get schemeApplicationsReviewAlreadyDecided =>
      'This application was already decided by someone else.';

  @override
  String get schemeApplicationsReviewSaveError =>
      'Could not save this decision. Please try again.';

  @override
  String get schemeApplicationsReviewTitle => 'Scheme Applications';

  @override
  String get schemeApplicationsReviewEmptyState =>
      'No pending scheme applications';

  @override
  String schemeApplicationsReviewAppliedOn(String date) {
    return 'Applied $date';
  }

  @override
  String get schemeApplicationsReviewReject => 'Reject';

  @override
  String get schemeApplicationsReviewSaving => 'Saving…';

  @override
  String get schemeApplicationsReviewApprove => 'Approve';

  @override
  String get adminSchemesTitle => 'Manage Schemes';

  @override
  String get adminSchemesAddSchemeTooltip => 'Add scheme';

  @override
  String get adminSchemesEmptyState => 'No schemes in the catalog yet';

  @override
  String adminSchemesEditTooltip(String name) {
    return 'Edit $name';
  }

  @override
  String adminSchemesDeleteTooltip(String name) {
    return 'Delete $name';
  }

  @override
  String get adminSchemesCriteriaSectionTitle =>
      'Eligibility criteria (optional)';

  @override
  String get adminSchemesCriteriaSectionSubtext =>
      'Checked automatically against a member\'s SHG. Leave blank for requirements this app can\'t verify automatically (age, income, BPL status, ...) — keep those in the eligibility text instead.';

  @override
  String get adminSchemesRequiresShgMembershipLabel =>
      'Requires SHG membership';

  @override
  String get adminSchemesMinAgeHint => 'Minimum SHG age in months (optional)';

  @override
  String get adminSchemesMinGradeHint => 'Minimum SHG grade (optional)';

  @override
  String get adminSchemesNoMinimum => 'No minimum';

  @override
  String get adminSchemesAddDialogTitle => 'Add scheme';

  @override
  String get adminSchemesNameHint => 'Scheme name';

  @override
  String get adminSchemesAgencyHint => 'Agency';

  @override
  String get adminSchemesBenefitHint => 'Benefit';

  @override
  String get adminSchemesNameRequiredError => 'Scheme name is required.';

  @override
  String get adminSchemesInvalidMinAgeError =>
      'Minimum SHG age must be a whole number of months.';

  @override
  String get adminSchemesAddedMessage => 'Scheme added';

  @override
  String get adminSchemesDemoModeMessage =>
      'Demo mode — scheme not saved (connect Supabase to persist)';

  @override
  String get adminSchemesAddErrorMessage =>
      'Could not add this scheme. Please try again.';

  @override
  String get adminSchemesEditDialogTitle => 'Edit scheme';

  @override
  String get adminSchemesUpdatedMessage => 'Scheme updated';

  @override
  String get adminSchemesUpdateErrorMessage =>
      'Could not update this scheme. Please try again.';

  @override
  String get adminSchemesDeleteDialogTitle => 'Delete scheme?';

  @override
  String adminSchemesDeleteDialogContent(String name) {
    return 'This removes \"$name\" from the catalog.';
  }

  @override
  String get adminSchemesDeletedMessage => 'Scheme deleted';

  @override
  String get adminSchemesDeleteDemoModeMessage =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get adminSchemesDeleteErrorMessage =>
      'Could not delete this scheme. Please try again.';

  @override
  String get adminSchemesDeleteHasApplicationsError =>
      'This scheme can\'t be deleted — it has applications on file.';

  @override
  String get adminTrainingCoursesTitle => 'Manage Training Courses';

  @override
  String get adminTrainingCoursesAddCourseTooltip => 'Add course';

  @override
  String get adminTrainingCoursesEmptyState => 'No courses in the catalog yet';

  @override
  String adminTrainingCoursesEditTooltip(String title) {
    return 'Edit $title';
  }

  @override
  String adminTrainingCoursesDeleteTooltip(String title) {
    return 'Delete $title';
  }

  @override
  String adminTrainingCoursesManageQuizTooltip(String title) {
    return 'Manage quiz for $title';
  }

  @override
  String get adminTrainingCoursesAddDialogTitle => 'Add course';

  @override
  String get adminTrainingCoursesTitleHint => 'Course title';

  @override
  String get adminTrainingCoursesTopicHint => 'Topic';

  @override
  String get adminTrainingCoursesFormatLabel => 'Format';

  @override
  String get adminTrainingCoursesDurationHint => 'Duration (optional)';

  @override
  String get adminTrainingCoursesChooseVideo => 'Attach video';

  @override
  String get adminTrainingCoursesVideoAttached => 'Video attached';

  @override
  String get adminTrainingCoursesRemoveVideo => 'Remove video';

  @override
  String get adminTrainingCoursesVideoTooLarge =>
      'This video is too large. Please choose a file under 200 MB.';

  @override
  String get adminTrainingCoursesVideoDemoModeNotice =>
      'Demo mode has no real storage — this video won\'t actually be attached.';

  @override
  String get adminTrainingCoursesTitleRequiredError =>
      'Course title is required.';

  @override
  String get adminTrainingCoursesAddedMessage => 'Course added';

  @override
  String get adminTrainingCoursesDemoModeMessage =>
      'Demo mode — course not saved (connect Supabase to persist)';

  @override
  String get adminTrainingCoursesAddErrorMessage =>
      'Could not add this course. Please try again.';

  @override
  String get adminTrainingCoursesEditDialogTitle => 'Edit course';

  @override
  String get adminTrainingCoursesUpdatedMessage => 'Course updated';

  @override
  String get adminTrainingCoursesUpdateErrorMessage =>
      'Could not update this course. Please try again.';

  @override
  String get adminTrainingCoursesDeleteDialogTitle => 'Delete course?';

  @override
  String adminTrainingCoursesDeleteDialogContent(String title) {
    return 'This removes \"$title\" and its quiz from the catalog.';
  }

  @override
  String get adminTrainingCoursesDeletedMessage => 'Course deleted';

  @override
  String get adminTrainingCoursesDeleteDemoModeMessage =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get adminTrainingCoursesDeleteErrorMessage =>
      'Could not delete this course. Please try again.';

  @override
  String get adminTrainingCoursesDeleteHasProgressError =>
      'This course can\'t be deleted — at least one member has already made progress or earned a certification from it.';

  @override
  String get adminDashboardTrainingTile => 'Training';

  @override
  String get servicesManageTrainingLabel => 'Manage Training';

  @override
  String adminTrainingQuizTitle(String courseTitle) {
    return 'Quiz — $courseTitle';
  }

  @override
  String get adminTrainingQuizAddQuestionTooltip => 'Add question';

  @override
  String get adminTrainingQuizEmptyState =>
      'No quiz questions yet — members can\'t take this course\'s quiz until you add some';

  @override
  String get adminTrainingQuizAddDialogTitle => 'Add question';

  @override
  String get adminTrainingQuizEditDialogTitle => 'Edit question';

  @override
  String get adminTrainingQuizQuestionHint => 'Question';

  @override
  String adminTrainingQuizOptionHint(int number) {
    return 'Option $number';
  }

  @override
  String adminTrainingQuizOptionCount(int count) {
    return '$count options';
  }

  @override
  String get adminTrainingQuizAddOptionTooltip => 'Add another option';

  @override
  String get adminTrainingQuizRemoveOptionTooltip => 'Remove this option';

  @override
  String get adminTrainingQuizCorrectAnswerLabel => 'Correct answer';

  @override
  String get adminTrainingQuizCorrectAnswerNotReadableNotice =>
      'This question\'s saved correct answer can\'t be shown here yet — pick it again before saving.';

  @override
  String get adminTrainingQuizQuestionRequiredError =>
      'Question text is required.';

  @override
  String get adminTrainingQuizMinOptionsError =>
      'At least 2 options are required.';

  @override
  String get adminTrainingQuizBlankOptionError => 'Options can\'t be blank.';

  @override
  String get adminTrainingQuizCorrectAnswerRequiredError =>
      'Select the correct answer.';

  @override
  String get adminTrainingQuizAddedMessage => 'Question added';

  @override
  String get adminTrainingQuizUpdatedMessage => 'Question updated';

  @override
  String get adminTrainingQuizDemoModeMessage =>
      'Demo mode — question not saved (connect Supabase to persist)';

  @override
  String get adminTrainingQuizAddErrorMessage =>
      'Could not add this question. Please try again.';

  @override
  String get adminTrainingQuizUpdateErrorMessage =>
      'Could not update this question. Please try again.';

  @override
  String get adminTrainingQuizDeleteDialogTitle => 'Delete question?';

  @override
  String get adminTrainingQuizDeleteDialogContent =>
      'This removes this question from the course\'s quiz.';

  @override
  String get adminTrainingQuizDeletedMessage => 'Question deleted';

  @override
  String get adminTrainingQuizDeleteDemoModeMessage =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get adminTrainingQuizDeleteErrorMessage =>
      'Could not delete this question. Please try again.';

  @override
  String get adminTrainingQuizEditTooltip => 'Edit question';

  @override
  String get adminTrainingQuizDeleteTooltip => 'Delete question';

  @override
  String get supportStatusOpen => 'Open';

  @override
  String get supportStatusInProgress => 'In Progress';

  @override
  String get supportStatusResolved => 'Resolved';

  @override
  String get supportStatusClosed => 'Closed';

  @override
  String get supportChatTitle => 'Chat Support';

  @override
  String get supportChatEmptyMessage =>
      'No conversations yet — raise a ticket to get started';

  @override
  String get supportFaqTitle => 'FAQs';

  @override
  String get supportFaq1Question => 'How do I add a savings entry?';

  @override
  String get supportFaq1Answer =>
      'Go to Savings > Add Entry, enter the amount and date, then submit.';

  @override
  String get supportFaq2Question => 'How do I apply for a loan?';

  @override
  String get supportFaq2Answer =>
      'Go to Loans > Apply, fill in the amount and purpose, then submit for leader approval.';

  @override
  String get supportFaq3Question => 'How do I check my SHG grade?';

  @override
  String get supportFaq3Answer =>
      'Your SHG grade is shown on the My SHG screen along with member details.';

  @override
  String get supportFaq4Question => 'Who can post announcements?';

  @override
  String get supportFaq4Answer =>
      'Only your SHG leader or program staff (CRP/CLF/Admin) can post announcements.';

  @override
  String get supportFaq5Question => 'How do I raise a support ticket?';

  @override
  String get supportFaq5Answer =>
      'Go to Support > Raise a Ticket, describe your issue, and submit. You can track replies in My Tickets.';

  @override
  String get supportHomeTitle => 'Support';

  @override
  String get supportHomeMyTickets => 'My Tickets';

  @override
  String get supportHomeRaiseTicket => 'Raise Ticket';

  @override
  String get supportHomeVoiceHelp => 'Voice Help';

  @override
  String get supportHomeFaqs => 'FAQs';

  @override
  String get supportHomeAllTickets => 'All Tickets';

  @override
  String get supportHomeViewAll => 'View all';

  @override
  String get supportHomeEmptyMessage => 'No support tickets yet';

  @override
  String get supportTicketDetailSendError =>
      'Could not send this message. Please try again.';

  @override
  String get supportTicketDetailStatusError =>
      'Could not update the ticket status. Please try again.';

  @override
  String get supportTicketDetailTitle => 'Ticket';

  @override
  String get supportTicketDetailNotFound => 'This ticket could not be found';

  @override
  String get supportTicketDetailNoMessages => 'No messages yet';

  @override
  String get supportTicketDetailYou => 'You';

  @override
  String get supportTicketDetailStaff => 'Staff';

  @override
  String get supportTicketDetailComposerHint => 'Type a message…';

  @override
  String get supportTicketDetailDemoModeHint => 'Demo mode — replies disabled';

  @override
  String get supportTicketDetailSendTooltip => 'Send message';

  @override
  String supportTicketDetailResolvedBy(String name, String date) {
    return 'Resolved by $name on $date';
  }

  @override
  String get supportTicketDetailReopenAction => 'Reopen ticket';

  @override
  String get supportTicketDetailPriorityLabel => 'Priority';

  @override
  String get supportCategoryGeneral => 'General';

  @override
  String get supportCategorySavings => 'Savings';

  @override
  String get supportCategoryLoans => 'Loans';

  @override
  String get supportCategoryMeetings => 'Meetings';

  @override
  String get supportCategoryLivelihood => 'Livelihood';

  @override
  String get supportCategoryMarketplace => 'Marketplace';

  @override
  String get supportCategoryPayments => 'Payments';

  @override
  String get supportCategoryAccount => 'Account';

  @override
  String get supportCategoryOther => 'Other';

  @override
  String get supportPriorityLow => 'Low';

  @override
  String get supportPriorityNormal => 'Normal';

  @override
  String get supportPriorityHigh => 'High';

  @override
  String get supportPriorityUrgent => 'Urgent';

  @override
  String get supportTicketFormCategoryLabel => 'Category';

  @override
  String get supportChatSearchHint => 'Search tickets or member names';

  @override
  String get supportChatFilterAll => 'All';

  @override
  String get supportChatSearchIncompleteNotice =>
      'Showing the latest 500 tickets only — search and filters may miss older ones';

  @override
  String get supportTicketFormTitle => 'Raise a Ticket';

  @override
  String get supportTicketFormSubjectLabel => 'Subject';

  @override
  String get supportTicketFormSubjectHint => 'e.g. Loan disbursement delay';

  @override
  String get supportTicketFormDescriptionLabel => 'Describe your issue';

  @override
  String get supportTicketFormDescriptionHint =>
      'Give as much detail as you can';

  @override
  String get supportTicketFormSubjectRequired =>
      'Enter a subject for your issue';

  @override
  String get supportTicketFormSubmitting => 'Submitting…';

  @override
  String get supportTicketFormSubmit => 'Submit Ticket';

  @override
  String get supportTicketFormRaisedSuccess => 'Ticket raised';

  @override
  String get supportTicketFormDemoModeMessage =>
      'Demo mode — ticket not saved (connect Supabase to persist)';

  @override
  String get supportTicketFormRaiseError =>
      'Could not raise this ticket. Please try again.';

  @override
  String get supportVoiceTitle => 'Voice Support';

  @override
  String get supportVoiceTapToAsk => 'Tap to ask a question';

  @override
  String get supportVoiceListening => 'Listening…';

  @override
  String get supportVoiceThinking => 'Finding an answer…';

  @override
  String get supportVoiceTapToAskAgain => 'Tap to ask again';

  @override
  String get supportVoiceError =>
      'Sorry, something went wrong. Please try again.';

  @override
  String get supportVoiceMicUnavailableError =>
      'Speech recognition isn\'t available on this device. Check microphone permission in your phone\'s Settings.';

  @override
  String get supportVoiceNoSpeechError =>
      'Sorry, I couldn\'t hear anything. Please try again.';

  @override
  String get supportVoiceNoMatchFallback =>
      'I don\'t have an answer for that yet. Try asking about savings, loans, your SHG grade, announcements, or support tickets — or raise a support ticket for a person to help.';

  @override
  String get supportVoiceEnglishOnlyHint =>
      'Voice Support currently understands English only.';

  @override
  String get supportVoiceYouAsked => 'You asked';

  @override
  String get supportVoiceAnswerLabel => 'Answer';

  @override
  String get memberDetailTitle => 'Member Detail';

  @override
  String get memberDetailNotFound => 'This member could not be found';

  @override
  String get memberDetailTotalSavings => 'Total Savings';

  @override
  String get memberDetailLoanOutstanding => 'Loan Outstanding';

  @override
  String get memberDetailContactSection => 'Contact';

  @override
  String get memberDetailMobileLabel => 'Mobile';

  @override
  String get memberDetailVillageLabel => 'Village';

  @override
  String get shgHomeTitle => 'My SHG';

  @override
  String get shgHomeNotLinked => 'You\'re not linked to an SHG yet';

  @override
  String shgHomeRegNumberLabel(String regNumber) {
    return 'Reg. $regNumber';
  }

  @override
  String get shgHomeMembersTile => 'Members';

  @override
  String get shgHomeDocumentsTile => 'Documents';

  @override
  String get shgHomeFederationSection => 'Federation';

  @override
  String get shgHomeVillageOrgLabel => 'Village Organi­sation';

  @override
  String get shgHomeClfLabel => 'CLF';

  @override
  String get shgHomeMandalLabel => 'Mandal';

  @override
  String get shgHomeFormedLabel => 'Formed';

  @override
  String get shgHomeBankDetailsSection => 'Bank Details';

  @override
  String get shgHomeBankLabel => 'Bank';

  @override
  String get shgHomeAccountLabel => 'Account';

  @override
  String get shgHomeIfscLabel => 'IFSC';

  @override
  String get shgHomeEditTooltip => 'Edit federation & bank details';

  @override
  String get shgHomeEditDialogTitle => 'Edit SHG details';

  @override
  String get shgHomeMandalHint => 'Mandal';

  @override
  String get shgHomeBankNameHint => 'Bank name';

  @override
  String get shgHomeBankAccountHint => 'Bank account number';

  @override
  String get shgHomeIfscHint => 'IFSC code';

  @override
  String get shgHomeDetailsUpdatedMessage => 'SHG details updated';

  @override
  String get shgHomeDetailsUpdatedDemoMessage =>
      'Demo mode — details not saved (connect Supabase to persist)';

  @override
  String get shgHomeDetailsUpdateError =>
      'Could not save changes. Please try again.';

  @override
  String get shgDocumentsTitle => 'Documents';

  @override
  String get shgDocumentsAddTooltip => 'Add document';

  @override
  String get shgDocumentsEmpty => 'No documents uploaded yet';

  @override
  String get shgDocumentsLoadMoreError =>
      'Could not load more documents. Please try again.';

  @override
  String get shgDocumentsAddDialogTitle => 'Add document';

  @override
  String get shgDocumentsNameHint => 'Document name';

  @override
  String get shgDocumentsChooseFile => 'Choose file (PDF, JPG, PNG, WEBP)';

  @override
  String get shgDocumentsFileTooLarge =>
      'File is too large — please choose one under 10 MB';

  @override
  String get shgDocumentsNameRequired => 'Document name is required.';

  @override
  String get shgDocumentsFileRequired => 'Please choose a file to upload.';

  @override
  String get shgDocumentsNotLinked =>
      'You\'re not linked to an SHG, so there\'s nothing to attach this document to.';

  @override
  String get shgDocumentsAdded => 'Document added';

  @override
  String get shgDocumentsAddError =>
      'Could not add this document. Please try again.';

  @override
  String get shgDocumentsNoFileAttached =>
      'No file is attached to this record.';

  @override
  String get shgDocumentsOpenError => 'Could not open this document.';

  @override
  String get shgJoinRequestsApproved => 'Request approved';

  @override
  String get shgJoinRequestsRejected => 'Request rejected';

  @override
  String get shgJoinRequestsDemoMode =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get shgJoinRequestsProcessError =>
      'Could not process this request. Please try again.';

  @override
  String get shgJoinRequestsProcessErrorStaleRequester =>
      'Could not process this request — the member\'s account has changed since she applied (e.g. her role or SHG was updated by an admin). Ask her to submit a new request.';

  @override
  String get shgJoinRequestsTitle => 'Join Requests';

  @override
  String get shgJoinRequestsAllTitle => 'All Pending Join Requests';

  @override
  String get shgJoinRequestsEmpty => 'No pending join requests';

  @override
  String get shgJoinRequestsMemberFallback => 'Member';

  @override
  String shgJoinRequestsRequestedOn(String date) {
    return 'Requested $date';
  }

  @override
  String get shgJoinRequestsReject => 'Reject';

  @override
  String get shgJoinRequestsWorking => 'Working…';

  @override
  String get shgJoinRequestsApprove => 'Approve';

  @override
  String get shgJoinRequestsApproveAsLeader => 'Approve as Leader';

  @override
  String get shgMembersTitle => 'Members';

  @override
  String get shgMembersJoinRequestsTooltip => 'Join requests';

  @override
  String get shgMembersEmpty => 'No members found';

  @override
  String get certificatesTitle => 'Certificates';

  @override
  String get certificatesEmptyState =>
      'No certificates earned yet — complete a course quiz to get one';

  @override
  String certificatesCompletedOn(String topic, String date) {
    return '$topic · Completed $date';
  }

  @override
  String get courseDetailTitle => 'Course Detail';

  @override
  String get courseDetailProgressDemoMode =>
      'Demo mode — progress not saved (connect Supabase to persist)';

  @override
  String get courseDetailProgressError =>
      'Could not save your progress. Please try again.';

  @override
  String get courseDetailNotFound => 'This course could not be found';

  @override
  String get trainingVideoPlayerError => 'Couldn\'t load video';

  @override
  String get courseDetailCertifiedBadge => 'Certified';

  @override
  String courseDetailPercentComplete(int pct) {
    return '$pct% complete';
  }

  @override
  String get courseDetailSaving => 'Saving…';

  @override
  String get courseDetailStartCourse => 'Start Course';

  @override
  String get courseDetailContinue => 'Continue';

  @override
  String get courseDetailTakeQuiz => 'Take Quiz & Get Certified';

  @override
  String get courseDetailCertificateEarned =>
      'You earned a certificate for this course!';

  @override
  String get courseDetailFullyComplete => '100% complete';

  @override
  String get courseDetailVideoUnavailable =>
      'No video is attached to this course yet.';

  @override
  String get courseQuizTitle => 'Course Quiz';

  @override
  String courseQuizScoreResult(int score, int total) {
    return 'You scored $score/$total. Try again to pass.';
  }

  @override
  String get courseQuizPassed => 'Passed! Certificate earned.';

  @override
  String get courseQuizPassedDemoMode =>
      'Passed! Demo mode — certificate not saved (connect Supabase to persist)';

  @override
  String get courseQuizSaveError =>
      'Could not save your certificate. Please try again.';

  @override
  String get courseQuizAttemptLimitError =>
      'You\'ve used all 5 attempts for today. Try again after 5:30 AM.';

  @override
  String get courseQuizNotFound => 'This course could not be found';

  @override
  String get courseQuizNoQuizAvailable =>
      'No quiz is available for this course yet';

  @override
  String get courseQuizSubmitButton => 'Submit Quiz';

  @override
  String get courseQuizSubmitting => 'Submitting…';

  @override
  String get trainingHomeTitle => 'Training';

  @override
  String get trainingHomeCertificatesTooltip => 'My certificates';

  @override
  String get trainingHomeEmpty => 'No courses available yet';

  @override
  String get trainingHomeCoursesSection => 'Courses';

  @override
  String get trainingHomeCertifiedBadge => 'Certified';

  @override
  String get loanApplyTitle => 'Apply for Loan';

  @override
  String get loanApplyPurposeLabel => 'Purpose';

  @override
  String get loanApplyPurposeHint => 'e.g. Dairy — buy milch cow';

  @override
  String get loanApplyAmountLabel => 'Amount requested';

  @override
  String get loanApplyTenureLabel => 'Tenure';

  @override
  String loanApplyTenureMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$months $_temp0';
  }

  @override
  String get loanApplySubmitting => 'Submitting…';

  @override
  String get loanApplySubmitButton => 'Submit Application';

  @override
  String get loanApplyPurposeRequiredError => 'Describe what the loan is for';

  @override
  String get loanApplyInvalidAmountError => 'Enter a valid amount';

  @override
  String get loanApplyAmountTooLargeError =>
      'Amount seems unusually large — please check and re-enter';

  @override
  String get loanApplyNoShgError =>
      'You\'re not linked to an SHG, so there\'s nothing to apply for this loan against.';

  @override
  String get loanApplySuccessMessage => 'Loan application submitted for review';

  @override
  String get loanApplyDemoModeMessage =>
      'Demo mode — application not saved (connect Supabase to persist)';

  @override
  String get loanApplySubmitError =>
      'Could not submit this application. Please try again.';

  @override
  String get loansHomeTitle => 'Loans';

  @override
  String get loansHomeApplyTooltip => 'Apply for a loan';

  @override
  String get loansHomeGroupOutstandingLabel => 'Group Outstanding';

  @override
  String get loansHomeMyOutstandingLabel => 'My Outstanding';

  @override
  String get loansHomePlatformOutstandingLabel => 'Platform Outstanding';

  @override
  String loansHomeLoanCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loans',
      one: 'loan',
    );
    return '$count $_temp0';
  }

  @override
  String get loansHomePendingApprovalLabel => 'Pending Approval';

  @override
  String get loansHomeOverdueLabel => 'Overdue';

  @override
  String get loanStatusPending => 'Pending';

  @override
  String get loanStatusActive => 'Active';

  @override
  String get loanStatusOverdue => 'Overdue';

  @override
  String get loanStatusClosed => 'Closed';

  @override
  String get loanStatusRejected => 'Rejected';

  @override
  String get schemeStatusApplied => 'Applied';

  @override
  String get schemeStatusUnderReview => 'Under Review';

  @override
  String get schemeStatusApproved => 'Approved';

  @override
  String get schemeStatusRejected => 'Rejected';

  @override
  String get marketplaceOrderStatusNew => 'New';

  @override
  String get marketplaceOrderStatusPacked => 'Packed';

  @override
  String get marketplaceOrderStatusShipped => 'Shipped';

  @override
  String get marketplaceOrderStatusDelivered => 'Delivered';

  @override
  String get marketplaceCategoryHandicrafts => 'Handicrafts';

  @override
  String get marketplaceCategoryTailoring => 'Tailoring';

  @override
  String get marketplaceCategoryFood => 'Food';

  @override
  String get marketplaceCategoryAgriculture => 'Agriculture';

  @override
  String get marketplaceCategoryOther => 'Other';

  @override
  String get meetingStatusUpcoming => 'Upcoming';

  @override
  String get meetingStatusCompleted => 'Completed';

  @override
  String get meetingStatusCancelled => 'Cancelled';

  @override
  String get savingsStatusPending => 'Pending';

  @override
  String get savingsStatusVerified => 'Verified';

  @override
  String get loansHomeNeedsReviewTrend => 'Needs review';

  @override
  String get loansHomeActionNeededTrend => 'Action needed';

  @override
  String get loansHomeOnTrackTrend => 'On track';

  @override
  String get loansHomeApplyLabel => 'Apply';

  @override
  String get loansHomeTrackingLabel => 'Tracking';

  @override
  String get loansHomeApprovalsLabel => 'Approvals';

  @override
  String loansHomeApprovalsBadgeSemanticLabel(int count) {
    return 'Approvals, $count pending';
  }

  @override
  String get loansHomeAllLoansTitle => 'All Loans';

  @override
  String get loansHomeAllShgsLoansTitle => 'All Loans (All SHGs)';

  @override
  String get loansHomeMyLoansTitle => 'My Loans';

  @override
  String get loansHomeEmptyMessage => 'No loans yet';

  @override
  String loansHomeOutstandingOfAmount(String outstanding, String amount) {
    return '₹$outstanding of ₹$amount outstanding';
  }

  @override
  String loansHomePurposeAndShg(String purpose, String shg) {
    return '$purpose · $shg';
  }

  @override
  String get loanTrackingTitle => 'Loan Tracking';

  @override
  String get loanTrackingEmptyMessage => 'No active loans to track';

  @override
  String loanTrackingOfAmount(String amount) {
    return 'of ₹$amount';
  }

  @override
  String loanTrackingEmiDueBadge(String emi, String dueDate) {
    return 'EMI ₹$emi due $dueDate';
  }

  @override
  String get loanTrackingDetailsLink => 'Details';

  @override
  String get loanApprovalTitle => 'Loan Approvals';

  @override
  String get loanApprovalEmptyMessage => 'No pending loan applications';

  @override
  String loanApprovalShgName(String shg) {
    return 'SHG: $shg';
  }

  @override
  String loanApprovalTenureMonths(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$months $_temp0 tenure';
  }

  @override
  String get loanApprovalRejectButton => 'Reject';

  @override
  String get loanApprovalRejectingButton => 'Rejecting…';

  @override
  String get loanApprovalApproveButton => 'Approve';

  @override
  String get loanApprovalRejectedMessage => 'Application rejected';

  @override
  String get loanApprovalDemoModeMessage =>
      'Demo mode — decision not saved (connect Supabase to persist)';

  @override
  String get loanApprovalAlreadyDecidedRejectMessage =>
      'This application was already decided by someone else.';

  @override
  String get loanApprovalRejectErrorMessage =>
      'Could not reject this application. Please try again.';

  @override
  String get loanApprovalDialogTitle => 'Approve loan';

  @override
  String loanApprovalDialogEmiForMember(String name) {
    return 'Monthly EMI for $name';
  }

  @override
  String get loanApprovalEmiLabel => 'Monthly EMI';

  @override
  String get loanApprovalInvalidEmiError => 'Enter a valid EMI amount';

  @override
  String get loanApprovalApprovingButton => 'Approving…';

  @override
  String get loanApprovalApproveErrorMessage =>
      'Could not approve this loan. Please try again.';

  @override
  String get loanApprovalApprovedMessage => 'Loan approved';

  @override
  String get loanApprovalAlreadyDecidedApproveMessage =>
      'This loan was already decided by someone else.';

  @override
  String get loanDetailTitle => 'Loan Detail';

  @override
  String get loanDetailNotFoundMessage => 'This loan could not be found';

  @override
  String loanDetailOutstandingOfAmount(String amount) {
    return 'outstanding of ₹$amount';
  }

  @override
  String loanProgressRepaidSemanticLabel(String paid, String total) {
    return 'Repaid ₹$paid of ₹$total';
  }

  @override
  String get loanDetailEmiLabel => 'EMI';

  @override
  String get loanDetailTenureLabel => 'Tenure';

  @override
  String loanDetailTenureMonthsValue(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'months',
      one: 'month',
    );
    return '$months $_temp0';
  }

  @override
  String get loanDetailDisbursedLabel => 'Disbursed';

  @override
  String get loanDetailNextDueLabel => 'Next Due';

  @override
  String loanDetailDecidedByLabel(String name) {
    return 'Decided by $name';
  }

  @override
  String get loanDetailRecordPaymentButton => 'Record Payment';

  @override
  String get loanDetailPaymentHistoryTitle => 'Payment History';

  @override
  String get loanDetailNoPaymentsMessage => 'No payments recorded yet';

  @override
  String get loanDetailRecordPaymentDialogTitle => 'Record payment';

  @override
  String get loanDetailPaymentAmountLabel => 'Payment amount';

  @override
  String get loanDetailInvalidAmountError => 'Enter a valid amount';

  @override
  String loanDetailAmountExceedsOutstandingError(String amount) {
    return 'Amount exceeds the outstanding balance of ₹$amount';
  }

  @override
  String get loanDetailRecordingButton => 'Recording…';

  @override
  String get loanDetailRecordButton => 'Record';

  @override
  String get loanDetailRecordErrorMessage =>
      'Could not record this payment. Please try again.';

  @override
  String get loanDetailBalanceChangedErrorMessage =>
      'The outstanding balance changed since this loan was opened — someone else may have just recorded a payment. Close this and check the latest balance before trying again.';

  @override
  String get loanDetailPaymentRecordedMessage => 'Payment recorded';

  @override
  String get loanDetailDemoModeMessage =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get analyticsDashboardTitle => 'Analytics';

  @override
  String get analyticsDashboardTotalShgs => 'Total SHGs';

  @override
  String get analyticsDashboardActiveMembers => 'Active Members';

  @override
  String get analyticsDashboardTotalSavings => 'Total Savings';

  @override
  String get analyticsDashboardLoansDisbursed => 'Loans Disbursed';

  @override
  String get analyticsDashboardLoanRecoveryRate => 'Loan Recovery Rate';

  @override
  String get analyticsDashboardMonitorShgs => 'Monitor SHGs';

  @override
  String get analyticsDashboardPerGroupHealthScores =>
      'Per-group health scores';

  @override
  String get analyticsDashboardChartsLabel => 'Charts';

  @override
  String get analyticsDashboardSavingsTrends => 'Savings Trends';

  @override
  String get analyticsDashboardLoanTrends => 'Loan Trends';

  @override
  String get analyticsDashboardRevenueTrends => 'Revenue Trends';

  @override
  String get analyticsDashboardAttendanceTrends => 'Attendance Trends';

  @override
  String get analyticsDashboardNoDataYet => 'No data yet';

  @override
  String get analyticsShgDetailTitle => 'SHG Analytics';

  @override
  String get analyticsShgDetailNotFound => 'This SHG could not be found';

  @override
  String get shgReportShgNotFound =>
      'This SHG could not be found — it may have been removed';

  @override
  String get analyticsShgDetailMembersLabel => 'Members';

  @override
  String get analyticsShgDetailTotalSavings => 'Total Savings';

  @override
  String get analyticsShgDetailHealthScore => 'Health Score';

  @override
  String get analyticsShgDetailHealthScoreNote =>
      'Based on completed-meeting attendance rate';

  @override
  String get analyticsShgDetailMembersLinkTitle => 'View Members';

  @override
  String get analyticsShgDetailMembersLinkSubtitle => 'Full roster of this SHG';

  @override
  String get analyticsShgDetailJoinRequestsLinkTitle => 'Join Requests';

  @override
  String get analyticsShgDetailJoinRequestsLinkSubtitle =>
      'Pending members waiting to join this SHG';

  @override
  String get analyticsShgListTitle => 'SHGs Monitoring';

  @override
  String get analyticsShgListEmptyState => 'No SHGs to monitor yet';

  @override
  String get analyticsShgListLoadMoreError =>
      'Could not load more SHGs. Please try again.';

  @override
  String analyticsShgListVillageMemberCount(String village, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'members',
      one: 'member',
    );
    return '$village · $count $_temp0';
  }

  @override
  String get livelihoodEntryTitle => 'Add Activity';

  @override
  String get livelihoodEntryActivityTypeLabel => 'Activity type';

  @override
  String get livelihoodEntryTypeDairy => 'Dairy';

  @override
  String get livelihoodEntryTypeTailoring => 'Tailoring';

  @override
  String get livelihoodEntryTypeRetail => 'Retail';

  @override
  String get livelihoodEntryTypePoultry => 'Poultry';

  @override
  String get livelihoodEntryTypeAgriculture => 'Agriculture';

  @override
  String get livelihoodEntryTypeHandicrafts => 'Handicrafts';

  @override
  String get livelihoodEntryTypeOther => 'Other';

  @override
  String get livelihoodStatusPlanned => 'Planned';

  @override
  String get livelihoodStatusActive => 'Active';

  @override
  String get livelihoodStatusCompleted => 'Completed';

  @override
  String get livelihoodEntryDescriptionLabel => 'Description';

  @override
  String get livelihoodEntryDescriptionHint =>
      'e.g. Milch cow rearing — 2 cows';

  @override
  String get livelihoodEntryInvestmentLabel => 'Initial investment';

  @override
  String get livelihoodEntryDescribeRequired => 'Describe the activity';

  @override
  String get livelihoodEntryInvalidInvestment =>
      'Enter a valid investment amount';

  @override
  String get livelihoodEntryInvestmentTooLarge =>
      'Amount seems unusually large — please check and re-enter';

  @override
  String get livelihoodEntryNoShg =>
      'You\'re not linked to an SHG, so there\'s nothing to record this activity against.';

  @override
  String get livelihoodEntryAdded => 'Activity added';

  @override
  String get livelihoodEntryDemoMode =>
      'Demo mode — activity not saved (connect Supabase to persist)';

  @override
  String get livelihoodEntrySaveError =>
      'Could not save this activity. Please try again.';

  @override
  String get livelihoodEntrySaving => 'Saving…';

  @override
  String get livelihoodHomeTitle => 'Livelihoods';

  @override
  String get livelihoodHomeAddActivityTooltip => 'Add activity';

  @override
  String get livelihoodHomeTotalInvestment => 'Total Investment';

  @override
  String get livelihoodHomeTotalRevenue => 'Total Revenue';

  @override
  String get livelihoodHomeEmpty => 'No livelihood activities yet';

  @override
  String livelihoodHomeMemberAndShg(String member, String shg) {
    return '$member · $shg';
  }

  @override
  String livelihoodHomeNetAmount(String amount) {
    return '$amount net';
  }

  @override
  String get livelihoodDetailTitle => 'Activity Detail';

  @override
  String get livelihoodDetailNotFoundMessage =>
      'This activity could not be found';

  @override
  String get livelihoodDetailInvestmentLabel => 'Investment';

  @override
  String get livelihoodDetailRevenueLabel => 'Revenue';

  @override
  String livelihoodDetailNetAmount(String amount) {
    return '$amount net';
  }

  @override
  String get livelihoodDetailProfitSoFar => 'Profit so far';

  @override
  String get livelihoodDetailLossSoFar => 'Loss so far';

  @override
  String get livelihoodDetailUpdateProgressButton => 'Update Progress';

  @override
  String get livelihoodDetailDialogTitle => 'Update progress';

  @override
  String get livelihoodDetailRevenueToDateLabel => 'Revenue to date';

  @override
  String get livelihoodDetailInvalidRevenueError =>
      'Enter a valid revenue amount';

  @override
  String get livelihoodDetailSaveError =>
      'Could not save this update. Please try again.';

  @override
  String get livelihoodDetailSavingButton => 'Saving…';

  @override
  String get livelihoodDetailSaveButton => 'Save';

  @override
  String get livelihoodDetailProgressUpdatedMessage => 'Progress updated';

  @override
  String get livelihoodDetailDemoModeMessage =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get paymentsHistoryTitle => 'Payment History';

  @override
  String get paymentsHistoryEmpty => 'No payments yet';

  @override
  String paymentsHistoryModePayment(String mode) {
    return '$mode Payment';
  }

  @override
  String get paymentsHomeTitle => 'Digital Payments';

  @override
  String get paymentsHomeScanPay => 'Scan & Pay';

  @override
  String get paymentsHomeHistory => 'History';

  @override
  String get paymentsHomeRecentPayments => 'Recent Payments';

  @override
  String get paymentsHomeViewAll => 'View all';

  @override
  String get paymentsHomeEmpty => 'No payments yet';

  @override
  String get adminMonitoringTitle => 'System Monitoring';

  @override
  String get adminMonitoringRefreshTooltip => 'Refresh';

  @override
  String get adminAuditLogTitle => 'Audit Log';

  @override
  String get adminAuditLogEmpty => 'No audit log entries yet';

  @override
  String get adminAuditLogLoadMoreError =>
      'Could not load more entries. Please try again.';

  @override
  String get adminAuditLogActionRoleChange => 'Role change';

  @override
  String get adminAuditLogActionShgGradeChange => 'SHG grade change';

  @override
  String get adminAuditLogActionLivelihoodOverride =>
      'Livelihood staff override';

  @override
  String get adminAuditLogActionLoanDecision => 'Loan decision';

  @override
  String get adminAuditLogActionDeactivation => 'Account status change';

  @override
  String get adminAuditLogActionShgReassignment => 'SHG reassignment';

  @override
  String adminAuditLogDecisionLabel(String decision) {
    return 'decision: $decision';
  }

  @override
  String get adminAuditLogActiveValue => 'Active';

  @override
  String get adminAuditLogInactiveValue => 'Deactivated';

  @override
  String get adminAuditLogUnknownActor => 'Unknown';

  @override
  String adminAuditLogByAt(String name, String date) {
    return 'By $name · $date';
  }

  @override
  String get adminMonitoringTotalUsers => 'Total Users';

  @override
  String get adminMonitoringTotalShgs => 'Total SHGs';

  @override
  String get adminMonitoringSavingsEntries => 'Savings Entries';

  @override
  String get adminMonitoringLoansPending => 'Loans (pending)';

  @override
  String get adminMonitoringAiModerationBlocksLabel => 'AI Advisor Blocks (7d)';

  @override
  String get adminMonitoringAiModerationMembersFlaggedLabel =>
      'Members Flagged (7d)';

  @override
  String get adminMonitoringUptimeLabel => 'Uptime (24h)';

  @override
  String get adminMonitoringAvgLatencyLabel => 'Avg Latency';

  @override
  String get adminMonitoringErrorRateLabel => 'Error Rate (24h)';

  @override
  String get adminMonitoringScheduledJobsLabel => 'Scheduled Jobs';

  @override
  String get adminMonitoringScheduledJobsHealthy => 'Healthy';

  @override
  String get adminMonitoringScheduledJobsUnhealthy => 'Unhealthy';

  @override
  String get adminMonitoringScopeLabel => 'About these metrics';

  @override
  String get adminMonitoringScopeDescription =>
      'Uptime/latency/error rate come from a real database round-trip check, run every 5 minutes and on every visit to this page. This measures our own backend, not a full third-party view of every layer of the stack.';

  @override
  String adminMonitoringCheckedAt(String date) {
    return 'Checked $date';
  }

  @override
  String get aiHubTitle => 'AI Advisors';

  @override
  String get aiHubAskAdvisor => 'Ask an advisor';

  @override
  String get aiHubFinancialAdvisorTitle => 'Financial Advisor';

  @override
  String get aiHubFinancialAdvisorSubtitle =>
      'Savings, loans & budgeting guidance';

  @override
  String get aiHubSchemeRecommenderTitle => 'Scheme Recommender';

  @override
  String get aiHubSchemeRecommenderSubtitle =>
      'Find government schemes you qualify for';

  @override
  String get aiHubMarketAdvisorTitle => 'Market Advisor';

  @override
  String get aiHubMarketAdvisorSubtitle =>
      'Pricing & selling tips for your products';

  @override
  String get aiHubVoiceAssistantTitle => 'Voice Assistant';

  @override
  String get aiHubVoiceAssistantSubtitle =>
      'Ask in Telugu, Hindi or English — hands-free';

  @override
  String get announcementDetailTitle => 'Announcement';

  @override
  String get announcementDetailNotFound =>
      'This announcement could not be found';

  @override
  String get announcementCategoryCircular => 'Circular';

  @override
  String get announcementCategoryMeeting => 'Meeting';

  @override
  String get announcementCategoryTraining => 'Training';

  @override
  String get announcementCategoryScheme => 'Scheme';

  @override
  String get announcementsHomeTitle => 'Announcements';

  @override
  String get announcementsHomeEmptyState => 'No announcements yet';

  @override
  String get announcementsHomePostTooltip => 'Post announcement';

  @override
  String get announcementsHomeDialogTitle => 'Post announcement';

  @override
  String get announcementsHomeTitleHint => 'Title';

  @override
  String get announcementsHomeDetailsHint => 'Details';

  @override
  String get announcementsHomePostButton => 'Post';

  @override
  String get announcementsHomeTitleRequired => 'Title is required.';

  @override
  String get announcementsHomeNotLinkedError =>
      'You\'re not linked to an SHG, so there\'s nothing to post this announcement to.';

  @override
  String get announcementsHomePostError =>
      'Could not post this announcement. Please try again.';

  @override
  String get announcementsHomeScopeShg =>
      'This will be posted to your own SHG only.';

  @override
  String get announcementsHomeScopePlatformWide =>
      'This will be visible to every SHG platform-wide.';

  @override
  String get splashBrandName => 'NAVASAKHI';

  @override
  String get splashHeadline => 'Empowering Women.\nTransforming Communities.';

  @override
  String get splashSubtitle =>
      'Savings, loans, meetings, schemes, marketplace & more — everything your SHG needs, in one app.';

  @override
  String get splashFeatureSavingsLoans => 'Savings & Loans';

  @override
  String get splashFeatureGroupManagement => 'Group Management';

  @override
  String get splashFeatureGovtSchemes => 'Govt. Schemes';

  @override
  String get splashFeatureLivelihoods => 'Livelihoods';

  @override
  String get splashGetStarted => 'Get Started';

  @override
  String get splashAvailableLanguages =>
      'Available in English · తెలుగు · हिंदी';

  @override
  String get financialLedgerCashbookLabel => 'Cashbook';

  @override
  String get financialLedgerLedgerLabel => 'Ledger';

  @override
  String get financialLedgerBankLabel => 'Bank';

  @override
  String get financialLedgerAuditLabel => 'Audit';

  @override
  String get financialLedgerAddEntryTooltip => 'Add entry';

  @override
  String get financialLedgerEntryAdded => 'Entry added';

  @override
  String get financialLedgerDemoMode =>
      'Demo mode — not saved (connect Supabase to persist)';

  @override
  String get financialLedgerLoadMoreError =>
      'Could not load more entries. Please try again.';

  @override
  String financialLedgerEmpty(String title) {
    return 'No $title entries yet';
  }

  @override
  String financialLedgerShgName(String shg) {
    return 'SHG: $shg';
  }

  @override
  String get financialLedgerCashbookTitle => 'Cashbook';

  @override
  String get financialLedgerLedgerTitle => 'General Ledger';

  @override
  String get financialLedgerBankTitle => 'Bank Reconciliation';

  @override
  String get financialLedgerAuditTitle => 'Audit Trail';

  @override
  String get financialEntryDialogTitle => 'Add entry';

  @override
  String get financialEntryDialogDescriptionHint => 'Description';

  @override
  String get financialEntryDialogAmountHint => 'Amount';

  @override
  String get financialEntryDialogCreditLabel => 'Credit (in)';

  @override
  String get financialEntryDialogDebitLabel => 'Debit (out)';

  @override
  String get financialEntryDialogDescriptionRequiredError =>
      'Enter a description';

  @override
  String get financialEntryDialogInvalidAmountError => 'Enter a valid amount';

  @override
  String get financialEntryDialogAmountTooLargeError =>
      'Amount seems unusually large — please check and re-enter';

  @override
  String get financialEntryDialogNoShgError =>
      'You\'re not linked to an SHG, so there\'s nothing to record this entry against.';

  @override
  String get financialEntryDialogSaveError =>
      'Could not save this entry. Please try again.';

  @override
  String get financialEntryDialogAddingButton => 'Adding…';

  @override
  String get financialEntryDialogAddButton => 'Add';

  @override
  String get servicesSavingsLabel => 'Savings';

  @override
  String get servicesLoansLabel => 'Loans';

  @override
  String get servicesMeetingsLabel => 'Meetings';

  @override
  String get servicesFinancialRecordsLabel => 'Financial Records';

  @override
  String get servicesLivelihoodsLabel => 'Livelihoods';

  @override
  String get servicesMarketplaceLabel => 'Marketplace';

  @override
  String get servicesDigitalPaymentsLabel => 'Digital Payments';

  @override
  String get servicesGovtSchemesLabel => 'Govt. Schemes';

  @override
  String get servicesTrainingLabel => 'Training';

  @override
  String get servicesSupportLabel => 'Support';

  @override
  String get servicesAiAdvisorsLabel => 'AI Advisors';

  @override
  String get servicesAnnouncementsLabel => 'Announce­ments';

  @override
  String get servicesReportsLabel => 'Reports';

  @override
  String get servicesAnalyticsLabel => 'Analytics';

  @override
  String get servicesManageUsersLabel => 'Manage Users';

  @override
  String get servicesManageSchemesLabel => 'Manage Schemes';

  @override
  String get servicesSystemMonitoringLabel => 'System Monitoring';

  @override
  String get servicesAuditLogLabel => 'Audit Log';

  @override
  String get servicesShgManagementSection => 'SHG Management';

  @override
  String get servicesCommerceSection => 'Commerce';

  @override
  String get servicesLearningSupportSection => 'Learning & Support';

  @override
  String get servicesInsightsSection => 'Insights';

  @override
  String get servicesAdminToolsSection => 'Admin Tools';

  @override
  String get schemeEligibilityShgMembershipMet =>
      'SHG membership — you are linked to an SHG';

  @override
  String get schemeEligibilityShgMembershipUnmet =>
      'Requires SHG membership — you are not linked to an SHG';

  @override
  String schemeEligibilityAgeMet(int actual, int required) {
    return 'SHG registered $actual+ months (requires $required+)';
  }

  @override
  String schemeEligibilityAgeUnmetNoShg(int required) {
    return 'Requires SHG registered $required+ months — you are not linked to an SHG';
  }

  @override
  String schemeEligibilityAgeUnmetNoRecord(int required) {
    return 'Requires SHG registered $required+ months — your SHG\'s registration date isn\'t on record';
  }

  @override
  String schemeEligibilityAgeUnmet(int required, int actual) {
    return 'Requires SHG registered $required+ months — yours is registered $actual months';
  }

  @override
  String schemeEligibilityGradeMet(String grade, String required) {
    return 'SHG grade $grade meets the $required-or-above requirement';
  }

  @override
  String schemeEligibilityGradeUnmetNoShg(String required) {
    return 'Requires SHG grade $required or above — you are not linked to an SHG';
  }

  @override
  String schemeEligibilityGradeUnmetNoRecord(String required) {
    return 'Requires SHG grade $required or above — your SHG\'s grade isn\'t on record';
  }

  @override
  String schemeEligibilityGradeUnmet(String required, String grade) {
    return 'Requires SHG grade $required or above — yours is graded $grade';
  }

  @override
  String adminDashboardActivityNewUser(String name) {
    return 'New user registered — $name';
  }

  @override
  String adminDashboardActivityNewShg(String name) {
    return 'New SHG registered — $name';
  }

  @override
  String adminDashboardActivityDocument(String name) {
    return 'Document uploaded — $name';
  }

  @override
  String get aiAdvisorUpstreamUnavailable =>
      'The advisor service is temporarily unavailable right now. Please try again in a moment.';

  @override
  String get aiAdvisorChatYouLabel => 'You';

  @override
  String get aiAdvisorChatAdvisorLabel => 'Advisor';

  @override
  String get aiAdvisorChatInputHint => 'Ask a question…';

  @override
  String get aiAdvisorChatSendTooltip => 'Send';

  @override
  String get aiAdvisorChatFinancialHint =>
      'Ask about savings, loans, or budgeting for your SHG.';

  @override
  String get aiAdvisorChatSchemeHint =>
      'Ask which government schemes you may be eligible for.';

  @override
  String get aiAdvisorChatMarketHint =>
      'Ask about pricing, demand, or selling your products.';

  @override
  String get actionLoadMore => 'Load more';

  @override
  String get adminUsersLoadMoreError =>
      'Could not load more users. Please try again.';

  @override
  String adminUsersChangeRoleDialogTitle(String name) {
    return 'Change role — $name';
  }

  @override
  String get adminUsersChangeRoleConfirmTitle => 'Change role?';

  @override
  String adminUsersChangeRoleConfirmMessage(
    String name,
    String from,
    String to,
  ) {
    return 'Change $name\'s role from $from to $to?';
  }

  @override
  String get adminUsersChangeRoleConfirmButton => 'Change';

  @override
  String get adminUsersUpdateRoleError =>
      'Could not update this role. Please try again.';

  @override
  String get adminUsersUpdateRoleErrorNeedsShg =>
      'Could not update this role — a Leader must be linked to an SHG first. Use \"Assign SHG\" on this account, then try again.';

  @override
  String get adminUsersAssignShgError =>
      'Could not assign this SHG. Please try again.';

  @override
  String get adminUsersRoleUpdatedMessage => 'Role updated';

  @override
  String get adminUsersRoleUpdatedDemoMessage =>
      'Demo mode — role not saved (connect Supabase to persist)';

  @override
  String adminUsersAssignedToMessage(String name) {
    return 'Assigned to $name';
  }

  @override
  String get adminUsersAssignedToDemoMessage =>
      'Demo mode — assignment not saved (connect Supabase to persist)';

  @override
  String get adminUsersManageTitle => 'Manage Users';

  @override
  String get adminUsersNoUsersFoundMessage => 'No users found';

  @override
  String get adminUsersSearchHint => 'Search by name or mobile';

  @override
  String get adminUsersRoleFilterAll => 'All';

  @override
  String get adminUsersAssignShgTooltip => 'Assign SHG';

  @override
  String get adminUsersDeactivateTooltip => 'Deactivate account';

  @override
  String get adminUsersReactivateTooltip => 'Reactivate account';

  @override
  String get adminUsersInactiveBadge => 'Inactive';

  @override
  String get shgMemberInactiveBadge => 'Inactive';

  @override
  String get adminUsersDeactivateConfirmTitle => 'Deactivate account?';

  @override
  String adminUsersDeactivateConfirmMessage(String name) {
    return '$name will lose access to the app until reactivated. Their historical records (savings, loans, meetings) are kept.';
  }

  @override
  String get adminUsersReactivateConfirmTitle => 'Reactivate account?';

  @override
  String adminUsersReactivateConfirmMessage(String name) {
    return '$name will regain access to the app.';
  }

  @override
  String get adminUsersDeactivateConfirmButton => 'Deactivate';

  @override
  String get adminUsersReactivateConfirmButton => 'Reactivate';

  @override
  String get adminUsersToggleActiveError =>
      'Could not update this account. Please try again.';

  @override
  String get adminUsersLastAdminError =>
      'Cannot deactivate the last active admin account. Promote another account to admin first.';

  @override
  String get adminUsersDeactivatedMessage => 'Account deactivated';

  @override
  String get adminUsersReactivatedMessage => 'Account reactivated';

  @override
  String get adminShgsLoadMoreError =>
      'Could not load more SHGs. Please try again.';

  @override
  String get adminShgsFormationDateLabel => 'Formation date (optional)';

  @override
  String get adminShgsPickDateButton => 'Pick date';

  @override
  String get adminShgsNotGradedOption => 'Not graded';

  @override
  String get adminShgsAddTitle => 'Add SHG';

  @override
  String get adminShgsNameRequiredError => 'SHG name is required.';

  @override
  String get adminShgsAddError => 'Could not add this SHG. Please try again.';

  @override
  String get adminShgsEditTitle => 'Edit SHG';

  @override
  String get adminShgsUpdateError =>
      'Could not update this SHG. Please try again.';

  @override
  String get adminShgsManageTitle => 'Manage SHGs';

  @override
  String get adminShgsAddTooltip => 'Add SHG';

  @override
  String get adminShgsEmptyState => 'No SHGs registered yet';

  @override
  String adminShgsEditTooltip(String name) {
    return 'Edit $name';
  }

  @override
  String get adminShgsNameHint => 'SHG name';

  @override
  String get adminShgsVillageHint => 'Village';

  @override
  String get adminShgsDistrictHint => 'District';

  @override
  String get adminShgsMandalHint => 'Mandal (optional)';

  @override
  String get adminShgsFederationSectionLabel => 'Federation';

  @override
  String get adminShgsVoHint => 'Village Organisation (optional)';

  @override
  String get adminShgsClfHint => 'CLF (optional)';

  @override
  String get adminShgsBankSectionLabel => 'Bank details';

  @override
  String get adminShgsBankNameHint => 'Bank name (optional)';

  @override
  String get adminShgsBankAccountHint => 'Bank account number (optional)';

  @override
  String get adminShgsIfscHint => 'IFSC code (optional)';

  @override
  String get adminShgsFormationDateNotSet => 'Not set';

  @override
  String get adminShgsGradeHint => 'Grade (optional)';

  @override
  String get adminShgsClearFormationDateTooltip => 'Clear formation date';

  @override
  String get adminShgsAddedMessage => 'SHG added';

  @override
  String get adminShgsAddedDemoModeMessage =>
      'Demo mode — SHG not saved (connect Supabase to persist)';

  @override
  String get adminShgsUpdatedMessage => 'SHG updated';

  @override
  String get adminShgsGradeChangeConfirmTitle => 'Change grade?';

  @override
  String adminShgsGradeChangeConfirmMessage(
    String shgName,
    String oldGrade,
    String newGrade,
  ) {
    return 'This changes $shgName\'s grade from $oldGrade to $newGrade, which affects loan/scheme eligibility.';
  }

  @override
  String get paymentsQrScanPrompt => 'Tap to scan a QR code';

  @override
  String paymentsQrPayingLabel(String name) {
    return 'Paying $name';
  }

  @override
  String get paymentsQrAmountLabel => 'Amount';

  @override
  String get paymentsQrPaymentModeLabel => 'Payment mode';

  @override
  String get paymentsQrScannedAmountFilled => 'QR scanned — amount filled in';

  @override
  String get paymentsQrScannedEnterAmount =>
      'QR scanned — enter the amount to pay';

  @override
  String get paymentsQrInvalidAmountError => 'Enter a valid amount';

  @override
  String get paymentsQrAmountTooLargeError =>
      'Amount seems unusually large — please check and re-enter';

  @override
  String paymentsQrPaymentSuccess(String reference) {
    return 'Payment successful · Ref $reference';
  }

  @override
  String get paymentsQrPaymentFailed => 'Payment failed';

  @override
  String get paymentsQrProcessError =>
      'Could not process this payment. Please try again.';

  @override
  String get paymentsQrProcessingButton => 'Processing…';

  @override
  String get paymentsQrPayNowButton => 'Pay Now';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get paymentStatusSuccess => 'Success';

  @override
  String get paymentStatusFailed => 'Failed';

  @override
  String get financialLedgerBalancePrefix => 'Bal';
}
