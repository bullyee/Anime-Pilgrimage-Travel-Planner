import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

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
    Locale('ja'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// Application name shown in app switcher and About section.
  ///
  /// In en, this message translates to:
  /// **'Trip Planner'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get navPhotos;

  /// No description provided for @navShoot.
  ///
  /// In en, this message translates to:
  /// **'Shoot'**
  String get navShoot;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsSectionData;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follows your device language; defaults to English for unsupported languages.'**
  String get settingsLanguageSystemSubtitle;

  /// No description provided for @settingsLanguageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageDialogTitle;

  /// No description provided for @settingsSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in: {error}'**
  String settingsSignInFailed(String error);

  /// No description provided for @settingsSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get settingsSignedOut;

  /// No description provided for @settingsSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign out: {error}'**
  String settingsSignOutFailed(String error);

  /// No description provided for @settingsNotSignedInTitle.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get settingsNotSignedInTitle;

  /// No description provided for @settingsNotSignedInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Signing in is only for sharing trips. Everything else works without an account.'**
  String get settingsNotSignedInSubtitle;

  /// No description provided for @settingsSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsSignInButton;

  /// No description provided for @settingsSignedInFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsSignedInFallbackTitle;

  /// No description provided for @settingsGoogleAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Google account, for shared trips'**
  String get settingsGoogleAccountSubtitle;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shared trips sync only while you\'re signed in. Your library and private trips don\'t need it.'**
  String get settingsSignOutSubtitle;

  /// No description provided for @settingsFrameUploadQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Frame upload quality'**
  String get settingsFrameUploadQualityTitle;

  /// No description provided for @settingsDriveRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove shared frames from my Google Drive'**
  String get settingsDriveRemoveTitle;

  /// No description provided for @settingsDriveRemoveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes every frame Trip Planner put in your Drive; anyone with a link loses it. People in your trips lose the frames they haven\'t downloaded.'**
  String get settingsDriveRemoveSubtitle;

  /// No description provided for @settingsDriveRemovalsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One removal is waiting, and will finish the next time Google Drive can be reached.} other{{count} removals are waiting, and will finish the next time Google Drive can be reached.}}'**
  String settingsDriveRemovalsWaiting(int count);

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up to a file'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your library with its photos and frames, and your private trips, in one file to keep or send to a new phone.'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a file'**
  String get settingsRestoreTitle;

  /// No description provided for @settingsRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adds what\'s in a backup and isn\'t on this phone yet. Nothing here is changed.'**
  String get settingsRestoreSubtitle;

  /// No description provided for @settingsYourDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Your places, trips, photos and frames'**
  String get settingsYourDataTitle;

  /// No description provided for @settingsMapTilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Map tiles'**
  String get settingsMapTilesTitle;

  /// No description provided for @settingsMapTilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The maps you looked at in the last 14 days, kept for using offline.\n{size}'**
  String settingsMapTilesSubtitle(String size);

  /// No description provided for @settingsCutoutModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cutout model'**
  String get settingsCutoutModelTitle;

  /// No description provided for @settingsCutoutModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For Cut out character, downloaded the first time.\n{size}'**
  String settingsCutoutModelSubtitle(String size);

  /// No description provided for @settingsStorageError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t measure'**
  String get settingsStorageError;

  /// No description provided for @settingsStorageMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring…'**
  String get settingsStorageMeasuring;

  /// No description provided for @settingsSizeUnder1Mb.
  ///
  /// In en, this message translates to:
  /// **'Under 1 MB'**
  String get settingsSizeUnder1Mb;

  /// No description provided for @settingsSizeLessThan1Mb.
  ///
  /// In en, this message translates to:
  /// **'less than 1 MB'**
  String get settingsSizeLessThan1Mb;

  /// No description provided for @settingsClearMapTilesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear map tiles?'**
  String get settingsClearMapTilesDialogTitle;

  /// No description provided for @settingsClearMapTilesDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Frees {size}. Maps load their tiles again the next time you look at them, so they need a connection until then.'**
  String settingsClearMapTilesDialogBody(String size);

  /// No description provided for @settingsDeleteModelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the cutout model?'**
  String get settingsDeleteModelDialogTitle;

  /// No description provided for @settingsDeleteModelDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Frees {size}. Cut out character downloads it again (about 176 MB) the next time you use it.'**
  String settingsDeleteModelDialogBody(String size);

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsAboutAnitabiTitle.
  ///
  /// In en, this message translates to:
  /// **'Spots and frames from Anitabi'**
  String get settingsAboutAnitabiTitle;

  /// No description provided for @settingsAboutAnitabiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'anitabi.cn, shared under CC BY-NC-SA 4.0: free to use, never sold.'**
  String get settingsAboutAnitabiSubtitle;

  /// No description provided for @settingsAboutOsmTitle.
  ///
  /// In en, this message translates to:
  /// **'Maps from OpenStreetMap'**
  String get settingsAboutOsmTitle;

  /// No description provided for @settingsAboutOsmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get settingsAboutOsmSubtitle;

  /// No description provided for @settingsAboutBangumiTitle.
  ///
  /// In en, this message translates to:
  /// **'Anime search from Bangumi'**
  String get settingsAboutBangumiTitle;

  /// No description provided for @settingsAboutBangumiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'bgm.tv'**
  String get settingsAboutBangumiSubtitle;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code and releases'**
  String get settingsSourceCode;

  /// No description provided for @settingsOpenSourceLicences.
  ///
  /// In en, this message translates to:
  /// **'Open-source licences'**
  String get settingsOpenSourceLicences;

  /// Title of a trip's place page while its name is unknown.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeTitleFallback;

  /// No description provided for @placeGone.
  ///
  /// In en, this message translates to:
  /// **'This place is no longer in the trip.'**
  String get placeGone;

  /// How many spots (shot positions) a place has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 spot} other{{count} spots}}'**
  String placeSpotCount(int count);

  /// How many of a place's spots are shot, after the spot count.
  ///
  /// In en, this message translates to:
  /// **'{count} shot'**
  String placeShotCount(int count);

  /// No description provided for @placeFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String placeFilterAll(int count);

  /// No description provided for @placeFilterNotShot.
  ///
  /// In en, this message translates to:
  /// **'Not shot {count}'**
  String placeFilterNotShot(int count);

  /// No description provided for @placeNearestFirst.
  ///
  /// In en, this message translates to:
  /// **'Nearest first'**
  String get placeNearestFirst;

  /// No description provided for @placeAllShot.
  ///
  /// In en, this message translates to:
  /// **'Every spot here is shot.'**
  String get placeAllShot;

  /// No description provided for @placeNoSpots.
  ///
  /// In en, this message translates to:
  /// **'No spots.'**
  String get placeNoSpots;

  /// No description provided for @placeSpotShot.
  ///
  /// In en, this message translates to:
  /// **'Shot'**
  String get placeSpotShot;

  /// No description provided for @placeSpotNotShot.
  ///
  /// In en, this message translates to:
  /// **'Not shot'**
  String get placeSpotNotShot;

  /// No description provided for @placeFrameCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 frame} other{{count} frames}}'**
  String placeFrameCount(int count);

  /// No description provided for @placeFrameNotShotLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame, not shot. Shoot it'**
  String get placeFrameNotShotLabel;

  /// No description provided for @placeFrameShotLabel.
  ///
  /// In en, this message translates to:
  /// **'Your photo of this frame'**
  String get placeFrameShotLabel;

  /// No description provided for @placeDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get placeDetails;
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
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
