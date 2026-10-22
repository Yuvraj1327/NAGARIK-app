import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('mr')
  ];

  /// No description provided for @authCivicGoodTag.
  ///
  /// In en, this message translates to:
  /// **'A CIVIC GOOD INITIATIVE'**
  String get authCivicGoodTag;

  /// No description provided for @authCivicGoodTagline.
  ///
  /// In en, this message translates to:
  /// **'A Civic Good Initiative'**
  String get authCivicGoodTagline;

  /// No description provided for @authHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'See it. Report it.\nGet it fixed.'**
  String get authHeroTitle;

  /// No description provided for @authHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Report roads, streetlights, sanitation, water, electricity and safety issues in your area — then track every one until it\'s resolved.'**
  String get authHeroBody;

  /// No description provided for @authLogInButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogInButton;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check it and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorGoogleConfig.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not set up correctly for this build (check GOOGLE_WEB_CLIENT_ID and the Android package name/SHA-1).'**
  String get authErrorGoogleConfig;

  /// No description provided for @authErrorGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google. Please try again.'**
  String get authErrorGoogleFailed;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalid;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authPasswordTooShort;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateTitle;

  /// No description provided for @authCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join NAGARIK to report and track civic issues.'**
  String get authCreateSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get authNameRequired;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsMismatch;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created. Check your email to confirm before logging in.'**
  String get authAccountCreated;

  /// No description provided for @authLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get authLogoutTitle;

  /// No description provided for @authLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need to log in again to submit or view your reports.'**
  String get authLogoutBody;

  /// No description provided for @authCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get authCancel;

  /// No description provided for @authLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get authLogout;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onbGetStarted;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'See it. Report it. Get it fixed.'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Report roads, streetlights, sanitation, water, electricity and safety issues in your area — then track every one until it\'s resolved. A few quick, optional steps and you\'re in.'**
  String get onbWelcomeBody;

  /// No description provided for @onbPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter a 10-digit mobile number, or skip this step.'**
  String get onbPhoneError;

  /// No description provided for @onbAgeYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I\'m 18 or older'**
  String get onbAgeYes;

  /// No description provided for @onbAgeNo.
  ///
  /// In en, this message translates to:
  /// **'No, I\'m under 18'**
  String get onbAgeNo;

  /// No description provided for @onbUnderstandContinue.
  ///
  /// In en, this message translates to:
  /// **'I understand, continue'**
  String get onbUnderstandContinue;

  /// No description provided for @onbContinueChoices.
  ///
  /// In en, this message translates to:
  /// **'Continue with my choices'**
  String get onbContinueChoices;

  /// No description provided for @onbFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish and open NAGARIK'**
  String get onbFinish;

  /// No description provided for @onbContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onbContinue;

  /// No description provided for @onbLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onbLanguageTitle;

  /// No description provided for @onbLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in Preferences.'**
  String get onbLanguageHint;

  /// No description provided for @onbAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'Fix what\'s around you.'**
  String get onbAboutTitle;

  /// No description provided for @onbAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report it, track it, see it resolved.'**
  String get onbAboutSubtitle;

  /// No description provided for @onbAboutTrackedTitle.
  ///
  /// In en, this message translates to:
  /// **'Every report is tracked'**
  String get onbAboutTrackedTitle;

  /// No description provided for @onbAboutTrackedBody.
  ///
  /// In en, this message translates to:
  /// **'Follow it from Submitted through In Review to Resolved.'**
  String get onbAboutTrackedBody;

  /// No description provided for @onbAboutPinnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Pinned to the exact spot'**
  String get onbAboutPinnedTitle;

  /// No description provided for @onbAboutPinnedBody.
  ///
  /// In en, this message translates to:
  /// **'A photo and a location help the right team find the problem.'**
  String get onbAboutPinnedBody;

  /// No description provided for @onbAboutOnePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Everything in one place'**
  String get onbAboutOnePlaceTitle;

  /// No description provided for @onbAboutOnePlaceBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see all your reports in My Reports, and browse nearby ones.'**
  String get onbAboutOnePlaceBody;

  /// No description provided for @onbNotEmergency.
  ///
  /// In en, this message translates to:
  /// **'NAGARIK is not an emergency service. '**
  String get onbNotEmergency;

  /// No description provided for @onbDangerCall112.
  ///
  /// In en, this message translates to:
  /// **'If you or someone is in danger, call 112.'**
  String get onbDangerCall112;

  /// No description provided for @onbMobileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your mobile number'**
  String get onbMobileTitle;

  /// No description provided for @onbMobileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. It\'s only used if a reviewer needs to reach you about a report — you\'ll still sign in with email or Google.'**
  String get onbMobileSubtitle;

  /// No description provided for @onbMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get onbMobileLabel;

  /// No description provided for @onbAgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you 18 or older?'**
  String get onbAgeTitle;

  /// No description provided for @onbAgeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us follow data protection rules. It is entirely optional — you can skip it.'**
  String get onbAgeSubtitle;

  /// No description provided for @onbAge18OrOlder.
  ///
  /// In en, this message translates to:
  /// **'18 or older'**
  String get onbAge18OrOlder;

  /// No description provided for @onbAgeUnder18.
  ///
  /// In en, this message translates to:
  /// **'Under 18'**
  String get onbAgeUnder18;

  /// No description provided for @onbPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data, your choice'**
  String get onbPrivacyTitle;

  /// No description provided for @onbPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on only what you want. Each switch is a separate consent, and your phone still asks before anything is shared.'**
  String get onbPrivacySubtitle;

  /// No description provided for @onbNeededToSignIn.
  ///
  /// In en, this message translates to:
  /// **'NEEDED TO SIGN IN'**
  String get onbNeededToSignIn;

  /// No description provided for @onbYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Your email address'**
  String get onbYourEmail;

  /// No description provided for @onbYourEmailBody.
  ///
  /// In en, this message translates to:
  /// **'To sign you in and keep your reports linked to you.'**
  String get onbYourEmailBody;

  /// No description provided for @onbYouChoose.
  ///
  /// In en, this message translates to:
  /// **'YOU CHOOSE'**
  String get onbYouChoose;

  /// No description provided for @onbLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get onbLocation;

  /// No description provided for @onbCameraPhotos.
  ///
  /// In en, this message translates to:
  /// **'Camera & photos'**
  String get onbCameraPhotos;

  /// No description provided for @onbConsentLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Tag a report with where the issue is, and show what is near you.'**
  String get onbConsentLocationBody;

  /// No description provided for @onbConsentCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Attach the photos you choose to a report.'**
  String get onbConsentCameraBody;

  /// No description provided for @onbPrivacyFooter.
  ///
  /// In en, this message translates to:
  /// **'You can continue with everything off. Features that need a consent you haven\'t given simply won\'t be available.'**
  String get onbPrivacyFooter;

  /// No description provided for @onbPermTitle.
  ///
  /// In en, this message translates to:
  /// **'Two phone permissions'**
  String get onbPermTitle;

  /// No description provided for @onbPermSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your phone will ask you to confirm each one.'**
  String get onbPermSubtitle;

  /// No description provided for @onbPermLocationBody.
  ///
  /// In en, this message translates to:
  /// **'To place a report on the map and show what is near you.'**
  String get onbPermLocationBody;

  /// No description provided for @onbAllowWhileUsing.
  ///
  /// In en, this message translates to:
  /// **'Allow while using the app'**
  String get onbAllowWhileUsing;

  /// No description provided for @onbPermCameraBody.
  ///
  /// In en, this message translates to:
  /// **'To attach a photo of the issue to your report.'**
  String get onbPermCameraBody;

  /// No description provided for @onbAllowCamera.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get onbAllowCamera;

  /// No description provided for @onbPermFooter.
  ///
  /// In en, this message translates to:
  /// **'Skipped one? You can still allow it later when you report an issue.'**
  String get onbPermFooter;

  /// No description provided for @onbAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get onbAllowed;

  /// No description provided for @onbOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get onbOpenSettings;

  /// No description provided for @onbPermOffBody.
  ///
  /// In en, this message translates to:
  /// **'You turned this off on the previous step. You can still allow it later from your phone\'s settings.'**
  String get onbPermOffBody;

  /// No description provided for @onbSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up NAGARIK'**
  String get onbSetupTitle;

  /// No description provided for @onbSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Last step. You can change this any time.'**
  String get onbSetupSubtitle;

  /// No description provided for @onbAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get onbAppearance;

  /// No description provided for @onbThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get onbThemeSystem;

  /// No description provided for @onbThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get onbThemeLight;

  /// No description provided for @onbThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get onbThemeDark;

  /// No description provided for @onbLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get onbLanguage;

  /// No description provided for @onbChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get onbChange;

  /// No description provided for @repCatRoad.
  ///
  /// In en, this message translates to:
  /// **'Road'**
  String get repCatRoad;

  /// No description provided for @repCatStreetlight.
  ///
  /// In en, this message translates to:
  /// **'Streetlight'**
  String get repCatStreetlight;

  /// No description provided for @repCatSanitation.
  ///
  /// In en, this message translates to:
  /// **'Sanitation'**
  String get repCatSanitation;

  /// No description provided for @repCatWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get repCatWater;

  /// No description provided for @repCatElectricity.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get repCatElectricity;

  /// No description provided for @repCatSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get repCatSafety;

  /// No description provided for @repCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get repCatOther;

  /// No description provided for @repStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get repStatusSubmitted;

  /// No description provided for @repStatusInReview.
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get repStatusInReview;

  /// No description provided for @repStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get repStatusResolved;

  /// No description provided for @repTimelineSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report Submitted'**
  String get repTimelineSubmitted;

  /// No description provided for @repTimelineUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get repTimelineUnderReview;

  /// No description provided for @repMapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map unavailable'**
  String get repMapUnavailable;

  /// No description provided for @repMapNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Google Maps is not configured for this build.'**
  String get repMapNotConfigured;

  /// No description provided for @repOpenLargerMap.
  ///
  /// In en, this message translates to:
  /// **'Open larger map'**
  String get repOpenLargerMap;

  /// No description provided for @repSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get repSettings;

  /// No description provided for @repDragPin.
  ///
  /// In en, this message translates to:
  /// **'Drag the pin to adjust'**
  String get repDragPin;

  /// No description provided for @repLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this report.'**
  String get repLoadFailed;

  /// No description provided for @repViewFullDetails.
  ///
  /// In en, this message translates to:
  /// **'View Full Details'**
  String get repViewFullDetails;

  /// No description provided for @repEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit report'**
  String get repEditTitle;

  /// No description provided for @repCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get repCategory;

  /// No description provided for @repDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get repDescription;

  /// No description provided for @repCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get repCity;

  /// No description provided for @repPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get repPinCode;

  /// No description provided for @repDescMin10.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue in at least 10 characters.'**
  String get repDescMin10;

  /// No description provided for @repEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter a city.'**
  String get repEnterCity;

  /// No description provided for @repEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit PIN code.'**
  String get repEnterPin;

  /// No description provided for @repNoMapLocation.
  ///
  /// In en, this message translates to:
  /// **'No map location'**
  String get repNoMapLocation;

  /// No description provided for @repLocationValue.
  ///
  /// In en, this message translates to:
  /// **'Location: {lat}, {lng}'**
  String repLocationValue(String lat, String lng);

  /// No description provided for @repUseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Use current'**
  String get repUseCurrent;

  /// No description provided for @repPhotosHeader.
  ///
  /// In en, this message translates to:
  /// **'Photos ({count}/{max})'**
  String repPhotosHeader(int count, int max);

  /// No description provided for @repAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get repAdd;

  /// No description provided for @repSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get repSaveChanges;

  /// No description provided for @repUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update your report.'**
  String get repUpdateFailed;

  /// No description provided for @repLocationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not get your current location.'**
  String get repLocationFailed;

  /// No description provided for @repPhotoLimit.
  ///
  /// In en, this message translates to:
  /// **'You can attach up to {max} photos.'**
  String repPhotoLimit(int max);

  /// No description provided for @repPhotoLibraryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the photo library. Please try again.'**
  String get repPhotoLibraryFailed;

  /// No description provided for @repCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera. Please try again.'**
  String get repCameraFailed;

  /// No description provided for @repStepType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get repStepType;

  /// No description provided for @repStepPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get repStepPhoto;

  /// No description provided for @repStepPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get repStepPlace;

  /// No description provided for @repStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get repStepDetails;

  /// No description provided for @repStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get repStepReview;

  /// No description provided for @repSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category to continue.'**
  String get repSelectCategory;

  /// No description provided for @repSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit your report. Please try again.'**
  String get repSubmitFailed;

  /// No description provided for @repConfirmPlace.
  ///
  /// In en, this message translates to:
  /// **'Confirm place'**
  String get repConfirmPlace;

  /// No description provided for @repSendReport.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get repSendReport;

  /// No description provided for @repContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get repContinue;

  /// No description provided for @repSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get repSkip;

  /// No description provided for @repReviewAndSend.
  ///
  /// In en, this message translates to:
  /// **'Review and send'**
  String get repReviewAndSend;

  /// No description provided for @repReportAnIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get repReportAnIssue;

  /// No description provided for @repSomeoneInDanger.
  ///
  /// In en, this message translates to:
  /// **'Someone in danger?'**
  String get repSomeoneInDanger;

  /// No description provided for @repCall112First.
  ///
  /// In en, this message translates to:
  /// **'Call 112 first.'**
  String get repCall112First;

  /// No description provided for @repCall112.
  ///
  /// In en, this message translates to:
  /// **'Call 112'**
  String get repCall112;

  /// No description provided for @repWhatToReport.
  ///
  /// In en, this message translates to:
  /// **'What do you want to report?'**
  String get repWhatToReport;

  /// No description provided for @repAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get repAddPhoto;

  /// No description provided for @repAddPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional, but it helps reviewers check faster. Keep a safe distance.'**
  String get repAddPhotoSubtitle;

  /// No description provided for @repCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get repCamera;

  /// No description provided for @repPhotosAdded.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} added.'**
  String repPhotosAdded(int count, int max);

  /// No description provided for @repPlaceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Could not find that place. Try a nearby landmark or area.'**
  String get repPlaceNotFound;

  /// No description provided for @repWhereIsIt.
  ///
  /// In en, this message translates to:
  /// **'Where is it?'**
  String get repWhereIsIt;

  /// No description provided for @repSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search an area or landmark'**
  String get repSearchHint;

  /// No description provided for @repOthersWillSee.
  ///
  /// In en, this message translates to:
  /// **'Others will see'**
  String get repOthersWillSee;

  /// No description provided for @repFindingArea.
  ///
  /// In en, this message translates to:
  /// **'Finding the area…'**
  String get repFindingArea;

  /// No description provided for @repMoveMapToSetArea.
  ///
  /// In en, this message translates to:
  /// **'Move the map to set the area'**
  String get repMoveMapToSetArea;

  /// No description provided for @repSelectedCoords.
  ///
  /// In en, this message translates to:
  /// **'Selected: {lat}, {lng}. Drag the pin, tap the map or use the locate button to change it.'**
  String repSelectedCoords(String lat, String lng);

  /// No description provided for @repPinNoCoords.
  ///
  /// In en, this message translates to:
  /// **'Drag the pin or tap the locate button — your location is only used when you ask for it.'**
  String get repPinNoCoords;

  /// No description provided for @repConfirmPinError.
  ///
  /// In en, this message translates to:
  /// **'Please confirm the pin location above.'**
  String get repConfirmPinError;

  /// No description provided for @repCorrectLocation.
  ///
  /// In en, this message translates to:
  /// **'This is the correct location'**
  String get repCorrectLocation;

  /// No description provided for @repCityArea.
  ///
  /// In en, this message translates to:
  /// **'City / area'**
  String get repCityArea;

  /// No description provided for @repCityRequired.
  ///
  /// In en, this message translates to:
  /// **'City is required.'**
  String get repCityRequired;

  /// No description provided for @repPinRequired.
  ///
  /// In en, this message translates to:
  /// **'PIN code is required.'**
  String get repPinRequired;

  /// No description provided for @repPinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit PIN code.'**
  String get repPinInvalid;

  /// No description provided for @repTellWhatYouSee.
  ///
  /// In en, this message translates to:
  /// **'Tell us what you see'**
  String get repTellWhatYouSee;

  /// No description provided for @repShortDescription.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get repShortDescription;

  /// No description provided for @repNoNamesPhones.
  ///
  /// In en, this message translates to:
  /// **'Do not include names or phone numbers'**
  String get repNoNamesPhones;

  /// No description provided for @repDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Large pothole near the bus stop causing traffic issues'**
  String get repDescriptionHint;

  /// No description provided for @repDescriptionMin.
  ///
  /// In en, this message translates to:
  /// **'Please provide at least 10 characters.'**
  String get repDescriptionMin;

  /// No description provided for @repAnyoneHurt.
  ///
  /// In en, this message translates to:
  /// **'Is anyone hurt or in danger?'**
  String get repAnyoneHurt;

  /// No description provided for @repStillHappening.
  ///
  /// In en, this message translates to:
  /// **'Is it still happening?'**
  String get repStillHappening;

  /// No description provided for @repYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get repYes;

  /// No description provided for @repNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get repNo;

  /// No description provided for @repNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get repNotSure;

  /// No description provided for @repNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get repNotSelected;

  /// No description provided for @repPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get repPhotos;

  /// No description provided for @repNoneAdded.
  ///
  /// In en, this message translates to:
  /// **'None added'**
  String get repNoneAdded;

  /// No description provided for @repPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String repPhotoCount(int count);

  /// No description provided for @repPlaceShown.
  ///
  /// In en, this message translates to:
  /// **'Place shown to others'**
  String get repPlaceShown;

  /// No description provided for @repCityNotSet.
  ///
  /// In en, this message translates to:
  /// **'City not set'**
  String get repCityNotSet;

  /// No description provided for @repPinValue.
  ///
  /// In en, this message translates to:
  /// **'PIN {pin}'**
  String repPinValue(String pin);

  /// No description provided for @repNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description provided.'**
  String get repNoDescription;

  /// No description provided for @repNoOneHurt.
  ///
  /// In en, this message translates to:
  /// **'No one hurt'**
  String get repNoOneHurt;

  /// No description provided for @repSomeoneHurt.
  ///
  /// In en, this message translates to:
  /// **'Someone hurt or in danger'**
  String get repSomeoneHurt;

  /// No description provided for @repStillHappeningExtra.
  ///
  /// In en, this message translates to:
  /// **'Still happening'**
  String get repStillHappeningExtra;

  /// No description provided for @repNoLongerHappening.
  ///
  /// In en, this message translates to:
  /// **'No longer happening'**
  String get repNoLongerHappening;

  /// No description provided for @repNotSureStillHappening.
  ///
  /// In en, this message translates to:
  /// **'Not sure if still happening'**
  String get repNotSureStillHappening;

  /// No description provided for @repCheckDetails.
  ///
  /// In en, this message translates to:
  /// **'Check the details above — you can edit any section before sending.'**
  String get repCheckDetails;

  /// No description provided for @repOnlyReportReal.
  ///
  /// In en, this message translates to:
  /// **'Please only report real issues.'**
  String get repOnlyReportReal;

  /// No description provided for @repEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get repEdit;

  /// No description provided for @repSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get repSubmitted;

  /// No description provided for @repSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you — we have received it and it is now marked as Submitted. Keep your reference ID to track its progress.'**
  String get repSubmittedBody;

  /// No description provided for @repReferenceId.
  ///
  /// In en, this message translates to:
  /// **'Reference ID'**
  String get repReferenceId;

  /// No description provided for @repViewReport.
  ///
  /// In en, this message translates to:
  /// **'View report'**
  String get repViewReport;

  /// No description provided for @repViewMyReports.
  ///
  /// In en, this message translates to:
  /// **'View my reports'**
  String get repViewMyReports;

  /// No description provided for @repBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get repBackHome;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navMyReports.
  ///
  /// In en, this message translates to:
  /// **'My Reports'**
  String get navMyReports;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navReportAnIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get navReportAnIssue;

  /// No description provided for @navDrawerMain.
  ///
  /// In en, this message translates to:
  /// **'MAIN'**
  String get navDrawerMain;

  /// No description provided for @navDrawerSupport.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get navDrawerSupport;

  /// No description provided for @navDrawerLegal.
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get navDrawerLegal;

  /// No description provided for @navDrawerSearchDiscover.
  ///
  /// In en, this message translates to:
  /// **'Search & Discover'**
  String get navDrawerSearchDiscover;

  /// No description provided for @navDrawerSavedReports.
  ///
  /// In en, this message translates to:
  /// **'Saved Reports'**
  String get navDrawerSavedReports;

  /// No description provided for @navDrawerReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get navDrawerReportIssue;

  /// No description provided for @navDrawerMapNearby.
  ///
  /// In en, this message translates to:
  /// **'Map & Nearby'**
  String get navDrawerMapNearby;

  /// No description provided for @navDrawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navDrawerSettings;

  /// No description provided for @navDrawerHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get navDrawerHelpSupport;

  /// No description provided for @navDrawerAbout.
  ///
  /// In en, this message translates to:
  /// **'About NAGARIK'**
  String get navDrawerAbout;

  /// No description provided for @navDrawerPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get navDrawerPrivacy;

  /// No description provided for @navDrawerTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get navDrawerTerms;

  /// No description provided for @navDrawerLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get navDrawerLogout;

  /// No description provided for @homeNearbyErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'Could not find civic issues near you.'**
  String get homeNearbyErrorFallback;

  /// No description provided for @homeMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get homeMenuTooltip;

  /// No description provided for @homeGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name} 👋'**
  String homeGreetingNamed(String name);

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello 👋'**
  String get homeGreeting;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Let\'s make our city better together'**
  String get homeTagline;

  /// No description provided for @homeNearbyIssues.
  ///
  /// In en, this message translates to:
  /// **'Nearby Issues'**
  String get homeNearbyIssues;

  /// No description provided for @homeRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetry;

  /// No description provided for @homeNearbyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been reported near you recently.'**
  String get homeNearbyEmpty;

  /// No description provided for @homeViewNearbyOnMap.
  ///
  /// In en, this message translates to:
  /// **'View Nearby Reports on Map'**
  String get homeViewNearbyOnMap;

  /// No description provided for @homeReportAnIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an Issue'**
  String get homeReportAnIssue;

  /// No description provided for @homeRecentReports.
  ///
  /// In en, this message translates to:
  /// **'Recent Reports'**
  String get homeRecentReports;

  /// No description provided for @homeRecentLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load recent reports. Pull down to try again.'**
  String get homeRecentLoadError;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeLocFinding.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get homeLocFinding;

  /// No description provided for @homeLocLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking for civic issues near you.'**
  String get homeLocLooking;

  /// No description provided for @homeLocAccess.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get homeLocAccess;

  /// No description provided for @homeLocEnablePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enable location to see issues near you.'**
  String get homeLocEnablePrompt;

  /// No description provided for @homeLocSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeLocSettings;

  /// No description provided for @homeLocEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get homeLocEnable;

  /// No description provided for @homeLocShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing issues near your current location.'**
  String get homeLocShowing;

  /// No description provided for @homeLocRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh location'**
  String get homeLocRefresh;

  /// No description provided for @searchKeywordHint.
  ///
  /// In en, this message translates to:
  /// **'Search by keyword, e.g. \"pothole\"'**
  String get searchKeywordHint;

  /// No description provided for @searchCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get searchCategory;

  /// No description provided for @searchAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchAll;

  /// No description provided for @searchStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get searchStatus;

  /// No description provided for @searchAnyStatus.
  ///
  /// In en, this message translates to:
  /// **'Any status'**
  String get searchAnyStatus;

  /// No description provided for @searchLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get searchLocation;

  /// No description provided for @searchNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near Me'**
  String get searchNearMe;

  /// No description provided for @searchCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get searchCity;

  /// No description provided for @searchPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get searchPinCode;

  /// No description provided for @searchSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSearchButton;

  /// No description provided for @searchViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get searchViewList;

  /// No description provided for @searchViewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get searchViewMap;

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilters;

  /// No description provided for @searchPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for civic reports'**
  String get searchPromptTitle;

  /// No description provided for @searchPromptMessage.
  ///
  /// In en, this message translates to:
  /// **'Find reports by keyword, category, status, city, PIN code, or near you.'**
  String get searchPromptMessage;

  /// No description provided for @searchError.
  ///
  /// In en, this message translates to:
  /// **'Could not search reports. Please try again.'**
  String get searchError;

  /// No description provided for @searchReportsFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 report found} other{{count} reports found}}'**
  String searchReportsFound(int count);

  /// No description provided for @searchLoadingMap.
  ///
  /// In en, this message translates to:
  /// **'Loading map…'**
  String get searchLoadingMap;

  /// No description provided for @searchMapError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the map. Please try again.'**
  String get searchMapError;

  /// No description provided for @searchMapEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching reports to show on the map'**
  String get searchMapEmptyTitle;

  /// No description provided for @searchMapEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different keyword or loosen your filters.'**
  String get searchMapEmptyMessage;

  /// No description provided for @listDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete report?'**
  String get listDeleteTitle;

  /// No description provided for @listDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the report and its photos.'**
  String get listDeleteMessage;

  /// No description provided for @listCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get listCancel;

  /// No description provided for @listDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get listDelete;

  /// No description provided for @listDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete the report.'**
  String get listDeleteError;

  /// No description provided for @listMyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your reports. Pull down to try again.'**
  String get listMyLoadError;

  /// No description provided for @listNoMatchingReports.
  ///
  /// In en, this message translates to:
  /// **'No matching reports'**
  String get listNoMatchingReports;

  /// No description provided for @listNoStatusReports.
  ///
  /// In en, this message translates to:
  /// **'No {status} reports'**
  String listNoStatusReports(String status);

  /// No description provided for @listTryDifferentFilter.
  ///
  /// In en, this message translates to:
  /// **'Try a different filter above.'**
  String get listTryDifferentFilter;

  /// No description provided for @listReportOptions.
  ///
  /// In en, this message translates to:
  /// **'Report options'**
  String get listReportOptions;

  /// No description provided for @listEditReport.
  ///
  /// In en, this message translates to:
  /// **'Edit Report'**
  String get listEditReport;

  /// No description provided for @listDeleteReport.
  ///
  /// In en, this message translates to:
  /// **'Delete Report'**
  String get listDeleteReport;

  /// No description provided for @listSavedLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved reports. Pull down to try again.'**
  String get listSavedLoadError;

  /// No description provided for @detailTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Details'**
  String get detailTitle;

  /// No description provided for @detailShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get detailShare;

  /// No description provided for @detailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading report…'**
  String get detailLoading;

  /// No description provided for @detailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this report. It may have been removed.'**
  String get detailLoadError;

  /// No description provided for @detailUnsaveReport.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved reports'**
  String get detailUnsaveReport;

  /// No description provided for @detailSaveReport.
  ///
  /// In en, this message translates to:
  /// **'Save report'**
  String get detailSaveReport;

  /// No description provided for @detailCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get detailCity;

  /// No description provided for @detailPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get detailPinCode;

  /// No description provided for @detailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get detailLocation;

  /// No description provided for @detailCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get detailCreated;

  /// No description provided for @detailUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get detailUpdated;

  /// No description provided for @detailStatusTimeline.
  ///
  /// In en, this message translates to:
  /// **'Status timeline'**
  String get detailStatusTimeline;

  /// No description provided for @profTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profTitle;

  /// No description provided for @profNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'You\'re not logged in'**
  String get profNotLoggedIn;

  /// No description provided for @profLoginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to submit reports and track their status.'**
  String get profLoginPrompt;

  /// No description provided for @profLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get profLogIn;

  /// No description provided for @profCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get profCreateAccount;

  /// No description provided for @profLoadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get profLoadingProfile;

  /// No description provided for @profLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile. Please try again.'**
  String get profLoadError;

  /// No description provided for @profMyActivity.
  ///
  /// In en, this message translates to:
  /// **'My Activity'**
  String get profMyActivity;

  /// No description provided for @profSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profSettings;

  /// No description provided for @profEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profEditProfile;

  /// No description provided for @profPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get profPreferences;

  /// No description provided for @profAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profAccount;

  /// No description provided for @profStatsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your report stats.'**
  String get profStatsLoadError;

  /// No description provided for @profStatTotalReports.
  ///
  /// In en, this message translates to:
  /// **'Total\nReports'**
  String get profStatTotalReports;

  /// No description provided for @profStatResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get profStatResolved;

  /// No description provided for @profStatInReview.
  ///
  /// In en, this message translates to:
  /// **'In Review'**
  String get profStatInReview;

  /// No description provided for @profStatSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get profStatSubmitted;

  /// No description provided for @profMyReports.
  ///
  /// In en, this message translates to:
  /// **'My Reports'**
  String get profMyReports;

  /// No description provided for @profSavedReports.
  ///
  /// In en, this message translates to:
  /// **'Saved Reports'**
  String get profSavedReports;

  /// No description provided for @profOpenProfile.
  ///
  /// In en, this message translates to:
  /// **'Open profile'**
  String get profOpenProfile;

  /// No description provided for @profProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated.'**
  String get profProfileUpdated;

  /// No description provided for @profUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile. Please try again.'**
  String get profUpdateError;

  /// No description provided for @profTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get profTakePhoto;

  /// No description provided for @profChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get profChooseFromGallery;

  /// No description provided for @profRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get profRemovePhoto;

  /// No description provided for @profCameraError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera. Please try again.'**
  String get profCameraError;

  /// No description provided for @profLibraryError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the photo library. Please try again.'**
  String get profLibraryError;

  /// No description provided for @profPhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile photo updated.'**
  String get profPhotoUpdated;

  /// No description provided for @profPhotoUploadError.
  ///
  /// In en, this message translates to:
  /// **'Could not upload your photo. Please try again.'**
  String get profPhotoUploadError;

  /// No description provided for @profPhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Profile photo removed.'**
  String get profPhotoRemoved;

  /// No description provided for @profPhotoRemoveError.
  ///
  /// In en, this message translates to:
  /// **'Could not remove your photo. Please try again.'**
  String get profPhotoRemoveError;

  /// No description provided for @profFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profFullName;

  /// No description provided for @profFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Full name is required.'**
  String get profFullNameRequired;

  /// No description provided for @profFullNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Full name is too short.'**
  String get profFullNameTooShort;

  /// No description provided for @profMobileOptional.
  ///
  /// In en, this message translates to:
  /// **'Mobile number (optional)'**
  String get profMobileOptional;

  /// No description provided for @profMobileInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number.'**
  String get profMobileInvalid;

  /// No description provided for @profEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profEmail;

  /// No description provided for @profEmailReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Your registered email cannot be changed here.'**
  String get profEmailReadOnly;

  /// No description provided for @profSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profSaveChanges;

  /// No description provided for @setTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setTitle;

  /// No description provided for @setAccountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get setAccountInformation;

  /// No description provided for @setAccountLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account information.'**
  String get setAccountLoadError;

  /// No description provided for @setMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get setMobileNumber;

  /// No description provided for @setThemePreference.
  ///
  /// In en, this message translates to:
  /// **'Theme preference'**
  String get setThemePreference;

  /// No description provided for @setThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get setThemeSystem;

  /// No description provided for @setThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get setThemeLight;

  /// No description provided for @setThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get setThemeDark;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get setHelpSupport;

  /// No description provided for @setHelpSubmitQ.
  ///
  /// In en, this message translates to:
  /// **'How do I submit a report?'**
  String get setHelpSubmitQ;

  /// No description provided for @setHelpSubmitA.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Report Issue\" from any tab, choose a category, add a description, confirm your location and city/PIN code, and optionally attach photos.'**
  String get setHelpSubmitA;

  /// No description provided for @setHelpStatusQ.
  ///
  /// In en, this message translates to:
  /// **'How do I check a report status?'**
  String get setHelpStatusQ;

  /// No description provided for @setHelpStatusA.
  ///
  /// In en, this message translates to:
  /// **'Open Profile -> My Reports to see every report you have submitted along with its current status: Submitted, In Review, or Resolved.'**
  String get setHelpStatusA;

  /// No description provided for @setHelpNameQ.
  ///
  /// In en, this message translates to:
  /// **'How do I change my name?'**
  String get setHelpNameQ;

  /// No description provided for @setHelpNameA.
  ///
  /// In en, this message translates to:
  /// **'Open Profile -> Edit Profile.'**
  String get setHelpNameA;

  /// No description provided for @setHelpMoreQ.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get setHelpMoreQ;

  /// No description provided for @setHelpMoreA.
  ///
  /// In en, this message translates to:
  /// **'Reach us at support@nagarik.example.'**
  String get setHelpMoreA;

  /// No description provided for @legalSection.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalSection;

  /// No description provided for @legalPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacyPolicy;

  /// No description provided for @legalTermsConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get legalTermsConditions;

  /// No description provided for @legalAboutNagarik.
  ///
  /// In en, this message translates to:
  /// **'About NAGARIK'**
  String get legalAboutNagarik;

  /// No description provided for @legalAboutHeading.
  ///
  /// In en, this message translates to:
  /// **'NAGARIK — A Civic Good Initiative'**
  String get legalAboutHeading;

  /// No description provided for @legalAboutBody.
  ///
  /// In en, this message translates to:
  /// **'NAGARIK gives citizens a simple way to report civic issues — potholes, broken streetlights, sanitation problems, water and electricity faults, safety hazards, and more — and to track each report from Submitted through In Review to Resolved.'**
  String get legalAboutBody;

  /// No description provided for @legalAboutHowHeading.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get legalAboutHowHeading;

  /// No description provided for @legalAboutHowBody.
  ///
  /// In en, this message translates to:
  /// **'Report an issue with a description, category, location, and photos. Browse and search reports from your city or nearby. Follow the status of your own reports from your Profile.'**
  String get legalAboutHowBody;

  /// No description provided for @legalVersionHeading.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get legalVersionHeading;

  /// No description provided for @legalVersionBody.
  ///
  /// In en, this message translates to:
  /// **'NAGARIK 0.1.0'**
  String get legalVersionBody;

  /// No description provided for @legalPrivacyIntro.
  ///
  /// In en, this message translates to:
  /// **'This is placeholder text describing how NAGARIK handles your information. Replace it with your reviewed privacy policy before a real release.'**
  String get legalPrivacyIntro;

  /// No description provided for @legalPrivacyCollectHeading.
  ///
  /// In en, this message translates to:
  /// **'What we collect'**
  String get legalPrivacyCollectHeading;

  /// No description provided for @legalPrivacyCollectBody.
  ///
  /// In en, this message translates to:
  /// **'Your name and email address (when you create an account), and the reports you submit — a category, description, city and PIN code, optional photos, and location coordinates when you choose to attach one.'**
  String get legalPrivacyCollectBody;

  /// No description provided for @legalPrivacyUseHeading.
  ///
  /// In en, this message translates to:
  /// **'How we use it'**
  String get legalPrivacyUseHeading;

  /// No description provided for @legalPrivacyUseBody.
  ///
  /// In en, this message translates to:
  /// **'To show your submitted reports back to you, to let other citizens browse and search civic issues in their area, and to track the status of a report as it moves from Submitted to In Review to Resolved.'**
  String get legalPrivacyUseBody;

  /// No description provided for @legalPrivacyStoredHeading.
  ///
  /// In en, this message translates to:
  /// **'Where it is stored'**
  String get legalPrivacyStoredHeading;

  /// No description provided for @legalPrivacyStoredBody.
  ///
  /// In en, this message translates to:
  /// **'Account and report data is stored with Supabase; photos are stored in a private file bucket and are never publicly browsable by their raw address.'**
  String get legalPrivacyStoredBody;

  /// No description provided for @legalPrivacySharingHeading.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get legalPrivacySharingHeading;

  /// No description provided for @legalPrivacySharingBody.
  ///
  /// In en, this message translates to:
  /// **'We do not sell your personal information to third parties.'**
  String get legalPrivacySharingBody;

  /// No description provided for @legalContactHeading.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get legalContactHeading;

  /// No description provided for @legalPrivacyContactBody.
  ///
  /// In en, this message translates to:
  /// **'Questions about this policy can be sent to privacy@nagarik.example.'**
  String get legalPrivacyContactBody;

  /// No description provided for @legalTermsIntro.
  ///
  /// In en, this message translates to:
  /// **'This is placeholder text. Replace it with your reviewed terms of use before a real release.'**
  String get legalTermsIntro;

  /// No description provided for @legalTermsUsingHeading.
  ///
  /// In en, this message translates to:
  /// **'Using NAGARIK'**
  String get legalTermsUsingHeading;

  /// No description provided for @legalTermsUsingBody.
  ///
  /// In en, this message translates to:
  /// **'NAGARIK is a civic issue reporting app. Reports you submit should be accurate and made in good faith — NAGARIK is not the right place for spam, harassment, or reports about private individuals rather than civic infrastructure or services.'**
  String get legalTermsUsingBody;

  /// No description provided for @legalTermsAccountHeading.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get legalTermsAccountHeading;

  /// No description provided for @legalTermsAccountBody.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for the reports submitted under your account. We may suspend or remove an account that misuses the app.'**
  String get legalTermsAccountBody;

  /// No description provided for @legalTermsNoGuaranteeHeading.
  ///
  /// In en, this message translates to:
  /// **'No guaranteed resolution'**
  String get legalTermsNoGuaranteeHeading;

  /// No description provided for @legalTermsNoGuaranteeBody.
  ///
  /// In en, this message translates to:
  /// **'Submitting a report shares it with other citizens and (where applicable) the relevant authority, but NAGARIK does not guarantee any particular resolution time or outcome for a reported issue.'**
  String get legalTermsNoGuaranteeBody;

  /// No description provided for @legalTermsChangesHeading.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get legalTermsChangesHeading;

  /// No description provided for @legalTermsChangesBody.
  ///
  /// In en, this message translates to:
  /// **'These terms may be updated from time to time; continuing to use the app after a change means you accept the updated terms.'**
  String get legalTermsChangesBody;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get commonLogout;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search civic issues, locations…'**
  String get commonSearchHint;

  /// No description provided for @commonNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach NAGARIK. Check your internet connection and try again.'**
  String get commonNetworkError;

  /// No description provided for @commonGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonGenericError;

  /// No description provided for @commonEmptyNoReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get commonEmptyNoReportsTitle;

  /// No description provided for @commonEmptyNoReportsMessage.
  ///
  /// In en, this message translates to:
  /// **'Reports submitted here will show up in this list.'**
  String get commonEmptyNoReportsMessage;

  /// No description provided for @commonEmptyNoSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved reports yet'**
  String get commonEmptyNoSavedTitle;

  /// No description provided for @commonEmptyNoSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark icon on a report to save it here for later.'**
  String get commonEmptyNoSavedMessage;

  /// No description provided for @commonEmptyNoNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'No civic issues nearby'**
  String get commonEmptyNoNearbyTitle;

  /// No description provided for @commonEmptyNoNearbyMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been reported near you recently.'**
  String get commonEmptyNoNearbyMessage;

  /// No description provided for @commonEmptyNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching reports'**
  String get commonEmptyNoMatchTitle;

  /// No description provided for @commonEmptyNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different keyword or loosen your filters.'**
  String get commonEmptyNoMatchMessage;
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
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

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
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
