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

  /// No description provided for @settingsNotifComingSoon.
  ///
  /// In en, this message translates to:
  /// **'These preferences are saved, but push/local reminders aren\'t sent yet in this version of the app.'**
  String get settingsNotifComingSoon;

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
