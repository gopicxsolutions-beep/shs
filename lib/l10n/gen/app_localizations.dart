import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NavaSakhi'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMySHG.
  ///
  /// In en, this message translates to:
  /// **'My SHG'**
  String get navMySHG;

  /// No description provided for @navSHGs.
  ///
  /// In en, this message translates to:
  /// **'SHGs'**
  String get navSHGs;

  /// No description provided for @navServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// No description provided for @navMarket.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get navMarket;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get actionSignOut;

  /// No description provided for @actionCheckStatus.
  ///
  /// In en, this message translates to:
  /// **'Check Status'**
  String get actionCheckStatus;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @asyncErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get asyncErrorGeneric;

  /// No description provided for @asyncErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get asyncErrorNetwork;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'ve entered information on this page that hasn\'t been saved yet. Leaving now will lose it.'**
  String get discardChangesMessage;

  /// No description provided for @discardChangesKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get discardChangesKeepEditing;

  /// No description provided for @discardChangesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChangesDiscard;

  /// No description provided for @errorGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get errorGoHome;

  /// No description provided for @error404Title.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get error404Title;

  /// No description provided for @error404Message.
  ///
  /// In en, this message translates to:
  /// **'The page you\'re looking for doesn\'t exist or may have moved.'**
  String get error404Message;

  /// No description provided for @profileLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile'**
  String get profileLoadErrorTitle;

  /// No description provided for @qrPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission was denied.'**
  String get qrPermissionDenied;

  /// No description provided for @qrUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Scanning isn\'t supported on this device.'**
  String get qrUnsupported;

  /// No description provided for @qrCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera not available.'**
  String get qrCameraUnavailable;

  /// No description provided for @qrManualFallbackHint.
  ///
  /// In en, this message translates to:
  /// **'You can still enter details manually.'**
  String get qrManualFallbackHint;

  /// No description provided for @qrEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually instead'**
  String get qrEnterManually;

  /// No description provided for @qrManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get qrManualEntry;

  /// No description provided for @qrTurnOffFlashlight.
  ///
  /// In en, this message translates to:
  /// **'Turn off flashlight'**
  String get qrTurnOffFlashlight;

  /// No description provided for @qrTurnOnFlashlight.
  ///
  /// In en, this message translates to:
  /// **'Turn on flashlight'**
  String get qrTurnOnFlashlight;

  /// No description provided for @qrTakingTooLong.
  ///
  /// In en, this message translates to:
  /// **'Camera is taking too long to start.'**
  String get qrTakingTooLong;

  /// No description provided for @qrScanToPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to Pay'**
  String get qrScanToPayTitle;

  /// No description provided for @qrScanToPayInstructions.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the merchant\'s UPI QR code'**
  String get qrScanToPayInstructions;

  /// No description provided for @qrScanAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Attendance QR'**
  String get qrScanAttendanceTitle;

  /// No description provided for @qrScanAttendanceInstructions.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the QR code displayed at the venue'**
  String get qrScanAttendanceInstructions;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// No description provided for @profileMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get profileMobile;

  /// No description provided for @profileVillage.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get profileVillage;

  /// No description provided for @profileSHG.
  ///
  /// In en, this message translates to:
  /// **'SHG'**
  String get profileSHG;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @profileUpdateDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — not saved (connect Supabase to persist)'**
  String get profileUpdateDemoMode;

  /// No description provided for @profileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile. Please try again.'**
  String get profileUpdateError;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get profileNameRequired;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotifMeetingReminders.
  ///
  /// In en, this message translates to:
  /// **'Meeting reminders'**
  String get settingsNotifMeetingReminders;

  /// No description provided for @settingsNotifPaymentAlerts.
  ///
  /// In en, this message translates to:
  /// **'Payment alerts'**
  String get settingsNotifPaymentAlerts;

  /// No description provided for @settingsNotifAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get settingsNotifAnnouncements;

  /// No description provided for @settingsNotifLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Reminders are scheduled on this device only — not sent by a server. They won\'t reach you if you use a different phone or reinstall the app. If a meeting is cancelled, only this device\'s own reminder is cancelled right away — another member\'s phone may still show a stale reminder for it until she reopens the Meetings tab.'**
  String get settingsNotifLocalOnly;

  /// No description provided for @settingsNotifPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in your phone\'s settings. Turn them on there to actually receive reminders.'**
  String get settingsNotifPermissionDenied;

  /// No description provided for @settingsNotifCancelPendingError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn off these reminders on this device. We\'ll keep retrying automatically — please check your connection, or try again.'**
  String get settingsNotifCancelPendingError;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsPreviewAs.
  ///
  /// In en, this message translates to:
  /// **'Preview as'**
  String get settingsPreviewAs;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersion;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralSection;

  /// No description provided for @settingsPreviewRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'This app lets you preview every role\'s dashboard — switch anytime.'**
  String get settingsPreviewRoleDescription;

  /// No description provided for @settingsPreferenceError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this preference. Please try again.'**
  String get settingsPreferenceError;

  /// No description provided for @settingsRoleSwitchError.
  ///
  /// In en, this message translates to:
  /// **'Could not switch role. Please try again.'**
  String get settingsRoleSwitchError;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language for the app'**
  String get languageSubtitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTelugu.
  ///
  /// In en, this message translates to:
  /// **'తెలుగు'**
  String get languageTelugu;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered mobile number to continue'**
  String get loginSubtitle;

  /// No description provided for @loginSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get loginSending;

  /// No description provided for @loginSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get loginSendOtp;

  /// No description provided for @loginOtpError.
  ///
  /// In en, this message translates to:
  /// **'Could not send OTP. Please check the number and try again.'**
  String get loginOtpError;

  /// No description provided for @loginDataProtected.
  ///
  /// In en, this message translates to:
  /// **'Your data is protected under DAY-NRLM guidelines. We never share your Aadhaar details.'**
  String get loginDataProtected;

  /// No description provided for @loginTermsAgreement.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the Terms of Service & Privacy Policy'**
  String get loginTermsAgreement;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get otpTitle;

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to your phone'**
  String get otpHint;

  /// No description provided for @otpVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit code to '**
  String get otpSentTo;

  /// No description provided for @otpVerifyContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get otpVerifyContinue;

  /// No description provided for @otpVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get otpVerifying;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP in '**
  String get otpResendIn;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend OTP'**
  String get otpResend;

  /// No description provided for @otpDidntReceive.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? Check your SMS inbox.'**
  String get otpDidntReceive;

  /// No description provided for @otpVerifyError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect or expired code. Please try again.'**
  String get otpVerifyError;

  /// No description provided for @otpResendError.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the code. Please try again.'**
  String get otpResendError;

  /// No description provided for @otpDigitLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP digit {position} of 6'**
  String otpDigitLabel(int position);

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your profile'**
  String get profileSetupTitle;

  /// No description provided for @profileSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us a bit about yourself to get started'**
  String get profileSetupSubtitle;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @fieldMandal.
  ///
  /// In en, this message translates to:
  /// **'Mandal'**
  String get fieldMandal;

  /// No description provided for @fieldDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get fieldDistrict;

  /// No description provided for @yourShg.
  ///
  /// In en, this message translates to:
  /// **'Your SHG (optional)'**
  String get yourShg;

  /// No description provided for @searchSelectShg.
  ///
  /// In en, this message translates to:
  /// **'Search & select your SHG'**
  String get searchSelectShg;

  /// No description provided for @changeShg.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeShg;

  /// No description provided for @profileSetupSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get profileSetupSaving;

  /// No description provided for @profileSetupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileSetupContinue;

  /// No description provided for @findYourShg.
  ///
  /// In en, this message translates to:
  /// **'Find your SHG'**
  String get findYourShg;

  /// No description provided for @searchShgHint.
  ///
  /// In en, this message translates to:
  /// **'Search by SHG name'**
  String get searchShgHint;

  /// No description provided for @noShgsFound.
  ///
  /// In en, this message translates to:
  /// **'No SHGs found'**
  String get noShgsFound;

  /// No description provided for @roleSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue as'**
  String get roleSelectTitle;

  /// No description provided for @roleSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your role in the SHG ecosystem to see a tailored experience'**
  String get roleSelectSubtitle;

  /// No description provided for @roleSelectSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your role. Please try again.'**
  String get roleSelectSaveError;

  /// No description provided for @dashboardGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get dashboardGreeting;

  /// No description provided for @shgApprovalWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get shgApprovalWaitingTitle;

  /// No description provided for @shgApprovalWaitingMessage.
  ///
  /// In en, this message translates to:
  /// **'Your request to join has been sent to your SHG leader. You will get access once it is approved.'**
  String get shgApprovalWaitingMessage;

  /// No description provided for @shgApprovalRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Request not approved'**
  String get shgApprovalRejectedTitle;

  /// No description provided for @shgApprovalRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your SHG leader did not approve this request. You can pick a different SHG and try again.'**
  String get shgApprovalRejectedMessage;

  /// No description provided for @unknownShg.
  ///
  /// In en, this message translates to:
  /// **'Unknown SHG'**
  String get unknownShg;

  /// No description provided for @chooseDifferentShg.
  ///
  /// In en, this message translates to:
  /// **'Choose a different SHG'**
  String get chooseDifferentShg;

  /// No description provided for @checkingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingStatus;

  /// No description provided for @shgApprovalCheckError.
  ///
  /// In en, this message translates to:
  /// **'Could not check status. Please try again.'**
  String get shgApprovalCheckError;

  /// No description provided for @voiceNoLoans.
  ///
  /// In en, this message translates to:
  /// **'You have no loans on record.'**
  String get voiceNoLoans;

  /// No description provided for @voiceNoActiveLoans.
  ///
  /// In en, this message translates to:
  /// **'You have no active loans out of {count} on record.'**
  String voiceNoActiveLoans(int count);

  /// No description provided for @voiceLoanActive.
  ///
  /// In en, this message translates to:
  /// **'{purpose}: ₹{amount} loan, ₹{outstanding} still outstanding.'**
  String voiceLoanActive(String purpose, String amount, String outstanding);

  /// No description provided for @voiceSavingsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'You have saved ₹{amount} this month across {count} {count, plural, =1{entry} other{entries}}.'**
  String voiceSavingsThisMonth(String amount, int count);

  /// No description provided for @voiceNoAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'You have no announcements.'**
  String get voiceNoAnnouncements;

  /// No description provided for @voiceOpeningSavingsForm.
  ///
  /// In en, this message translates to:
  /// **'Opening the savings entry form for you.'**
  String get voiceOpeningSavingsForm;

  /// No description provided for @voiceUnknownCommand.
  ///
  /// In en, this message translates to:
  /// **'Sorry, I didn\'t understand that.'**
  String get voiceUnknownCommand;

  /// No description provided for @aiDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated guidance — may be inaccurate. Not professional financial, legal, or medical advice; confirm important decisions with your SHG leader or a qualified advisor.'**
  String get aiDisclaimer;

  /// No description provided for @adminDashboardJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get adminDashboardJustNow;

  /// No description provided for @adminDashboardMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String adminDashboardMinutesAgo(int count);

  /// No description provided for @adminDashboardHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String adminDashboardHoursAgo(int count);

  /// No description provided for @adminDashboardDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String adminDashboardDaysAgo(int count);

  /// No description provided for @adminDashboardMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}mo ago'**
  String adminDashboardMonthsAgo(int count);

  /// No description provided for @adminDashboardTotalShgsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total SHGs'**
  String get adminDashboardTotalShgsLabel;

  /// No description provided for @adminDashboardActiveMembersTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String adminDashboardActiveMembersTrend(int count);

  /// No description provided for @adminDashboardSystemUptimeLabel.
  ///
  /// In en, this message translates to:
  /// **'System Uptime'**
  String get adminDashboardSystemUptimeLabel;

  /// No description provided for @adminDashboardHeartbeatHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get adminDashboardHeartbeatHealthy;

  /// No description provided for @adminDashboardHeartbeatStale.
  ///
  /// In en, this message translates to:
  /// **'Stale'**
  String get adminDashboardHeartbeatStale;

  /// No description provided for @adminDashboardHeartbeatTrend.
  ///
  /// In en, this message translates to:
  /// **'Heartbeat: {time}'**
  String adminDashboardHeartbeatTrend(String time);

  /// No description provided for @adminDashboardHeartbeatPending.
  ///
  /// In en, this message translates to:
  /// **'No heartbeat recorded yet'**
  String get adminDashboardHeartbeatPending;

  /// No description provided for @adminDashboardUsersTile.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminDashboardUsersTile;

  /// No description provided for @adminDashboardShgsTile.
  ///
  /// In en, this message translates to:
  /// **'SHGs'**
  String get adminDashboardShgsTile;

  /// No description provided for @adminDashboardSchemesTile.
  ///
  /// In en, this message translates to:
  /// **'Schemes'**
  String get adminDashboardSchemesTile;

  /// No description provided for @adminDashboardMonitoringTile.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get adminDashboardMonitoringTile;

  /// No description provided for @adminDashboardReportsTile.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminDashboardReportsTile;

  /// No description provided for @adminDashboardPendingReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} scheme applications pending review'**
  String adminDashboardPendingReviewCount(int count);

  /// No description provided for @adminDashboardAwaitingReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Awaiting staff approval or rejection'**
  String get adminDashboardAwaitingReviewSubtitle;

  /// No description provided for @adminDashboardReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminDashboardReviewAction;

  /// No description provided for @adminDashboardPlatformSnapshotTitle.
  ///
  /// In en, this message translates to:
  /// **'Platform Snapshot'**
  String get adminDashboardPlatformSnapshotTitle;

  /// No description provided for @adminDashboardAnalyticsAction.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get adminDashboardAnalyticsAction;

  /// No description provided for @adminDashboardLoansDisbursedLabel.
  ///
  /// In en, this message translates to:
  /// **'Loans Disbursed'**
  String get adminDashboardLoansDisbursedLabel;

  /// No description provided for @adminDashboardTrainingCompletionLabel.
  ///
  /// In en, this message translates to:
  /// **'Training Completion'**
  String get adminDashboardTrainingCompletionLabel;

  /// No description provided for @adminDashboardRecentActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent System Activity'**
  String get adminDashboardRecentActivityTitle;

  /// No description provided for @adminDashboardNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity yet'**
  String get adminDashboardNoRecentActivity;

  /// No description provided for @clfDashboardVillageOrgsLabel.
  ///
  /// In en, this message translates to:
  /// **'Village Orgs'**
  String get clfDashboardVillageOrgsLabel;

  /// No description provided for @clfDashboardShgsTotalTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} SHGs total'**
  String clfDashboardShgsTotalTrend(int count);

  /// No description provided for @clfDashboardTotalSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get clfDashboardTotalSavingsLabel;

  /// No description provided for @clfDashboardFinancialOversightTrend.
  ///
  /// In en, this message translates to:
  /// **'Financial oversight'**
  String get clfDashboardFinancialOversightTrend;

  /// No description provided for @clfDashboardMonitorVillageOrgsTitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor Village Organisations'**
  String get clfDashboardMonitorVillageOrgsTitle;

  /// No description provided for @clfDashboardVillagesShgsSummary.
  ///
  /// In en, this message translates to:
  /// **'{villageCount} villages · {shgCount} SHGs'**
  String clfDashboardVillagesShgsSummary(int villageCount, int shgCount);

  /// No description provided for @clfDashboardVillageWiseShgsTitle.
  ///
  /// In en, this message translates to:
  /// **'Village-wise SHGs'**
  String get clfDashboardVillageWiseShgsTitle;

  /// No description provided for @clfDashboardFederationReportsAction.
  ///
  /// In en, this message translates to:
  /// **'Federation reports'**
  String get clfDashboardFederationReportsAction;

  /// No description provided for @clfDashboardNoVillagesYet.
  ///
  /// In en, this message translates to:
  /// **'No villages yet'**
  String get clfDashboardNoVillagesYet;

  /// No description provided for @clfDashboardShgChartSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Village-wise SHGs bar chart: {summary}'**
  String clfDashboardShgChartSemanticLabel(String summary);

  /// No description provided for @clfDashboardShgChartItemLabel.
  ///
  /// In en, this message translates to:
  /// **'{village} {count} SHGs'**
  String clfDashboardShgChartItemLabel(String village, int count);

  /// No description provided for @clfDashboardFinancialOversightTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Oversight'**
  String get clfDashboardFinancialOversightTitle;

  /// No description provided for @clfDashboardLoansDisbursedLabel.
  ///
  /// In en, this message translates to:
  /// **'Loans Disbursed'**
  String get clfDashboardLoansDisbursedLabel;

  /// No description provided for @clfDashboardRecoveryRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery Rate'**
  String get clfDashboardRecoveryRateLabel;

  /// No description provided for @clfDashboardFullAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Analytics Dashboard'**
  String get clfDashboardFullAnalyticsTitle;

  /// No description provided for @clfDashboardFullAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'KPIs, trends & recovery insights'**
  String get clfDashboardFullAnalyticsSubtitle;

  /// No description provided for @clfDashboardOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get clfDashboardOpenAction;

  /// No description provided for @crpDashboardShgsMonitoredLabel.
  ///
  /// In en, this message translates to:
  /// **'SHGs Monitored'**
  String get crpDashboardShgsMonitoredLabel;

  /// No description provided for @crpDashboardNoShgsYetTrend.
  ///
  /// In en, this message translates to:
  /// **'No SHGs yet'**
  String get crpDashboardNoShgsYetTrend;

  /// No description provided for @crpDashboardAvgHealthScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg. Health Score'**
  String get crpDashboardAvgHealthScoreLabel;

  /// No description provided for @crpDashboardAttendanceProxyTrend.
  ///
  /// In en, this message translates to:
  /// **'Attendance-based proxy'**
  String get crpDashboardAttendanceProxyTrend;

  /// No description provided for @crpDashboardShgsUnderMonitoringTitle.
  ///
  /// In en, this message translates to:
  /// **'SHGs Under Monitoring'**
  String get crpDashboardShgsUnderMonitoringTitle;

  /// No description provided for @crpDashboardViewAllAction.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get crpDashboardViewAllAction;

  /// No description provided for @crpDashboardNoShgsToMonitorYet.
  ///
  /// In en, this message translates to:
  /// **'No SHGs to monitor yet'**
  String get crpDashboardNoShgsToMonitorYet;

  /// No description provided for @crpDashboardShgVillageMembersSummary.
  ///
  /// In en, this message translates to:
  /// **'{village} · {count} members'**
  String crpDashboardShgVillageMembersSummary(String village, int count);

  /// No description provided for @crpDashboardTrainingCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Catalog'**
  String get crpDashboardTrainingCatalogTitle;

  /// No description provided for @crpDashboardNoCoursesYet.
  ///
  /// In en, this message translates to:
  /// **'No courses yet'**
  String get crpDashboardNoCoursesYet;

  /// No description provided for @dashboardTopBarGreeting.
  ///
  /// In en, this message translates to:
  /// **'Namaste, {name} 🙏'**
  String dashboardTopBarGreeting(String name);

  /// No description provided for @dashboardTopBarUnreadAnnouncementsTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} unread announcements'**
  String dashboardTopBarUnreadAnnouncementsTooltip(int count);

  /// No description provided for @dashboardTopBarAnnouncementsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get dashboardTopBarAnnouncementsTooltip;

  /// No description provided for @leaderDashboardGroupSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Savings'**
  String get leaderDashboardGroupSavingsLabel;

  /// No description provided for @leaderDashboardMembersTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String leaderDashboardMembersTrend(int count);

  /// No description provided for @leaderDashboardLoansOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loans Outstanding'**
  String get leaderDashboardLoansOutstandingLabel;

  /// No description provided for @leaderDashboardOverdueTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} overdue'**
  String leaderDashboardOverdueTrend(int count);

  /// No description provided for @leaderDashboardMembersTile.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get leaderDashboardMembersTile;

  /// No description provided for @leaderDashboardApprovalsTile.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get leaderDashboardApprovalsTile;

  /// No description provided for @leaderDashboardApprovalsPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'Approvals, {count} pending'**
  String leaderDashboardApprovalsPendingBadge(int count);

  /// No description provided for @leaderDashboardScheduleTile.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get leaderDashboardScheduleTile;

  /// No description provided for @leaderDashboardReportsTile.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get leaderDashboardReportsTile;

  /// No description provided for @leaderDashboardDefaulterAlert.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{Defaulter Alert} other{Defaulter Alerts}}'**
  String leaderDashboardDefaulterAlert(int count);

  /// No description provided for @leaderDashboardEmiOverdueSinceDate.
  ///
  /// In en, this message translates to:
  /// **'{name} — EMI overdue since {date}'**
  String leaderDashboardEmiOverdueSinceDate(String name, String date);

  /// No description provided for @leaderDashboardEmiOverdue.
  ///
  /// In en, this message translates to:
  /// **'{name} — EMI overdue'**
  String leaderDashboardEmiOverdue(String name);

  /// No description provided for @leaderDashboardViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get leaderDashboardViewAction;

  /// No description provided for @leaderDashboardPendingApprovalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Loan Approvals'**
  String get leaderDashboardPendingApprovalsTitle;

  /// No description provided for @leaderDashboardReviewAllAction.
  ///
  /// In en, this message translates to:
  /// **'Review all'**
  String get leaderDashboardReviewAllAction;

  /// No description provided for @leaderDashboardNoPendingLoans.
  ///
  /// In en, this message translates to:
  /// **'No pending loan requests'**
  String get leaderDashboardNoPendingLoans;

  /// No description provided for @leaderDashboardNextMeetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Next Meeting'**
  String get leaderDashboardNextMeetingTitle;

  /// No description provided for @leaderDashboardManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get leaderDashboardManageAction;

  /// No description provided for @leaderDashboardMeetingFallback.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get leaderDashboardMeetingFallback;

  /// No description provided for @leaderDashboardShgHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'SHG Health'**
  String get leaderDashboardShgHealthTitle;

  /// No description provided for @leaderDashboardGradingLabel.
  ///
  /// In en, this message translates to:
  /// **'Grading'**
  String get leaderDashboardGradingLabel;

  /// No description provided for @leaderDashboardAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get leaderDashboardAttendanceLabel;

  /// No description provided for @leaderDashboardRecoveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery'**
  String get leaderDashboardRecoveryLabel;

  /// No description provided for @memberDashboardMySavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'My Savings'**
  String get memberDashboardMySavingsLabel;

  /// No description provided for @memberDashboardSavingsEntriesTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String memberDashboardSavingsEntriesTrend(int count);

  /// No description provided for @memberDashboardOutstandingLoanLabel.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Loan'**
  String get memberDashboardOutstandingLoanLabel;

  /// No description provided for @memberDashboardNextEmiTrend.
  ///
  /// In en, this message translates to:
  /// **'Next EMI {date}'**
  String memberDashboardNextEmiTrend(String date);

  /// No description provided for @memberDashboardNoDuesTrend.
  ///
  /// In en, this message translates to:
  /// **'No dues'**
  String get memberDashboardNoDuesTrend;

  /// No description provided for @memberDashboardAddSavingsTile.
  ///
  /// In en, this message translates to:
  /// **'Add Savings'**
  String get memberDashboardAddSavingsTile;

  /// No description provided for @memberDashboardApplyLoanTile.
  ///
  /// In en, this message translates to:
  /// **'Apply Loan'**
  String get memberDashboardApplyLoanTile;

  /// No description provided for @memberDashboardAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get memberDashboardAttendanceLabel;

  /// No description provided for @memberDashboardSchemesTile.
  ///
  /// In en, this message translates to:
  /// **'Schemes'**
  String get memberDashboardSchemesTile;

  /// No description provided for @memberDashboardSchemesNewBadge.
  ///
  /// In en, this message translates to:
  /// **'Schemes, {count} new'**
  String memberDashboardSchemesNewBadge(int count);

  /// No description provided for @memberDashboardNewSchemesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String memberDashboardNewSchemesCount(int count);

  /// No description provided for @memberDashboardSchemesAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Schemes available'**
  String get memberDashboardSchemesAvailableLabel;

  /// No description provided for @memberDashboardSavingsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Summary'**
  String get memberDashboardSavingsSummaryTitle;

  /// No description provided for @memberDashboardViewAllAction.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get memberDashboardViewAllAction;

  /// No description provided for @memberDashboardLoanSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Summary'**
  String get memberDashboardLoanSummaryTitle;

  /// No description provided for @memberDashboardTrackAction.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get memberDashboardTrackAction;

  /// No description provided for @memberDashboardOfAmount.
  ///
  /// In en, this message translates to:
  /// **'of ₹{amount}'**
  String memberDashboardOfAmount(String amount);

  /// No description provided for @memberDashboardEmiDueBadge.
  ///
  /// In en, this message translates to:
  /// **'EMI ₹{amount} due {date}'**
  String memberDashboardEmiDueBadge(String amount, String date);

  /// No description provided for @memberDashboardEmiBadge.
  ///
  /// In en, this message translates to:
  /// **'EMI ₹{amount}'**
  String memberDashboardEmiBadge(String amount);

  /// No description provided for @memberDashboardPayNowAction.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get memberDashboardPayNowAction;

  /// No description provided for @memberDashboardMeetingAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'MEETING ALERT'**
  String get memberDashboardMeetingAlertLabel;

  /// No description provided for @memberDashboardMeetingFallback.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get memberDashboardMeetingFallback;

  /// No description provided for @memberDashboardDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get memberDashboardDetailsAction;

  /// No description provided for @memberDashboardTrainingAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'TRAINING ALERT'**
  String get memberDashboardTrainingAlertLabel;

  /// No description provided for @memberDashboardContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get memberDashboardContinueAction;

  /// No description provided for @memberDashboardAiAdvisorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Financial Advisor'**
  String get memberDashboardAiAdvisorTitle;

  /// No description provided for @memberDashboardAiAdvisorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about savings, loans & budgeting'**
  String get memberDashboardAiAdvisorSubtitle;

  /// No description provided for @memberDashboardViewAction.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get memberDashboardViewAction;

  /// No description provided for @memberDashboardRecentAnnouncementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Announcements'**
  String get memberDashboardRecentAnnouncementsTitle;

  /// No description provided for @memberDashboardSeeAllAction.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get memberDashboardSeeAllAction;

  /// No description provided for @memberDashboardNoAnnouncementsYet.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet'**
  String get memberDashboardNoAnnouncementsYet;

  /// No description provided for @memberDashboardUnreadLabel.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get memberDashboardUnreadLabel;

  /// No description provided for @memberDashboardSavingsTrendChartSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Savings trend chart: {summary}'**
  String memberDashboardSavingsTrendChartSemanticLabel(String summary);

  /// No description provided for @attendanceReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance Report'**
  String get attendanceReportTitle;

  /// No description provided for @attendanceReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed meetings yet'**
  String get attendanceReportEmpty;

  /// No description provided for @attendanceReportOverallLabel.
  ///
  /// In en, this message translates to:
  /// **'Overall Attendance'**
  String get attendanceReportOverallLabel;

  /// No description provided for @attendanceReportSummary.
  ///
  /// In en, this message translates to:
  /// **'{present} of {total} meetings attended'**
  String attendanceReportSummary(int present, int total);

  /// No description provided for @federationGrowthTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Growth'**
  String get federationGrowthTitle;

  /// No description provided for @federationGrowthEmpty.
  ///
  /// In en, this message translates to:
  /// **'No savings recorded yet'**
  String get federationGrowthEmpty;

  /// No description provided for @federationGrowthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly total savings across every SHG'**
  String get federationGrowthSubtitle;

  /// No description provided for @federationRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Recovery'**
  String get federationRecoveryTitle;

  /// No description provided for @federationRecoveryLoansDisbursed.
  ///
  /// In en, this message translates to:
  /// **'Loans Disbursed'**
  String get federationRecoveryLoansDisbursed;

  /// No description provided for @federationRecoveryRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery Rate'**
  String get federationRecoveryRateLabel;

  /// No description provided for @federationRecoveryRecoveredLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovered'**
  String get federationRecoveryRecoveredLabel;

  /// No description provided for @federationRecoveryFootnote.
  ///
  /// In en, this message translates to:
  /// **'Across active, overdue & closed loans in every SHG'**
  String get federationRecoveryFootnote;

  /// No description provided for @federationReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Federation Reports'**
  String get federationReportsTitle;

  /// No description provided for @federationReportsVillagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Village-wise SHGs'**
  String get federationReportsVillagesTitle;

  /// No description provided for @federationReportsVillagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SHG count & savings per village'**
  String get federationReportsVillagesSubtitle;

  /// No description provided for @federationReportsRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Recovery'**
  String get federationReportsRecoveryTitle;

  /// No description provided for @federationReportsRecoverySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disbursed vs. repaid across every SHG'**
  String get federationReportsRecoverySubtitle;

  /// No description provided for @federationReportsGrowthTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Growth'**
  String get federationReportsGrowthTitle;

  /// No description provided for @federationReportsGrowthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly savings trend, federation-wide'**
  String get federationReportsGrowthSubtitle;

  /// No description provided for @federationVillagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Village-wise SHGs'**
  String get federationVillagesTitle;

  /// No description provided for @federationVillagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No SHGs registered yet'**
  String get federationVillagesEmpty;

  /// No description provided for @federationVillagesShgCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{SHG} other{SHGs}}'**
  String federationVillagesShgCount(int count);

  /// No description provided for @loanStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Statement'**
  String get loanStatementTitle;

  /// No description provided for @loanStatementEmpty.
  ///
  /// In en, this message translates to:
  /// **'No loans to statement yet'**
  String get loanStatementEmpty;

  /// No description provided for @loanStatementTotalOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Outstanding'**
  String get loanStatementTotalOutstandingLabel;

  /// No description provided for @loanStatementLoanCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{loan} other{loans}}'**
  String loanStatementLoanCount(int count);

  /// No description provided for @loanStatementRepaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Repaid ₹{amount}'**
  String loanStatementRepaidAmount(String amount);

  /// No description provided for @loanStatementAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount ₹{amount}'**
  String loanStatementAmountLabel(String amount);

  /// No description provided for @loanStatementOutstandingAmount.
  ///
  /// In en, this message translates to:
  /// **'Outstanding ₹{amount}'**
  String loanStatementOutstandingAmount(String amount);

  /// No description provided for @loanStatementDisbursedOn.
  ///
  /// In en, this message translates to:
  /// **'Disbursed {date}'**
  String loanStatementDisbursedOn(String date);

  /// No description provided for @memberReportTitle.
  ///
  /// In en, this message translates to:
  /// **'My Reports'**
  String get memberReportTitle;

  /// No description provided for @memberReportTotalSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get memberReportTotalSavingsLabel;

  /// No description provided for @memberReportEntriesTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{entry} other{entries}}'**
  String memberReportEntriesTrend(int count);

  /// No description provided for @memberReportLoanOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loan Outstanding'**
  String get memberReportLoanOutstandingLabel;

  /// No description provided for @memberReportActiveLoansTrend.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String memberReportActiveLoansTrend(int count);

  /// No description provided for @memberReportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get memberReportSectionTitle;

  /// No description provided for @memberReportSavingsStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Statement'**
  String get memberReportSavingsStatementTitle;

  /// No description provided for @memberReportSavingsStatementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Running balance across every savings entry'**
  String get memberReportSavingsStatementSubtitle;

  /// No description provided for @memberReportLoanStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Statement'**
  String get memberReportLoanStatementTitle;

  /// No description provided for @memberReportLoanStatementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every loan, EMI schedule & outstanding balance'**
  String get memberReportLoanStatementSubtitle;

  /// No description provided for @memberReportAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance Report'**
  String get memberReportAttendanceTitle;

  /// No description provided for @memberReportAttendanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{pct}% · {present} of {total} meetings'**
  String memberReportAttendanceSubtitle(String pct, int present, int total);

  /// No description provided for @reportsHubTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsHubTitle;

  /// No description provided for @reportsHubMyReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Reports'**
  String get reportsHubMyReportsTitle;

  /// No description provided for @reportsHubMyReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your savings, loans & attendance summary'**
  String get reportsHubMyReportsSubtitle;

  /// No description provided for @reportsHubShgReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'SHG Reports'**
  String get reportsHubShgReportsTitle;

  /// No description provided for @reportsHubShgReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Group-wide savings, loans & attendance'**
  String get reportsHubShgReportsSubtitle;

  /// No description provided for @reportsHubFederationReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Federation Reports'**
  String get reportsHubFederationReportsTitle;

  /// No description provided for @reportsHubFederationReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aggregated across every SHG'**
  String get reportsHubFederationReportsSubtitle;

  /// No description provided for @shgFinancialSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get shgFinancialSummaryTitle;

  /// No description provided for @shgFinancialSummaryMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get shgFinancialSummaryMembersLabel;

  /// No description provided for @shgFinancialSummaryActiveLoansLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Loans'**
  String get shgFinancialSummaryActiveLoansLabel;

  /// No description provided for @shgFinancialSummaryTotalSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get shgFinancialSummaryTotalSavingsLabel;

  /// No description provided for @shgFinancialSummaryLoanOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loan Outstanding'**
  String get shgFinancialSummaryLoanOutstandingLabel;

  /// No description provided for @shgFinancialSummaryAvgAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Average Attendance'**
  String get shgFinancialSummaryAvgAttendanceLabel;

  /// No description provided for @shgPerformanceReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance Report'**
  String get shgPerformanceReportTitle;

  /// No description provided for @shgPerformanceAvgAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg. Attendance'**
  String get shgPerformanceAvgAttendanceLabel;

  /// No description provided for @shgPerformanceActiveLoansLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Loans'**
  String get shgPerformanceActiveLoansLabel;

  /// No description provided for @shgPerformanceAttendanceTrendLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance Trend'**
  String get shgPerformanceAttendanceTrendLabel;

  /// No description provided for @shgPerformanceEmptyTrend.
  ///
  /// In en, this message translates to:
  /// **'No completed meetings yet'**
  String get shgPerformanceEmptyTrend;

  /// No description provided for @shgReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'SHG Reports'**
  String get shgReportsTitle;

  /// No description provided for @shgReportsFinancialSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Summary'**
  String get shgReportsFinancialSummaryTitle;

  /// No description provided for @shgReportsFinancialSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Savings, loans & attendance at a glance'**
  String get shgReportsFinancialSummarySubtitle;

  /// No description provided for @shgReportsAuditReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Report'**
  String get shgReportsAuditReportTitle;

  /// No description provided for @shgReportsAuditReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Internal & external audit trail'**
  String get shgReportsAuditReportSubtitle;

  /// No description provided for @shgReportsPerformanceReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance Report'**
  String get shgReportsPerformanceReportTitle;

  /// No description provided for @shgReportsPerformanceReportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance trend & loan activity'**
  String get shgReportsPerformanceReportSubtitle;

  /// No description provided for @addProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductTitle;

  /// No description provided for @addProductImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large — please choose one under 5 MB'**
  String get addProductImageTooLarge;

  /// No description provided for @addProductAddPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get addProductAddPhotoOptional;

  /// No description provided for @addProductNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get addProductNameLabel;

  /// No description provided for @addProductNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Handwoven Cotton Saree'**
  String get addProductNameHint;

  /// No description provided for @addProductDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get addProductDescriptionLabel;

  /// No description provided for @addProductDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your product'**
  String get addProductDescriptionHint;

  /// No description provided for @addProductPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (₹)'**
  String get addProductPriceLabel;

  /// No description provided for @addProductStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get addProductStockLabel;

  /// No description provided for @addProductCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get addProductCategoryLabel;

  /// No description provided for @addProductNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a product name'**
  String get addProductNameRequired;

  /// No description provided for @addProductInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get addProductInvalidPrice;

  /// No description provided for @addProductPriceTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Price seems unusually large — please check and re-enter'**
  String get addProductPriceTooLarge;

  /// No description provided for @addProductSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Could not list this product. Please try again.'**
  String get addProductSubmitError;

  /// No description provided for @addProductListedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Product listed'**
  String get addProductListedSuccess;

  /// No description provided for @addProductDemoModeNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — product not saved (connect Supabase to persist)'**
  String get addProductDemoModeNotSaved;

  /// No description provided for @addProductListingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Listing…'**
  String get addProductListingInProgress;

  /// No description provided for @addProductSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'List Product'**
  String get addProductSubmitButton;

  /// No description provided for @marketplaceHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplaceHomeTitle;

  /// No description provided for @marketplaceHomeAddProductTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get marketplaceHomeAddProductTooltip;

  /// No description provided for @marketplaceHomeSellTile.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get marketplaceHomeSellTile;

  /// No description provided for @marketplaceHomeOrdersTile.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get marketplaceHomeOrdersTile;

  /// No description provided for @marketplaceHomeReviewsTile.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get marketplaceHomeReviewsTile;

  /// No description provided for @marketplaceHomeBrowseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse Products'**
  String get marketplaceHomeBrowseProducts;

  /// No description provided for @marketplaceHomeEmptyProducts.
  ///
  /// In en, this message translates to:
  /// **'No products listed yet'**
  String get marketplaceHomeEmptyProducts;

  /// No description provided for @marketplaceOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get marketplaceOrdersTitle;

  /// No description provided for @marketplaceOrdersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get marketplaceOrdersEmpty;

  /// No description provided for @marketplaceReviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get marketplaceReviewsTitle;

  /// No description provided for @marketplaceReviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews on your products yet'**
  String get marketplaceReviewsEmpty;

  /// No description provided for @marketplaceReviewsFromCount.
  ///
  /// In en, this message translates to:
  /// **'from {count} {count, plural, =1{review} other{reviews}}'**
  String marketplaceReviewsFromCount(int count);

  /// No description provided for @marketplaceReviewsRatingSemantics.
  ///
  /// In en, this message translates to:
  /// **'{rating} out of 5 stars'**
  String marketplaceReviewsRatingSemantics(int rating);

  /// No description provided for @orderDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Detail'**
  String get orderDetailTitle;

  /// No description provided for @orderDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This order could not be found'**
  String get orderDetailNotFound;

  /// No description provided for @orderDetailUpdateStatusError.
  ///
  /// In en, this message translates to:
  /// **'Could not update the order status. Please try again.'**
  String get orderDetailUpdateStatusError;

  /// No description provided for @orderDetailUpdateStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get orderDetailUpdateStatusLabel;

  /// No description provided for @orderDetailBuyerLabel.
  ///
  /// In en, this message translates to:
  /// **'Buyer: {name}'**
  String orderDetailBuyerLabel(String name);

  /// No description provided for @orderDetailOrderedOn.
  ///
  /// In en, this message translates to:
  /// **'Ordered {date}'**
  String orderDetailOrderedOn(String date);

  /// No description provided for @productDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productDetailTitle;

  /// No description provided for @productDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This product could not be found'**
  String get productDetailNotFound;

  /// No description provided for @productDetailWriteReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get productDetailWriteReviewTitle;

  /// No description provided for @productDetailStarTooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{star} other{stars}}'**
  String productDetailStarTooltip(int count);

  /// No description provided for @productDetailReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience with this product (optional)'**
  String get productDetailReviewHint;

  /// No description provided for @productDetailReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get productDetailReviewSubmitted;

  /// No description provided for @productDetailReviewDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — review not saved (connect Supabase to persist)'**
  String get productDetailReviewDemoMode;

  /// No description provided for @productDetailReviewSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your review. You may need to purchase this product first.'**
  String get productDetailReviewSubmitError;

  /// No description provided for @productDetailOrderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get productDetailOrderPlaced;

  /// No description provided for @productDetailOrderDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — order not saved (connect Supabase to persist)'**
  String get productDetailOrderDemoMode;

  /// No description provided for @productDetailOrderPlaceError.
  ///
  /// In en, this message translates to:
  /// **'Could not place this order. Please try again.'**
  String get productDetailOrderPlaceError;

  /// No description provided for @productDetailBySeller.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String productDetailBySeller(String name);

  /// No description provided for @productDetailInStock.
  ///
  /// In en, this message translates to:
  /// **'{count} in stock'**
  String productDetailInStock(int count);

  /// No description provided for @productDetailReviewsSection.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get productDetailReviewsSection;

  /// No description provided for @productDetailSubmittingAction.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get productDetailSubmittingAction;

  /// No description provided for @productDetailWriteReviewAction.
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get productDetailWriteReviewAction;

  /// No description provided for @productDetailNoReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get productDetailNoReviewsYet;

  /// No description provided for @productDetailReviewRatingSemantics.
  ///
  /// In en, this message translates to:
  /// **'{rating} out of 5 stars'**
  String productDetailReviewRatingSemantics(int rating);

  /// No description provided for @productDetailPlacingInProgress.
  ///
  /// In en, this message translates to:
  /// **'Placing…'**
  String get productDetailPlacingInProgress;

  /// No description provided for @productDetailPlaceOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get productDetailPlaceOrderButton;

  /// No description provided for @meetingsHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meetingsHomeTitle;

  /// No description provided for @meetingsHomeScheduleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Schedule meeting'**
  String get meetingsHomeScheduleTooltip;

  /// No description provided for @meetingsHomeCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get meetingsHomeCheckIn;

  /// No description provided for @meetingsHomeScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get meetingsHomeScheduleLabel;

  /// No description provided for @meetingsHomeAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get meetingsHomeAttendanceLabel;

  /// No description provided for @meetingsHomeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get meetingsHomeUpcoming;

  /// No description provided for @meetingsHomePastMeetings.
  ///
  /// In en, this message translates to:
  /// **'Past Meetings'**
  String get meetingsHomePastMeetings;

  /// No description provided for @meetingsHomeNoPastMeetings.
  ///
  /// In en, this message translates to:
  /// **'No past meetings yet'**
  String get meetingsHomeNoPastMeetings;

  /// No description provided for @meetingsHomeDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingsHomeDefaultTitle;

  /// No description provided for @meetingDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting Detail'**
  String get meetingDetailTitle;

  /// No description provided for @meetingDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This meeting could not be found'**
  String get meetingDetailNotFound;

  /// No description provided for @meetingDetailDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meetingDetailDefaultTitle;

  /// No description provided for @meetingDetailMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Minutes of Meeting'**
  String get meetingDetailMinutesLabel;

  /// No description provided for @meetingDetailCancelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel meeting?'**
  String get meetingDetailCancelDialogTitle;

  /// No description provided for @meetingDetailCancelDialogContent.
  ///
  /// In en, this message translates to:
  /// **'This marks the {date} meeting as cancelled. Members will see it as cancelled instead of upcoming.'**
  String meetingDetailCancelDialogContent(String date);

  /// No description provided for @meetingDetailKeepMeeting.
  ///
  /// In en, this message translates to:
  /// **'Keep Meeting'**
  String get meetingDetailKeepMeeting;

  /// No description provided for @meetingDetailCancelMeeting.
  ///
  /// In en, this message translates to:
  /// **'Cancel Meeting'**
  String get meetingDetailCancelMeeting;

  /// No description provided for @meetingDetailCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get meetingDetailCancelling;

  /// No description provided for @meetingDetailCancelledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Meeting cancelled'**
  String get meetingDetailCancelledSuccess;

  /// No description provided for @meetingDetailCancelledDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — cancelled for the rest of this session (connect Supabase to persist)'**
  String get meetingDetailCancelledDemoMode;

  /// No description provided for @meetingDetailCancelError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel this meeting. Please try again.'**
  String get meetingDetailCancelError;

  /// No description provided for @meetingDetailAttendanceSection.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get meetingDetailAttendanceSection;

  /// No description provided for @meetingDetailMarkAction.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get meetingDetailMarkAction;

  /// No description provided for @meetingDetailPresentCount.
  ///
  /// In en, this message translates to:
  /// **'{present} / {total} present'**
  String meetingDetailPresentCount(int present, int total);

  /// No description provided for @meetingAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get meetingAttendanceTitle;

  /// No description provided for @meetingAttendanceNoMeetings.
  ///
  /// In en, this message translates to:
  /// **'No meetings to mark attendance for'**
  String get meetingAttendanceNoMeetings;

  /// No description provided for @meetingAttendanceNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members to mark attendance for'**
  String get meetingAttendanceNoMembers;

  /// No description provided for @meetingAttendancePresentCount.
  ///
  /// In en, this message translates to:
  /// **'{present} / {total} present'**
  String meetingAttendancePresentCount(int present, int total);

  /// No description provided for @meetingAttendanceUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update attendance. Please try again.'**
  String get meetingAttendanceUpdateError;

  /// No description provided for @meetingMomTitle.
  ///
  /// In en, this message translates to:
  /// **'Minutes of Meeting'**
  String get meetingMomTitle;

  /// No description provided for @meetingMomNotFound.
  ///
  /// In en, this message translates to:
  /// **'This meeting could not be found'**
  String get meetingMomNotFound;

  /// No description provided for @meetingMomDemoModeNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — not saved (connect Supabase to persist)'**
  String get meetingMomDemoModeNotSaved;

  /// No description provided for @meetingMomSaveDecisionError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this decision. Please try again.'**
  String get meetingMomSaveDecisionError;

  /// No description provided for @meetingMomSaveActionItemError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this action item. Please try again.'**
  String get meetingMomSaveActionItemError;

  /// No description provided for @meetingMomDecisionsSection.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get meetingMomDecisionsSection;

  /// No description provided for @meetingMomNoDecisions.
  ///
  /// In en, this message translates to:
  /// **'No decisions recorded yet'**
  String get meetingMomNoDecisions;

  /// No description provided for @meetingMomAddDecisionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a decision…'**
  String get meetingMomAddDecisionHint;

  /// No description provided for @meetingMomAddDecisionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add decision'**
  String get meetingMomAddDecisionTooltip;

  /// No description provided for @meetingMomActionItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Action Items'**
  String get meetingMomActionItemsSection;

  /// No description provided for @meetingMomNoActionItems.
  ///
  /// In en, this message translates to:
  /// **'No action items yet'**
  String get meetingMomNoActionItems;

  /// No description provided for @meetingMomUpdateActionItemError.
  ///
  /// In en, this message translates to:
  /// **'Could not update this action item. Please try again.'**
  String get meetingMomUpdateActionItemError;

  /// No description provided for @meetingMomAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {name}'**
  String meetingMomAssignedTo(String name);

  /// No description provided for @meetingMomDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String meetingMomDueDate(String date);

  /// No description provided for @meetingMomAssignToLabel.
  ///
  /// In en, this message translates to:
  /// **'Assign to'**
  String get meetingMomAssignToLabel;

  /// No description provided for @meetingMomUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get meetingMomUnassigned;

  /// No description provided for @meetingMomAddTaskHint.
  ///
  /// In en, this message translates to:
  /// **'Add a task…'**
  String get meetingMomAddTaskHint;

  /// No description provided for @meetingMomAddActionItemTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add action item'**
  String get meetingMomAddActionItemTooltip;

  /// No description provided for @meetingScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule Meeting'**
  String get meetingScheduleTitle;

  /// No description provided for @meetingScheduleSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Scheduling…'**
  String get meetingScheduleSubmitting;

  /// No description provided for @meetingScheduleEnterVenueError.
  ///
  /// In en, this message translates to:
  /// **'Enter a venue'**
  String get meetingScheduleEnterVenueError;

  /// No description provided for @meetingScheduleNoShgError.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to an SHG, so there\'s nothing to schedule this meeting for.'**
  String get meetingScheduleNoShgError;

  /// No description provided for @meetingScheduleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Meeting scheduled'**
  String get meetingScheduleSuccess;

  /// No description provided for @meetingScheduleDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — meeting not saved (connect Supabase to persist)'**
  String get meetingScheduleDemoMode;

  /// No description provided for @meetingScheduleError.
  ///
  /// In en, this message translates to:
  /// **'Could not schedule this meeting. Please try again.'**
  String get meetingScheduleError;

  /// No description provided for @meetingScheduleDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get meetingScheduleDateLabel;

  /// No description provided for @meetingScheduleTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get meetingScheduleTimeLabel;

  /// No description provided for @meetingScheduleVenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Venue'**
  String get meetingScheduleVenueLabel;

  /// No description provided for @meetingScheduleVenueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Anganwadi Centre, Kondapur'**
  String get meetingScheduleVenueHint;

  /// No description provided for @meetingScheduleAgendaLabel.
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get meetingScheduleAgendaLabel;

  /// No description provided for @meetingScheduleAgendaHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monthly savings review & loan applications'**
  String get meetingScheduleAgendaHint;

  /// No description provided for @savingsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Savings'**
  String get savingsEntryTitle;

  /// No description provided for @savingsEntryMemberLabel.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get savingsEntryMemberLabel;

  /// No description provided for @savingsEntryNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found in your SHG yet — there\'s no one to record this entry against.'**
  String get savingsEntryNoMembersFound;

  /// No description provided for @savingsEntrySelectMember.
  ///
  /// In en, this message translates to:
  /// **'Select a member'**
  String get savingsEntrySelectMember;

  /// No description provided for @savingsEntryAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get savingsEntryAmountLabel;

  /// No description provided for @savingsEntryAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get savingsEntryAmountRequired;

  /// No description provided for @savingsEntryAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get savingsEntryAmountInvalid;

  /// No description provided for @savingsEntryAmountZero.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero'**
  String get savingsEntryAmountZero;

  /// No description provided for @savingsEntryAmountTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Amount seems unusually large — please check and re-enter'**
  String get savingsEntryAmountTooLarge;

  /// No description provided for @savingsEntryPaymentModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment mode'**
  String get savingsEntryPaymentModeLabel;

  /// No description provided for @savingsEntryFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get savingsEntryFrequencyLabel;

  /// No description provided for @savingsEntryNoShgError.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to an SHG, so there\'s nothing to record this entry against.'**
  String get savingsEntryNoShgError;

  /// No description provided for @savingsEntrySubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Savings entry submitted for verification'**
  String get savingsEntrySubmittedMessage;

  /// No description provided for @savingsEntryDemoModeMessage.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — entry not saved (connect Supabase to persist)'**
  String get savingsEntryDemoModeMessage;

  /// No description provided for @savingsEntrySaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this entry. Please try again.'**
  String get savingsEntrySaveError;

  /// No description provided for @savingsEntrySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingsEntrySaving;

  /// No description provided for @savingsEntrySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Entry'**
  String get savingsEntrySubmit;

  /// No description provided for @savingsGroupReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Group Savings Report'**
  String get savingsGroupReportTitle;

  /// No description provided for @savingsGroupReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No group savings data yet'**
  String get savingsGroupReportEmpty;

  /// No description provided for @savingsGroupReportTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Total'**
  String get savingsGroupReportTotalLabel;

  /// No description provided for @savingsGroupReportSummary.
  ///
  /// In en, this message translates to:
  /// **'{memberCount} contributing {memberCount, plural, =1{member} other{members}} · {monthCount} {monthCount, plural, =1{month} other{months}} of activity'**
  String savingsGroupReportSummary(int memberCount, int monthCount);

  /// No description provided for @savingsGroupReportRank.
  ///
  /// In en, this message translates to:
  /// **'Rank #{rank}'**
  String savingsGroupReportRank(int rank);

  /// No description provided for @savingsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings History'**
  String get savingsHistoryTitle;

  /// No description provided for @savingsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No savings history yet'**
  String get savingsHistoryEmpty;

  /// No description provided for @savingsFrequencyEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'{frequency} savings'**
  String savingsFrequencyEntryTitle(String frequency);

  /// No description provided for @savingsHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savingsHomeTitle;

  /// No description provided for @savingsHomeAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add savings'**
  String get savingsHomeAddTooltip;

  /// No description provided for @savingsHomeGroupSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Savings'**
  String get savingsHomeGroupSavingsLabel;

  /// No description provided for @savingsHomeMySavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'My Savings'**
  String get savingsHomeMySavingsLabel;

  /// No description provided for @savingsHomeEntriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{entry} other{entries}}'**
  String savingsHomeEntriesCount(int count);

  /// No description provided for @savingsHomePendingVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending Verification'**
  String get savingsHomePendingVerificationLabel;

  /// No description provided for @savingsHomeNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get savingsHomeNeedsReview;

  /// No description provided for @savingsHomeAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get savingsHomeAllCaughtUp;

  /// No description provided for @savingsHomeAddSavingsTile.
  ///
  /// In en, this message translates to:
  /// **'Add Savings'**
  String get savingsHomeAddSavingsTile;

  /// No description provided for @savingsHomeHistoryTile.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get savingsHomeHistoryTile;

  /// No description provided for @savingsHomeStatementTile.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get savingsHomeStatementTile;

  /// No description provided for @savingsHomeLedgerTile.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get savingsHomeLedgerTile;

  /// No description provided for @savingsHomeGroupTile.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get savingsHomeGroupTile;

  /// No description provided for @savingsHomeRecentEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Entries'**
  String get savingsHomeRecentEntriesTitle;

  /// No description provided for @savingsHomeViewAllAction.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get savingsHomeViewAllAction;

  /// No description provided for @savingsHomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No savings entries yet'**
  String get savingsHomeEmpty;

  /// No description provided for @savingsLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Ledger'**
  String get savingsLedgerTitle;

  /// No description provided for @savingsLedgerLiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get savingsLedgerLiveLabel;

  /// No description provided for @savingsLedgerAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add savings'**
  String get savingsLedgerAddTooltip;

  /// No description provided for @savingsLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No savings entries recorded yet'**
  String get savingsLedgerEmpty;

  /// No description provided for @savingsLedgerVerifyError.
  ///
  /// In en, this message translates to:
  /// **'Could not verify this entry. Please try again.'**
  String get savingsLedgerVerifyError;

  /// No description provided for @savingsLedgerVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get savingsLedgerVerifying;

  /// No description provided for @savingsLedgerVerifyAction.
  ///
  /// In en, this message translates to:
  /// **'{amount} · Verify'**
  String savingsLedgerVerifyAction(String amount);

  /// No description provided for @savingsLedgerVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get savingsLedgerVerifiedBadge;

  /// No description provided for @savingsStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Savings Statement'**
  String get savingsStatementTitle;

  /// No description provided for @savingsStatementEmpty.
  ///
  /// In en, this message translates to:
  /// **'No entries to statement yet'**
  String get savingsStatementEmpty;

  /// No description provided for @savingsStatementClosingBalance.
  ///
  /// In en, this message translates to:
  /// **'Closing Balance'**
  String get savingsStatementClosingBalance;

  /// No description provided for @savingsStatementTransactionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{transaction} other{transactions}}'**
  String savingsStatementTransactionsCount(int count);

  /// No description provided for @savingsStatementDateModeHeader.
  ///
  /// In en, this message translates to:
  /// **'DATE / MODE'**
  String get savingsStatementDateModeHeader;

  /// No description provided for @savingsStatementAmountBalanceHeader.
  ///
  /// In en, this message translates to:
  /// **'AMOUNT / BALANCE'**
  String get savingsStatementAmountBalanceHeader;

  /// No description provided for @schemeEligibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Eligibility Checker'**
  String get schemeEligibilityTitle;

  /// No description provided for @schemeEligibilityIntro.
  ///
  /// In en, this message translates to:
  /// **'Checked automatically against your SHG\'s membership, registration age and grade. Some requirements — like BPL status or prior subsidy history — still need manual verification; see each scheme\'s full eligibility list for those.'**
  String get schemeEligibilityIntro;

  /// No description provided for @schemeEligibilityEmptyCatalog.
  ///
  /// In en, this message translates to:
  /// **'No schemes in the catalog yet'**
  String get schemeEligibilityEmptyCatalog;

  /// No description provided for @schemeEligibilitySeeFullDetails.
  ///
  /// In en, this message translates to:
  /// **'See full details'**
  String get schemeEligibilitySeeFullDetails;

  /// No description provided for @schemeEligibilityEligible.
  ///
  /// In en, this message translates to:
  /// **'Eligible'**
  String get schemeEligibilityEligible;

  /// No description provided for @schemeEligibilityNotEligible.
  ///
  /// In en, this message translates to:
  /// **'Not eligible'**
  String get schemeEligibilityNotEligible;

  /// No description provided for @schemeEligibilityNoCriteria.
  ///
  /// In en, this message translates to:
  /// **'No automatic eligibility criteria set for this scheme — open it to see the full requirements.'**
  String get schemeEligibilityNoCriteria;

  /// No description provided for @schemesHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Government Schemes'**
  String get schemesHomeTitle;

  /// No description provided for @schemesHomeEligibilityTile.
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get schemesHomeEligibilityTile;

  /// No description provided for @schemesHomeTrackingTile.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get schemesHomeTrackingTile;

  /// No description provided for @schemesHomeApplicationsTile.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get schemesHomeApplicationsTile;

  /// No description provided for @schemesHomeAllSchemesSection.
  ///
  /// In en, this message translates to:
  /// **'All Schemes'**
  String get schemesHomeAllSchemesSection;

  /// No description provided for @schemesHomeEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No schemes available right now'**
  String get schemesHomeEmptyState;

  /// No description provided for @schemesHomeNotApplied.
  ///
  /// In en, this message translates to:
  /// **'not applied'**
  String get schemesHomeNotApplied;

  /// No description provided for @schemeDetailApplicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted'**
  String get schemeDetailApplicationSubmitted;

  /// No description provided for @schemeDetailApplyError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit this application. Please try again.'**
  String get schemeDetailApplyError;

  /// No description provided for @schemeDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheme Detail'**
  String get schemeDetailTitle;

  /// No description provided for @schemeDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This scheme could not be found'**
  String get schemeDetailNotFound;

  /// No description provided for @schemeDetailBenefitSection.
  ///
  /// In en, this message translates to:
  /// **'Benefit'**
  String get schemeDetailBenefitSection;

  /// No description provided for @schemeDetailEligibilitySection.
  ///
  /// In en, this message translates to:
  /// **'Eligibility'**
  String get schemeDetailEligibilitySection;

  /// No description provided for @schemeDetailApplicationStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Application status: '**
  String get schemeDetailApplicationStatusLabel;

  /// No description provided for @schemeDetailDeadlinePassed.
  ///
  /// In en, this message translates to:
  /// **'Applications closed — the deadline for this scheme has passed.'**
  String get schemeDetailDeadlinePassed;

  /// No description provided for @schemeDetailSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get schemeDetailSubmitting;

  /// No description provided for @schemeDetailApplyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get schemeDetailApplyNow;

  /// No description provided for @schemeDetailDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline: {date}'**
  String schemeDetailDeadlineLabel(String date);

  /// No description provided for @schemeTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Application Tracking'**
  String get schemeTrackingTitle;

  /// No description provided for @schemeTrackingEmptyState.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t applied to any schemes yet'**
  String get schemeTrackingEmptyState;

  /// No description provided for @schemeApplicationsReviewApproved.
  ///
  /// In en, this message translates to:
  /// **'Application approved'**
  String get schemeApplicationsReviewApproved;

  /// No description provided for @schemeApplicationsReviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Application rejected'**
  String get schemeApplicationsReviewRejected;

  /// No description provided for @schemeApplicationsReviewAlreadyDecided.
  ///
  /// In en, this message translates to:
  /// **'This application was already decided by someone else.'**
  String get schemeApplicationsReviewAlreadyDecided;

  /// No description provided for @schemeApplicationsReviewSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this decision. Please try again.'**
  String get schemeApplicationsReviewSaveError;

  /// No description provided for @schemeApplicationsReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheme Applications'**
  String get schemeApplicationsReviewTitle;

  /// No description provided for @schemeApplicationsReviewEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No pending scheme applications'**
  String get schemeApplicationsReviewEmptyState;

  /// No description provided for @schemeApplicationsReviewAppliedOn.
  ///
  /// In en, this message translates to:
  /// **'Applied {date}'**
  String schemeApplicationsReviewAppliedOn(String date);

  /// No description provided for @schemeApplicationsReviewReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get schemeApplicationsReviewReject;

  /// No description provided for @schemeApplicationsReviewSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get schemeApplicationsReviewSaving;

  /// No description provided for @schemeApplicationsReviewApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get schemeApplicationsReviewApprove;

  /// No description provided for @supportStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get supportStatusOpen;

  /// No description provided for @supportStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get supportStatusInProgress;

  /// No description provided for @supportStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get supportStatusResolved;

  /// No description provided for @supportStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportStatusClosed;

  /// No description provided for @supportChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat Support'**
  String get supportChatTitle;

  /// No description provided for @supportChatEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet — raise a ticket to get started'**
  String get supportChatEmptyMessage;

  /// No description provided for @supportFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get supportFaqTitle;

  /// No description provided for @supportHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportHomeTitle;

  /// No description provided for @supportHomeMyTickets.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get supportHomeMyTickets;

  /// No description provided for @supportHomeRaiseTicket.
  ///
  /// In en, this message translates to:
  /// **'Raise Ticket'**
  String get supportHomeRaiseTicket;

  /// No description provided for @supportHomeVoiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Voice Help'**
  String get supportHomeVoiceHelp;

  /// No description provided for @supportHomeFaqs.
  ///
  /// In en, this message translates to:
  /// **'FAQs'**
  String get supportHomeFaqs;

  /// No description provided for @supportHomeAllTickets.
  ///
  /// In en, this message translates to:
  /// **'All Tickets'**
  String get supportHomeAllTickets;

  /// No description provided for @supportHomeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get supportHomeViewAll;

  /// No description provided for @supportHomeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No support tickets yet'**
  String get supportHomeEmptyMessage;

  /// No description provided for @supportTicketDetailSendError.
  ///
  /// In en, this message translates to:
  /// **'Could not send this message. Please try again.'**
  String get supportTicketDetailSendError;

  /// No description provided for @supportTicketDetailStatusError.
  ///
  /// In en, this message translates to:
  /// **'Could not update the ticket status. Please try again.'**
  String get supportTicketDetailStatusError;

  /// No description provided for @supportTicketDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get supportTicketDetailTitle;

  /// No description provided for @supportTicketDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This ticket could not be found'**
  String get supportTicketDetailNotFound;

  /// No description provided for @supportTicketDetailNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get supportTicketDetailNoMessages;

  /// No description provided for @supportTicketDetailYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get supportTicketDetailYou;

  /// No description provided for @supportTicketDetailStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get supportTicketDetailStaff;

  /// No description provided for @supportTicketDetailComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get supportTicketDetailComposerHint;

  /// No description provided for @supportTicketDetailDemoModeHint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — replies disabled'**
  String get supportTicketDetailDemoModeHint;

  /// No description provided for @supportTicketDetailSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get supportTicketDetailSendTooltip;

  /// No description provided for @supportTicketFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Raise a Ticket'**
  String get supportTicketFormTitle;

  /// No description provided for @supportTicketFormSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get supportTicketFormSubjectLabel;

  /// No description provided for @supportTicketFormSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Loan disbursement delay'**
  String get supportTicketFormSubjectHint;

  /// No description provided for @supportTicketFormDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue'**
  String get supportTicketFormDescriptionLabel;

  /// No description provided for @supportTicketFormDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Give as much detail as you can'**
  String get supportTicketFormDescriptionHint;

  /// No description provided for @supportTicketFormSubjectRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a subject for your issue'**
  String get supportTicketFormSubjectRequired;

  /// No description provided for @supportTicketFormSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get supportTicketFormSubmitting;

  /// No description provided for @supportTicketFormSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get supportTicketFormSubmit;

  /// No description provided for @supportTicketFormRaisedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ticket raised'**
  String get supportTicketFormRaisedSuccess;

  /// No description provided for @supportTicketFormDemoModeMessage.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — ticket not saved (connect Supabase to persist)'**
  String get supportTicketFormDemoModeMessage;

  /// No description provided for @supportTicketFormRaiseError.
  ///
  /// In en, this message translates to:
  /// **'Could not raise this ticket. Please try again.'**
  String get supportTicketFormRaiseError;

  /// No description provided for @supportVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Support'**
  String get supportVoiceTitle;

  /// No description provided for @supportVoiceTapToAsk.
  ///
  /// In en, this message translates to:
  /// **'Tap to ask a question'**
  String get supportVoiceTapToAsk;

  /// No description provided for @supportVoiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get supportVoiceListening;

  /// No description provided for @supportVoiceThinking.
  ///
  /// In en, this message translates to:
  /// **'Finding an answer…'**
  String get supportVoiceThinking;

  /// No description provided for @supportVoiceTapToAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Tap to ask again'**
  String get supportVoiceTapToAskAgain;

  /// No description provided for @supportVoiceError.
  ///
  /// In en, this message translates to:
  /// **'Sorry, something went wrong. Please try again.'**
  String get supportVoiceError;

  /// No description provided for @supportVoiceYouAsked.
  ///
  /// In en, this message translates to:
  /// **'You asked'**
  String get supportVoiceYouAsked;

  /// No description provided for @supportVoiceAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get supportVoiceAnswerLabel;

  /// No description provided for @memberDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Member Detail'**
  String get memberDetailTitle;

  /// No description provided for @memberDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This member could not be found'**
  String get memberDetailNotFound;

  /// No description provided for @memberDetailTotalSavings.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get memberDetailTotalSavings;

  /// No description provided for @memberDetailLoanOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Loan Outstanding'**
  String get memberDetailLoanOutstanding;

  /// No description provided for @memberDetailContactSection.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get memberDetailContactSection;

  /// No description provided for @memberDetailMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get memberDetailMobileLabel;

  /// No description provided for @memberDetailVillageLabel.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get memberDetailVillageLabel;

  /// No description provided for @shgHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'My SHG'**
  String get shgHomeTitle;

  /// No description provided for @shgHomeNotLinked.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to an SHG yet'**
  String get shgHomeNotLinked;

  /// No description provided for @shgHomeRegNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Reg. {regNumber}'**
  String shgHomeRegNumberLabel(String regNumber);

  /// No description provided for @shgHomeMembersTile.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get shgHomeMembersTile;

  /// No description provided for @shgHomeDocumentsTile.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get shgHomeDocumentsTile;

  /// No description provided for @shgHomeFederationSection.
  ///
  /// In en, this message translates to:
  /// **'Federation'**
  String get shgHomeFederationSection;

  /// No description provided for @shgHomeVillageOrgLabel.
  ///
  /// In en, this message translates to:
  /// **'Village Organi­sation'**
  String get shgHomeVillageOrgLabel;

  /// No description provided for @shgHomeClfLabel.
  ///
  /// In en, this message translates to:
  /// **'CLF'**
  String get shgHomeClfLabel;

  /// No description provided for @shgHomeMandalLabel.
  ///
  /// In en, this message translates to:
  /// **'Mandal'**
  String get shgHomeMandalLabel;

  /// No description provided for @shgHomeFormedLabel.
  ///
  /// In en, this message translates to:
  /// **'Formed'**
  String get shgHomeFormedLabel;

  /// No description provided for @shgHomeBankDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Bank Details'**
  String get shgHomeBankDetailsSection;

  /// No description provided for @shgHomeBankLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get shgHomeBankLabel;

  /// No description provided for @shgHomeAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get shgHomeAccountLabel;

  /// No description provided for @shgHomeIfscLabel.
  ///
  /// In en, this message translates to:
  /// **'IFSC'**
  String get shgHomeIfscLabel;

  /// No description provided for @shgDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get shgDocumentsTitle;

  /// No description provided for @shgDocumentsAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get shgDocumentsAddTooltip;

  /// No description provided for @shgDocumentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents uploaded yet'**
  String get shgDocumentsEmpty;

  /// No description provided for @shgDocumentsAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get shgDocumentsAddDialogTitle;

  /// No description provided for @shgDocumentsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Document name'**
  String get shgDocumentsNameHint;

  /// No description provided for @shgDocumentsChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file (PDF, JPG, PNG, WEBP)'**
  String get shgDocumentsChooseFile;

  /// No description provided for @shgDocumentsFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large — please choose one under 10 MB'**
  String get shgDocumentsFileTooLarge;

  /// No description provided for @shgDocumentsNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Document name is required.'**
  String get shgDocumentsNameRequired;

  /// No description provided for @shgDocumentsFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose a file to upload.'**
  String get shgDocumentsFileRequired;

  /// No description provided for @shgDocumentsNotLinked.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to an SHG, so there\'s nothing to attach this document to.'**
  String get shgDocumentsNotLinked;

  /// No description provided for @shgDocumentsAdded.
  ///
  /// In en, this message translates to:
  /// **'Document added'**
  String get shgDocumentsAdded;

  /// No description provided for @shgDocumentsAddError.
  ///
  /// In en, this message translates to:
  /// **'Could not add this document. Please try again.'**
  String get shgDocumentsAddError;

  /// No description provided for @shgDocumentsNoFileAttached.
  ///
  /// In en, this message translates to:
  /// **'No file is attached to this record.'**
  String get shgDocumentsNoFileAttached;

  /// No description provided for @shgDocumentsOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open this document.'**
  String get shgDocumentsOpenError;

  /// No description provided for @shgJoinRequestsApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved'**
  String get shgJoinRequestsApproved;

  /// No description provided for @shgJoinRequestsRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get shgJoinRequestsRejected;

  /// No description provided for @shgJoinRequestsDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — not saved (connect Supabase to persist)'**
  String get shgJoinRequestsDemoMode;

  /// No description provided for @shgJoinRequestsProcessError.
  ///
  /// In en, this message translates to:
  /// **'Could not process this request. Please try again.'**
  String get shgJoinRequestsProcessError;

  /// No description provided for @shgJoinRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get shgJoinRequestsTitle;

  /// No description provided for @shgJoinRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending join requests'**
  String get shgJoinRequestsEmpty;

  /// No description provided for @shgJoinRequestsMemberFallback.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get shgJoinRequestsMemberFallback;

  /// No description provided for @shgJoinRequestsRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested {date}'**
  String shgJoinRequestsRequestedOn(String date);

  /// No description provided for @shgJoinRequestsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get shgJoinRequestsReject;

  /// No description provided for @shgJoinRequestsWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get shgJoinRequestsWorking;

  /// No description provided for @shgJoinRequestsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get shgJoinRequestsApprove;

  /// No description provided for @shgMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get shgMembersTitle;

  /// No description provided for @shgMembersJoinRequestsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Join requests'**
  String get shgMembersJoinRequestsTooltip;

  /// No description provided for @shgMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get shgMembersEmpty;

  /// No description provided for @certificatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificatesTitle;

  /// No description provided for @certificatesEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No certificates earned yet — complete a course quiz to get one'**
  String get certificatesEmptyState;

  /// No description provided for @certificatesCompletedOn.
  ///
  /// In en, this message translates to:
  /// **'{topic} · Completed {date}'**
  String certificatesCompletedOn(String topic, String date);

  /// No description provided for @courseDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Detail'**
  String get courseDetailTitle;

  /// No description provided for @courseDetailProgressDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — progress not saved (connect Supabase to persist)'**
  String get courseDetailProgressDemoMode;

  /// No description provided for @courseDetailProgressError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your progress. Please try again.'**
  String get courseDetailProgressError;

  /// No description provided for @courseDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This course could not be found'**
  String get courseDetailNotFound;

  /// No description provided for @courseDetailCertifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Certified'**
  String get courseDetailCertifiedBadge;

  /// No description provided for @courseDetailPercentComplete.
  ///
  /// In en, this message translates to:
  /// **'{pct}% complete'**
  String courseDetailPercentComplete(int pct);

  /// No description provided for @courseDetailSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get courseDetailSaving;

  /// No description provided for @courseDetailStartCourse.
  ///
  /// In en, this message translates to:
  /// **'Start Course'**
  String get courseDetailStartCourse;

  /// No description provided for @courseDetailContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get courseDetailContinue;

  /// No description provided for @courseDetailTakeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take Quiz & Get Certified'**
  String get courseDetailTakeQuiz;

  /// No description provided for @courseDetailCertificateEarned.
  ///
  /// In en, this message translates to:
  /// **'You earned a certificate for this course!'**
  String get courseDetailCertificateEarned;

  /// No description provided for @courseQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Course Quiz'**
  String get courseQuizTitle;

  /// No description provided for @courseQuizScoreResult.
  ///
  /// In en, this message translates to:
  /// **'You scored {score}/{total}. Try again to pass.'**
  String courseQuizScoreResult(int score, int total);

  /// No description provided for @courseQuizPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed! Certificate earned.'**
  String get courseQuizPassed;

  /// No description provided for @courseQuizPassedDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Passed! Demo mode — certificate not saved (connect Supabase to persist)'**
  String get courseQuizPassedDemoMode;

  /// No description provided for @courseQuizSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save your certificate. Please try again.'**
  String get courseQuizSaveError;

  /// No description provided for @courseQuizNotFound.
  ///
  /// In en, this message translates to:
  /// **'This course could not be found'**
  String get courseQuizNotFound;

  /// No description provided for @courseQuizNoQuizAvailable.
  ///
  /// In en, this message translates to:
  /// **'No quiz is available for this course yet'**
  String get courseQuizNoQuizAvailable;

  /// No description provided for @courseQuizSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Quiz'**
  String get courseQuizSubmitButton;

  /// No description provided for @courseQuizSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get courseQuizSubmitting;

  /// No description provided for @trainingHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingHomeTitle;

  /// No description provided for @trainingHomeCertificatesTooltip.
  ///
  /// In en, this message translates to:
  /// **'My certificates'**
  String get trainingHomeCertificatesTooltip;

  /// No description provided for @trainingHomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No courses available yet'**
  String get trainingHomeEmpty;

  /// No description provided for @trainingHomeCoursesSection.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get trainingHomeCoursesSection;

  /// No description provided for @trainingHomeCertifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Certified'**
  String get trainingHomeCertifiedBadge;

  /// No description provided for @loanApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply for Loan'**
  String get loanApplyTitle;

  /// No description provided for @loanApplyPurposeLabel.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get loanApplyPurposeLabel;

  /// No description provided for @loanApplyPurposeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Dairy — buy milch cow'**
  String get loanApplyPurposeHint;

  /// No description provided for @loanApplyAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount requested'**
  String get loanApplyAmountLabel;

  /// No description provided for @loanApplyTenureLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenure'**
  String get loanApplyTenureLabel;

  /// No description provided for @loanApplyTenureMonths.
  ///
  /// In en, this message translates to:
  /// **'{months} {months, plural, =1{month} other{months}}'**
  String loanApplyTenureMonths(int months);

  /// No description provided for @loanApplySubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get loanApplySubmitting;

  /// No description provided for @loanApplySubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get loanApplySubmitButton;

  /// No description provided for @loanApplyPurposeRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Describe what the loan is for'**
  String get loanApplyPurposeRequiredError;

  /// No description provided for @loanApplyInvalidAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get loanApplyInvalidAmountError;

  /// No description provided for @loanApplyAmountTooLargeError.
  ///
  /// In en, this message translates to:
  /// **'Amount seems unusually large — please check and re-enter'**
  String get loanApplyAmountTooLargeError;

  /// No description provided for @loanApplyNoShgError.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to an SHG, so there\'s nothing to apply for this loan against.'**
  String get loanApplyNoShgError;

  /// No description provided for @loanApplySuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Loan application submitted for review'**
  String get loanApplySuccessMessage;

  /// No description provided for @loanApplyDemoModeMessage.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — application not saved (connect Supabase to persist)'**
  String get loanApplyDemoModeMessage;

  /// No description provided for @loanApplySubmitError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit this application. Please try again.'**
  String get loanApplySubmitError;

  /// No description provided for @loansHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loansHomeTitle;

  /// No description provided for @loansHomeApplyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Apply for a loan'**
  String get loansHomeApplyTooltip;

  /// No description provided for @loansHomeGroupOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'Group Outstanding'**
  String get loansHomeGroupOutstandingLabel;

  /// No description provided for @loansHomeMyOutstandingLabel.
  ///
  /// In en, this message translates to:
  /// **'My Outstanding'**
  String get loansHomeMyOutstandingLabel;

  /// No description provided for @loansHomeLoanCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{loan} other{loans}}'**
  String loansHomeLoanCount(int count);

  /// No description provided for @loansHomePendingApprovalLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get loansHomePendingApprovalLabel;

  /// No description provided for @loansHomeOverdueLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get loansHomeOverdueLabel;

  /// No description provided for @loansHomeNeedsReviewTrend.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get loansHomeNeedsReviewTrend;

  /// No description provided for @loansHomeActionNeededTrend.
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get loansHomeActionNeededTrend;

  /// No description provided for @loansHomeOnTrackTrend.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get loansHomeOnTrackTrend;

  /// No description provided for @loansHomeApplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get loansHomeApplyLabel;

  /// No description provided for @loansHomeTrackingLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get loansHomeTrackingLabel;

  /// No description provided for @loansHomeApprovalsLabel.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get loansHomeApprovalsLabel;

  /// No description provided for @loansHomeApprovalsBadgeSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Approvals, {count} pending'**
  String loansHomeApprovalsBadgeSemanticLabel(int count);

  /// No description provided for @loansHomeAllLoansTitle.
  ///
  /// In en, this message translates to:
  /// **'All Loans'**
  String get loansHomeAllLoansTitle;

  /// No description provided for @loansHomeMyLoansTitle.
  ///
  /// In en, this message translates to:
  /// **'My Loans'**
  String get loansHomeMyLoansTitle;

  /// No description provided for @loansHomeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No loans yet'**
  String get loansHomeEmptyMessage;

  /// No description provided for @loansHomeOutstandingOfAmount.
  ///
  /// In en, this message translates to:
  /// **'₹{outstanding} of ₹{amount} outstanding'**
  String loansHomeOutstandingOfAmount(String outstanding, String amount);

  /// No description provided for @loanTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan Tracking'**
  String get loanTrackingTitle;

  /// No description provided for @loanTrackingEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No active loans to track'**
  String get loanTrackingEmptyMessage;

  /// No description provided for @loanTrackingOfAmount.
  ///
  /// In en, this message translates to:
  /// **'of ₹{amount}'**
  String loanTrackingOfAmount(String amount);

  /// No description provided for @loanTrackingEmiDueBadge.
  ///
  /// In en, this message translates to:
  /// **'EMI ₹{emi} due {dueDate}'**
  String loanTrackingEmiDueBadge(String emi, String dueDate);

  /// No description provided for @loanTrackingDetailsLink.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get loanTrackingDetailsLink;

  /// No description provided for @analyticsDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsDashboardTitle;

  /// No description provided for @analyticsDashboardTotalShgs.
  ///
  /// In en, this message translates to:
  /// **'Total SHGs'**
  String get analyticsDashboardTotalShgs;

  /// No description provided for @analyticsDashboardActiveMembers.
  ///
  /// In en, this message translates to:
  /// **'Active Members'**
  String get analyticsDashboardActiveMembers;

  /// No description provided for @analyticsDashboardTotalSavings.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get analyticsDashboardTotalSavings;

  /// No description provided for @analyticsDashboardLoansDisbursed.
  ///
  /// In en, this message translates to:
  /// **'Loans Disbursed'**
  String get analyticsDashboardLoansDisbursed;

  /// No description provided for @analyticsDashboardLoanRecoveryRate.
  ///
  /// In en, this message translates to:
  /// **'Loan Recovery Rate'**
  String get analyticsDashboardLoanRecoveryRate;

  /// No description provided for @analyticsDashboardMonitorShgs.
  ///
  /// In en, this message translates to:
  /// **'Monitor SHGs'**
  String get analyticsDashboardMonitorShgs;

  /// No description provided for @analyticsDashboardPerGroupHealthScores.
  ///
  /// In en, this message translates to:
  /// **'Per-group health scores'**
  String get analyticsDashboardPerGroupHealthScores;

  /// No description provided for @analyticsDashboardChartsLabel.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get analyticsDashboardChartsLabel;

  /// No description provided for @analyticsDashboardSavingsTrends.
  ///
  /// In en, this message translates to:
  /// **'Savings Trends'**
  String get analyticsDashboardSavingsTrends;

  /// No description provided for @analyticsDashboardLoanTrends.
  ///
  /// In en, this message translates to:
  /// **'Loan Trends'**
  String get analyticsDashboardLoanTrends;

  /// No description provided for @analyticsDashboardRevenueTrends.
  ///
  /// In en, this message translates to:
  /// **'Revenue Trends'**
  String get analyticsDashboardRevenueTrends;

  /// No description provided for @analyticsDashboardAttendanceTrends.
  ///
  /// In en, this message translates to:
  /// **'Attendance Trends'**
  String get analyticsDashboardAttendanceTrends;

  /// No description provided for @analyticsDashboardNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get analyticsDashboardNoDataYet;

  /// No description provided for @analyticsShgDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'SHG Analytics'**
  String get analyticsShgDetailTitle;

  /// No description provided for @analyticsShgDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This SHG could not be found'**
  String get analyticsShgDetailNotFound;

  /// No description provided for @analyticsShgDetailMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get analyticsShgDetailMembersLabel;

  /// No description provided for @analyticsShgDetailTotalSavings.
  ///
  /// In en, this message translates to:
  /// **'Total Savings'**
  String get analyticsShgDetailTotalSavings;

  /// No description provided for @analyticsShgDetailHealthScore.
  ///
  /// In en, this message translates to:
  /// **'Health Score'**
  String get analyticsShgDetailHealthScore;

  /// No description provided for @analyticsShgDetailHealthScoreNote.
  ///
  /// In en, this message translates to:
  /// **'Based on completed-meeting attendance rate'**
  String get analyticsShgDetailHealthScoreNote;

  /// No description provided for @analyticsShgListTitle.
  ///
  /// In en, this message translates to:
  /// **'SHGs Monitoring'**
  String get analyticsShgListTitle;

  /// No description provided for @analyticsShgListEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No SHGs to monitor yet'**
  String get analyticsShgListEmptyState;

  /// No description provided for @analyticsShgListVillageMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{village} · {count} {count, plural, =1{member} other{members}}'**
  String analyticsShgListVillageMemberCount(String village, int count);

  /// No description provided for @livelihoodEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Activity'**
  String get livelihoodEntryTitle;

  /// No description provided for @livelihoodEntryActivityTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Activity type'**
  String get livelihoodEntryActivityTypeLabel;

  /// No description provided for @livelihoodEntryTypeDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get livelihoodEntryTypeDairy;

  /// No description provided for @livelihoodEntryTypeTailoring.
  ///
  /// In en, this message translates to:
  /// **'Tailoring'**
  String get livelihoodEntryTypeTailoring;

  /// No description provided for @livelihoodEntryTypeRetail.
  ///
  /// In en, this message translates to:
  /// **'Retail'**
  String get livelihoodEntryTypeRetail;

  /// No description provided for @livelihoodEntryTypePoultry.
  ///
  /// In en, this message translates to:
  /// **'Poultry'**
  String get livelihoodEntryTypePoultry;

  /// No description provided for @livelihoodEntryTypeAgriculture.
  ///
  /// In en, this message translates to:
  /// **'Agriculture'**
  String get livelihoodEntryTypeAgriculture;

  /// No description provided for @livelihoodEntryTypeHandicrafts.
  ///
  /// In en, this message translates to:
  /// **'Handicrafts'**
  String get livelihoodEntryTypeHandicrafts;

  /// No description provided for @livelihoodEntryTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get livelihoodEntryTypeOther;

  /// No description provided for @livelihoodEntryDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get livelihoodEntryDescriptionLabel;

  /// No description provided for @livelihoodEntryDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Milch cow rearing — 2 cows'**
  String get livelihoodEntryDescriptionHint;

  /// No description provided for @livelihoodEntryInvestmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Initial investment'**
  String get livelihoodEntryInvestmentLabel;

  /// No description provided for @livelihoodEntryDescribeRequired.
  ///
  /// In en, this message translates to:
  /// **'Describe the activity'**
  String get livelihoodEntryDescribeRequired;

  /// No description provided for @livelihoodEntryInvalidInvestment.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid investment amount'**
  String get livelihoodEntryInvalidInvestment;

  /// No description provided for @livelihoodEntryNoShg.
  ///
  /// In en, this message translates to:
  /// **'You\'re not linked to an SHG, so there\'s nothing to record this activity against.'**
  String get livelihoodEntryNoShg;

  /// No description provided for @livelihoodEntryAdded.
  ///
  /// In en, this message translates to:
  /// **'Activity added'**
  String get livelihoodEntryAdded;

  /// No description provided for @livelihoodEntryDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — activity not saved (connect Supabase to persist)'**
  String get livelihoodEntryDemoMode;

  /// No description provided for @livelihoodEntrySaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save this activity. Please try again.'**
  String get livelihoodEntrySaveError;

  /// No description provided for @livelihoodEntrySaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get livelihoodEntrySaving;

  /// No description provided for @livelihoodHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Livelihoods'**
  String get livelihoodHomeTitle;

  /// No description provided for @livelihoodHomeAddActivityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add activity'**
  String get livelihoodHomeAddActivityTooltip;

  /// No description provided for @livelihoodHomeTotalInvestment.
  ///
  /// In en, this message translates to:
  /// **'Total Investment'**
  String get livelihoodHomeTotalInvestment;

  /// No description provided for @livelihoodHomeTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get livelihoodHomeTotalRevenue;

  /// No description provided for @livelihoodHomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No livelihood activities yet'**
  String get livelihoodHomeEmpty;

  /// No description provided for @livelihoodHomeNetAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} net'**
  String livelihoodHomeNetAmount(String amount);

  /// No description provided for @paymentsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentsHistoryTitle;

  /// No description provided for @paymentsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get paymentsHistoryEmpty;

  /// No description provided for @paymentsHistoryModePayment.
  ///
  /// In en, this message translates to:
  /// **'{mode} Payment'**
  String paymentsHistoryModePayment(String mode);

  /// No description provided for @paymentsHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Digital Payments'**
  String get paymentsHomeTitle;

  /// No description provided for @paymentsHomeScanPay.
  ///
  /// In en, this message translates to:
  /// **'Scan & Pay'**
  String get paymentsHomeScanPay;

  /// No description provided for @paymentsHomeHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get paymentsHomeHistory;

  /// No description provided for @paymentsHomeRecentPayments.
  ///
  /// In en, this message translates to:
  /// **'Recent Payments'**
  String get paymentsHomeRecentPayments;

  /// No description provided for @paymentsHomeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get paymentsHomeViewAll;

  /// No description provided for @paymentsHomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get paymentsHomeEmpty;

  /// No description provided for @adminMonitoringTitle.
  ///
  /// In en, this message translates to:
  /// **'System Monitoring'**
  String get adminMonitoringTitle;

  /// No description provided for @adminMonitoringTotalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get adminMonitoringTotalUsers;

  /// No description provided for @adminMonitoringTotalShgs.
  ///
  /// In en, this message translates to:
  /// **'Total SHGs'**
  String get adminMonitoringTotalShgs;

  /// No description provided for @adminMonitoringSavingsEntries.
  ///
  /// In en, this message translates to:
  /// **'Savings Entries'**
  String get adminMonitoringSavingsEntries;

  /// No description provided for @adminMonitoringLoansPending.
  ///
  /// In en, this message translates to:
  /// **'Loans (pending)'**
  String get adminMonitoringLoansPending;

  /// No description provided for @adminMonitoringAiModerationBlocksLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Advisor Blocks (7d)'**
  String get adminMonitoringAiModerationBlocksLabel;

  /// No description provided for @adminMonitoringAiModerationMembersFlaggedLabel.
  ///
  /// In en, this message translates to:
  /// **'Members Flagged (7d)'**
  String get adminMonitoringAiModerationMembersFlaggedLabel;

  /// No description provided for @adminMonitoringPlaceholderLabel.
  ///
  /// In en, this message translates to:
  /// **'Placeholder metrics'**
  String get adminMonitoringPlaceholderLabel;

  /// No description provided for @adminMonitoringPlaceholderDescription.
  ///
  /// In en, this message translates to:
  /// **'These are basic row counts, not real infrastructure metrics (uptime, latency, error rate). Wiring real monitoring needs a dedicated Edge Function or an external service.'**
  String get adminMonitoringPlaceholderDescription;

  /// No description provided for @adminMonitoringCheckedAt.
  ///
  /// In en, this message translates to:
  /// **'Checked {date}'**
  String adminMonitoringCheckedAt(String date);

  /// No description provided for @aiHubTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Advisors'**
  String get aiHubTitle;

  /// No description provided for @aiHubAskAdvisor.
  ///
  /// In en, this message translates to:
  /// **'Ask an advisor'**
  String get aiHubAskAdvisor;

  /// No description provided for @aiHubFinancialAdvisorTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial Advisor'**
  String get aiHubFinancialAdvisorTitle;

  /// No description provided for @aiHubFinancialAdvisorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Savings, loans & budgeting guidance'**
  String get aiHubFinancialAdvisorSubtitle;

  /// No description provided for @aiHubSchemeRecommenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheme Recommender'**
  String get aiHubSchemeRecommenderTitle;

  /// No description provided for @aiHubSchemeRecommenderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find government schemes you qualify for'**
  String get aiHubSchemeRecommenderSubtitle;

  /// No description provided for @aiHubMarketAdvisorTitle.
  ///
  /// In en, this message translates to:
  /// **'Market Advisor'**
  String get aiHubMarketAdvisorTitle;

  /// No description provided for @aiHubMarketAdvisorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing & selling tips for your products'**
  String get aiHubMarketAdvisorSubtitle;

  /// No description provided for @aiHubVoiceAssistantTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Assistant'**
  String get aiHubVoiceAssistantTitle;

  /// No description provided for @aiHubVoiceAssistantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask in Telugu, Hindi or English — hands-free'**
  String get aiHubVoiceAssistantSubtitle;

  /// No description provided for @announcementDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get announcementDetailTitle;

  /// No description provided for @announcementDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'This announcement could not be found'**
  String get announcementDetailNotFound;

  /// No description provided for @splashBrandName.
  ///
  /// In en, this message translates to:
  /// **'NAVASAKHI'**
  String get splashBrandName;

  /// No description provided for @splashHeadline.
  ///
  /// In en, this message translates to:
  /// **'Empowering Women.\nTransforming Communities.'**
  String get splashHeadline;

  /// No description provided for @splashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Savings, loans, meetings, schemes, marketplace & more — everything your SHG needs, in one app.'**
  String get splashSubtitle;

  /// No description provided for @splashFeatureSavingsLoans.
  ///
  /// In en, this message translates to:
  /// **'Savings & Loans'**
  String get splashFeatureSavingsLoans;

  /// No description provided for @splashFeatureGroupManagement.
  ///
  /// In en, this message translates to:
  /// **'Group Management'**
  String get splashFeatureGroupManagement;

  /// No description provided for @splashFeatureGovtSchemes.
  ///
  /// In en, this message translates to:
  /// **'Govt. Schemes'**
  String get splashFeatureGovtSchemes;

  /// No description provided for @splashFeatureLivelihoods.
  ///
  /// In en, this message translates to:
  /// **'Livelihoods'**
  String get splashFeatureLivelihoods;

  /// No description provided for @splashGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get splashGetStarted;

  /// No description provided for @splashAvailableLanguages.
  ///
  /// In en, this message translates to:
  /// **'Available in English · తెలుగు · हिंदी'**
  String get splashAvailableLanguages;

  /// No description provided for @financialLedgerCashbookLabel.
  ///
  /// In en, this message translates to:
  /// **'Cashbook'**
  String get financialLedgerCashbookLabel;

  /// No description provided for @financialLedgerLedgerLabel.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get financialLedgerLedgerLabel;

  /// No description provided for @financialLedgerBankLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get financialLedgerBankLabel;

  /// No description provided for @financialLedgerAuditLabel.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get financialLedgerAuditLabel;

  /// No description provided for @financialLedgerAddEntryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get financialLedgerAddEntryTooltip;

  /// No description provided for @financialLedgerEntryAdded.
  ///
  /// In en, this message translates to:
  /// **'Entry added'**
  String get financialLedgerEntryAdded;

  /// No description provided for @financialLedgerDemoMode.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — not saved (connect Supabase to persist)'**
  String get financialLedgerDemoMode;

  /// No description provided for @financialLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No {title} entries yet'**
  String financialLedgerEmpty(String title);

  /// No description provided for @servicesSavingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get servicesSavingsLabel;

  /// No description provided for @servicesLoansLabel.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get servicesLoansLabel;

  /// No description provided for @servicesMeetingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get servicesMeetingsLabel;

  /// No description provided for @servicesFinancialRecordsLabel.
  ///
  /// In en, this message translates to:
  /// **'Financial Records'**
  String get servicesFinancialRecordsLabel;

  /// No description provided for @servicesLivelihoodsLabel.
  ///
  /// In en, this message translates to:
  /// **'Livelihoods'**
  String get servicesLivelihoodsLabel;

  /// No description provided for @servicesMarketplaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get servicesMarketplaceLabel;

  /// No description provided for @servicesDigitalPaymentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Digital Payments'**
  String get servicesDigitalPaymentsLabel;

  /// No description provided for @servicesGovtSchemesLabel.
  ///
  /// In en, this message translates to:
  /// **'Govt. Schemes'**
  String get servicesGovtSchemesLabel;

  /// No description provided for @servicesTrainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get servicesTrainingLabel;

  /// No description provided for @servicesSupportLabel.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get servicesSupportLabel;

  /// No description provided for @servicesAiAdvisorsLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Advisors'**
  String get servicesAiAdvisorsLabel;

  /// No description provided for @servicesAnnouncementsLabel.
  ///
  /// In en, this message translates to:
  /// **'Announce­ments'**
  String get servicesAnnouncementsLabel;

  /// No description provided for @servicesReportsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get servicesReportsLabel;

  /// No description provided for @servicesAnalyticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get servicesAnalyticsLabel;

  /// No description provided for @servicesManageUsersLabel.
  ///
  /// In en, this message translates to:
  /// **'Manage Users'**
  String get servicesManageUsersLabel;

  /// No description provided for @servicesManageSchemesLabel.
  ///
  /// In en, this message translates to:
  /// **'Manage Schemes'**
  String get servicesManageSchemesLabel;

  /// No description provided for @servicesSystemMonitoringLabel.
  ///
  /// In en, this message translates to:
  /// **'System Monitoring'**
  String get servicesSystemMonitoringLabel;

  /// No description provided for @servicesShgManagementSection.
  ///
  /// In en, this message translates to:
  /// **'SHG Management'**
  String get servicesShgManagementSection;

  /// No description provided for @servicesCommerceSection.
  ///
  /// In en, this message translates to:
  /// **'Commerce'**
  String get servicesCommerceSection;

  /// No description provided for @servicesLearningSupportSection.
  ///
  /// In en, this message translates to:
  /// **'Learning & Support'**
  String get servicesLearningSupportSection;

  /// No description provided for @servicesInsightsSection.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get servicesInsightsSection;

  /// No description provided for @servicesAdminToolsSection.
  ///
  /// In en, this message translates to:
  /// **'Admin Tools'**
  String get servicesAdminToolsSection;

  /// No description provided for @schemeEligibilityShgMembershipMet.
  ///
  /// In en, this message translates to:
  /// **'SHG membership — you are linked to an SHG'**
  String get schemeEligibilityShgMembershipMet;

  /// No description provided for @schemeEligibilityShgMembershipUnmet.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG membership — you are not linked to an SHG'**
  String get schemeEligibilityShgMembershipUnmet;

  /// No description provided for @schemeEligibilityAgeMet.
  ///
  /// In en, this message translates to:
  /// **'SHG registered {actual}+ months (requires {required}+)'**
  String schemeEligibilityAgeMet(int actual, int required);

  /// No description provided for @schemeEligibilityAgeUnmetNoShg.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG registered {required}+ months — you are not linked to an SHG'**
  String schemeEligibilityAgeUnmetNoShg(int required);

  /// No description provided for @schemeEligibilityAgeUnmetNoRecord.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG registered {required}+ months — your SHG\'s registration date isn\'t on record'**
  String schemeEligibilityAgeUnmetNoRecord(int required);

  /// No description provided for @schemeEligibilityAgeUnmet.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG registered {required}+ months — yours is registered {actual} months'**
  String schemeEligibilityAgeUnmet(int required, int actual);

  /// No description provided for @schemeEligibilityGradeMet.
  ///
  /// In en, this message translates to:
  /// **'SHG grade {grade} meets the {required}-or-above requirement'**
  String schemeEligibilityGradeMet(String grade, String required);

  /// No description provided for @schemeEligibilityGradeUnmetNoShg.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG grade {required} or above — you are not linked to an SHG'**
  String schemeEligibilityGradeUnmetNoShg(String required);

  /// No description provided for @schemeEligibilityGradeUnmetNoRecord.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG grade {required} or above — your SHG\'s grade isn\'t on record'**
  String schemeEligibilityGradeUnmetNoRecord(String required);

  /// No description provided for @schemeEligibilityGradeUnmet.
  ///
  /// In en, this message translates to:
  /// **'Requires SHG grade {required} or above — yours is graded {grade}'**
  String schemeEligibilityGradeUnmet(String required, String grade);

  /// No description provided for @adminDashboardActivityNewUser.
  ///
  /// In en, this message translates to:
  /// **'New user registered — {name}'**
  String adminDashboardActivityNewUser(String name);

  /// No description provided for @adminDashboardActivityNewShg.
  ///
  /// In en, this message translates to:
  /// **'New SHG registered — {name}'**
  String adminDashboardActivityNewShg(String name);

  /// No description provided for @adminDashboardActivityDocument.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded — {name}'**
  String adminDashboardActivityDocument(String name);

  /// No description provided for @aiAdvisorUpstreamUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The advisor service is temporarily unavailable right now. Please try again in a moment.'**
  String get aiAdvisorUpstreamUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
