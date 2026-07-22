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
  String get actionCheckStatus => 'Check Status';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonBack => 'Back';

  @override
  String get asyncErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get asyncErrorNetwork =>
      'Check your internet connection and try again.';

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
  String get settingsNotifComingSoon =>
      'These preferences are saved, but push/local reminders aren\'t sent yet in this version of the app.';

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
  String get yourShg => 'Your SHG (optional)';

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
  String get unknownShg => 'Unknown SHG';

  @override
  String get chooseDifferentShg => 'Choose a different SHG';

  @override
  String get checkingStatus => 'Checking…';

  @override
  String get shgApprovalCheckError =>
      'Could not check status. Please try again.';

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
  String get aiDisclaimer =>
      'AI-generated guidance — may be inaccurate. Not professional financial, legal, or medical advice; confirm important decisions with your SHG leader or a qualified advisor.';
}
