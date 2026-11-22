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

  /// How many of a place's frames are shot, after the counts.
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
  /// **'Everything here is shot.'**
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
  /// **'Frame, not shot'**
  String get placeFrameNotShotLabel;

  /// No description provided for @placeFrameShotLabel.
  ///
  /// In en, this message translates to:
  /// **'Your photo of this frame'**
  String get placeFrameShotLabel;

  /// No description provided for @placeDetails.
  ///
  /// In en, this message translates to:
  /// **'Stop details'**
  String get placeDetails;

  /// No description provided for @placeFoldBannerText.
  ///
  /// In en, this message translates to:
  /// **'A group of stops is one place now, its stops the spots inside it.'**
  String get placeFoldBannerText;

  /// No description provided for @placeFoldBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Turn into places'**
  String get placeFoldBannerAction;

  /// No description provided for @placeFoldConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn groups into places?'**
  String get placeFoldConfirmTitle;

  /// No description provided for @placeFoldConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Each group becomes one stop with the group\'s name. Its stops\' frames, days and labels move onto it, and each frame keeps where it was shot from. Everyone in the trip sees the change.'**
  String get placeFoldConfirmBody;

  /// No description provided for @placeFoldDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Made 1 place.} other{Made {count} places.}}'**
  String placeFoldDone(int count);

  /// No description provided for @placeFoldNeedsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to change a shared trip.'**
  String get placeFoldNeedsSignIn;

  /// No description provided for @placeFoldNeedsSync.
  ///
  /// In en, this message translates to:
  /// **'Some changes haven\'t synced yet. Try again once they have.'**
  String get placeFoldNeedsSync;

  /// No description provided for @placeFoldFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn the groups into places: {error}'**
  String placeFoldFailed(String error);

  /// No description provided for @placeFilterNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby {count}'**
  String placeFilterNearby(int count);

  /// No description provided for @placeNoneNearby.
  ///
  /// In en, this message translates to:
  /// **'No spots within 60 m.'**
  String get placeNoneNearby;

  /// No description provided for @placeEstimated.
  ///
  /// In en, this message translates to:
  /// **'Position estimated'**
  String get placeEstimated;

  /// No description provided for @placeSpotsHeading.
  ///
  /// In en, this message translates to:
  /// **'Spots'**
  String get placeSpotsHeading;

  /// No description provided for @placeSpotsHint.
  ///
  /// In en, this message translates to:
  /// **'Each spot is a place to shoot from, with the frames shot there.'**
  String get placeSpotsHint;

  /// No description provided for @placeNotesHeading.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get placeNotesHeading;

  /// No description provided for @placeNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Getting there, opening hours, when to shoot…'**
  String get placeNotesHint;

  /// No description provided for @placeOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get placeOpenInMaps;

  /// No description provided for @placeDistanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} away'**
  String placeDistanceAway(String distance);

  /// A compass point: n, ne, e, se, s, sw, w or nw.
  ///
  /// In en, this message translates to:
  /// **'{dir, select, n{N} ne{NE} e{E} se{SE} s{S} sw{SW} w{W} nw{NW} other{}}'**
  String placeCompass(String dir);

  /// Which way a spot is and how far, e.g. "NE 40 m".
  ///
  /// In en, this message translates to:
  /// **'{direction} {distance}'**
  String placeSpotWay(String direction, String distance);

  /// No description provided for @placeStartShooting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Start shooting · 1 not shot} other{Start shooting · {count} not shot}}'**
  String placeStartShooting(int count);

  /// No description provided for @placeSeePhotos.
  ///
  /// In en, this message translates to:
  /// **'Everything here is shot · See photos'**
  String get placeSeePhotos;

  /// No description provided for @placeNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {spot} · {distance}'**
  String placeNext(String spot, String distance);

  /// No description provided for @placeNextHere.
  ///
  /// In en, this message translates to:
  /// **'Next: {spot}'**
  String placeNextHere(String spot);

  /// No description provided for @placeShoot.
  ///
  /// In en, this message translates to:
  /// **'Shoot'**
  String get placeShoot;

  /// No description provided for @placeSpotNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (a spot has no name; its note tells it apart)'**
  String get placeSpotNoteLabel;

  /// No description provided for @placeSpotNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. north side of the 3rd pillar'**
  String get placeSpotNoteHint;

  /// No description provided for @placeSaveNote.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get placeSaveNote;

  /// No description provided for @placeSetPosition.
  ///
  /// In en, this message translates to:
  /// **'Set its position on the map'**
  String get placeSetPosition;

  /// No description provided for @placeSetPositionEstimated.
  ///
  /// In en, this message translates to:
  /// **'The position now is estimated'**
  String get placeSetPositionEstimated;

  /// No description provided for @placeShootSpot.
  ///
  /// In en, this message translates to:
  /// **'Shoot this spot'**
  String get placeShootSpot;

  /// No description provided for @placePlacing.
  ///
  /// In en, this message translates to:
  /// **'Drag the map to put the cross on where “{spot}” is shot from'**
  String placePlacing(String spot);

  /// No description provided for @placeSetHere.
  ///
  /// In en, this message translates to:
  /// **'Set here'**
  String get placeSetHere;

  /// No description provided for @placePositionSaved.
  ///
  /// In en, this message translates to:
  /// **'Position saved.'**
  String get placePositionSaved;

  /// No description provided for @placeSpotOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for “{spot}”'**
  String placeSpotOptions(String spot);

  /// No description provided for @placeMenu.
  ///
  /// In en, this message translates to:
  /// **'Place options'**
  String get placeMenu;

  /// No description provided for @placeDayUnsorted.
  ///
  /// In en, this message translates to:
  /// **'Unsorted'**
  String get placeDayUnsorted;

  /// No description provided for @placeDayN.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String placeDayN(int n);

  /// No description provided for @placeNoDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get placeNoDate;

  /// No description provided for @placeDayChip.
  ///
  /// In en, this message translates to:
  /// **'Day: {day}. Tap to move the place'**
  String placeDayChip(String day);

  /// No description provided for @placeMoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Where “{place}” goes'**
  String placeMoveTitle(String place);

  /// No description provided for @placeMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {day}.'**
  String placeMovedTo(String day);

  /// No description provided for @placeCountInDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place} other{{count} places}}'**
  String placeCountInDay(int count);

  /// No description provided for @placeMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge another place into this one'**
  String get placeMerge;

  /// No description provided for @placeMergePick.
  ///
  /// In en, this message translates to:
  /// **'Merge into “{place}”'**
  String placeMergePick(String place);

  /// No description provided for @placeMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Merge “{other}” into “{place}”?'**
  String placeMergeConfirm(String other, String place);

  /// No description provided for @placeMergeBody.
  ///
  /// In en, this message translates to:
  /// **'Its frames, labels and days come here, each frame keeping where it was shot from, and “{other}” leaves the trip, for everyone in it.'**
  String placeMergeBody(String other);

  /// No description provided for @placeMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get placeMergeAction;

  /// No description provided for @placeMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged “{other}” into this place.'**
  String placeMerged(String other);

  /// No description provided for @placeTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get placeTakePhoto;

  /// No description provided for @placeCompare.
  ///
  /// In en, this message translates to:
  /// **'See your photo'**
  String get placeCompare;

  /// No description provided for @placeFrameTitle.
  ///
  /// In en, this message translates to:
  /// **'Anime frame'**
  String get placeFrameTitle;

  /// No description provided for @placeNoFrames.
  ///
  /// In en, this message translates to:
  /// **'No frames yet'**
  String get placeNoFrames;

  /// No description provided for @placeSpotNoFrames.
  ///
  /// In en, this message translates to:
  /// **'No frames at this spot yet.'**
  String get placeSpotNoFrames;

  /// No description provided for @placeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get placeCancel;

  /// No description provided for @tripTabPlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get tripTabPlaces;

  /// No description provided for @tripTabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get tripTabMembers;

  /// No description provided for @tripSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get tripSchedule;

  /// No description provided for @placesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find places, spot notes or frames'**
  String get placesSearchHint;

  /// No description provided for @placesClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get placesClearSearch;

  /// No description provided for @placesSortNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get placesSortNearest;

  /// No description provided for @placesSortByDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get placesSortByDay;

  /// No description provided for @placesNearestHeading.
  ///
  /// In en, this message translates to:
  /// **'Nearest to you'**
  String get placesNearestHeading;

  /// No description provided for @placesToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get placesToday;

  /// No description provided for @placesTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today {date} · {day}'**
  String placesTodayTitle(String date, String day);

  /// No description provided for @placesTodayNearest.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place, nearest is “{place}” {distance}} other{{count} places, nearest is “{place}” {distance}}}'**
  String placesTodayNearest(int count, String place, String distance);

  /// No description provided for @placesTodayStart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place, start with “{place}”} other{{count} places, start with “{place}”}}'**
  String placesTodayStart(int count, String place);

  /// No description provided for @placesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”.'**
  String placesNoMatch(String query);

  /// No description provided for @placesEmptyDay.
  ///
  /// In en, this message translates to:
  /// **'No places yet. Open a place and tap its day to move it here.'**
  String get placesEmptyDay;

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No places in this trip yet.'**
  String get placesEmpty;

  /// No description provided for @placesNewDay.
  ///
  /// In en, this message translates to:
  /// **'+ New day / category'**
  String get placesNewDay;

  /// No description provided for @placesAddPlaces.
  ///
  /// In en, this message translates to:
  /// **'Add places'**
  String get placesAddPlaces;

  /// No description provided for @placesDayOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for “{day}”'**
  String placesDayOptions(String day);

  /// No description provided for @placesRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get placesRename;

  /// No description provided for @placesSetDate.
  ///
  /// In en, this message translates to:
  /// **'Add a date'**
  String get placesSetDate;

  /// No description provided for @placesChangeDate.
  ///
  /// In en, this message translates to:
  /// **'Change the date ({date})'**
  String placesChangeDate(String date);

  /// No description provided for @placesClearDate.
  ///
  /// In en, this message translates to:
  /// **'Remove the date'**
  String get placesClearDate;

  /// No description provided for @placesClearDateHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps just the name'**
  String get placesClearDateHint;

  /// No description provided for @placesReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get placesReorder;

  /// No description provided for @placesDeleteDay.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get placesDeleteDay;

  /// No description provided for @placesDeleteDayHint.
  ///
  /// In en, this message translates to:
  /// **'Its places move to Unsorted'**
  String get placesDeleteDayHint;

  /// No description provided for @placesDeleteDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{day}”?'**
  String placesDeleteDayTitle(String day);

  /// No description provided for @placesDeleteDayBody.
  ///
  /// In en, this message translates to:
  /// **'Its places aren\'t deleted; they move to Unsorted.'**
  String get placesDeleteDayBody;

  /// No description provided for @placesDayName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get placesDayName;

  /// No description provided for @placesDayNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nishinomiya, Next time'**
  String get placesDayNameHint;

  /// No description provided for @placesNewDayTitle.
  ///
  /// In en, this message translates to:
  /// **'New day / category'**
  String get placesNewDayTitle;

  /// No description provided for @placesRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename the day'**
  String get placesRenameTitle;

  /// No description provided for @placesWithDate.
  ///
  /// In en, this message translates to:
  /// **'Add a date (optional)'**
  String get placesWithDate;

  /// No description provided for @placesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get placesCreate;

  /// No description provided for @placesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get placesSave;

  /// No description provided for @placesMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get placesMoveUp;

  /// No description provided for @placesMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get placesMoveDown;

  /// No description provided for @placesMatchName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get placesMatchName;

  /// No description provided for @placesMatchSpots.
  ///
  /// In en, this message translates to:
  /// **'Spots: {notes}'**
  String placesMatchSpots(String notes);

  /// No description provided for @placesMatchFrames.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 frame: {names}} other{{count} frames: {names}}}'**
  String placesMatchFrames(int count, String names);

  /// No description provided for @placesDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get placesDone;

  /// No description provided for @placesAddFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'From my library'**
  String get placesAddFromLibrary;

  /// No description provided for @placesAddFromLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Places you have saved'**
  String get placesAddFromLibraryHint;

  /// No description provided for @placesAddNewSpot.
  ///
  /// In en, this message translates to:
  /// **'New spot'**
  String get placesAddNewSpot;

  /// No description provided for @placesAddNewSpotHint.
  ///
  /// In en, this message translates to:
  /// **'Pick it on the map'**
  String get placesAddNewSpotHint;

  /// No description provided for @placesShowAs.
  ///
  /// In en, this message translates to:
  /// **'Show as'**
  String get placesShowAs;

  /// No description provided for @placesViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get placesViewList;

  /// No description provided for @placesViewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get placesViewMap;

  /// No description provided for @mapAllDays.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mapAllDays;

  /// No description provided for @mapDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get mapDays;

  /// No description provided for @mapYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get mapYourLocation;

  /// No description provided for @mapOpenPlace.
  ///
  /// In en, this message translates to:
  /// **'Open place'**
  String get mapOpenPlace;

  /// No description provided for @mapShootHere.
  ///
  /// In en, this message translates to:
  /// **'Shoot here'**
  String get mapShootHere;

  /// No description provided for @mapClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get mapClose;

  /// No description provided for @mapPlaceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 place} other{{count} places}}'**
  String mapPlaceCount(int count);

  /// No description provided for @mapCrowded.
  ///
  /// In en, this message translates to:
  /// **'Too crowded here; pick one'**
  String get mapCrowded;

  /// No description provided for @mapNoPlaces.
  ///
  /// In en, this message translates to:
  /// **'No places here yet'**
  String get mapNoPlaces;

  /// No description provided for @placePickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get placePickFromGallery;

  /// No description provided for @placePickEmpty.
  ///
  /// In en, this message translates to:
  /// **'That photo can\'t be opened, so it can\'t be used'**
  String get placePickEmpty;

  /// No description provided for @placePickedSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved as your photo of this frame'**
  String get placePickedSaved;

  /// No description provided for @placePickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the photo: {error}'**
  String placePickFailed(String error);

  /// No description provided for @photosFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get photosFilterAll;

  /// No description provided for @photosFilterToEdit.
  ///
  /// In en, this message translates to:
  /// **'To edit'**
  String get photosFilterToEdit;

  /// No description provided for @photosFilterToEditCount.
  ///
  /// In en, this message translates to:
  /// **'To edit · {count}'**
  String photosFilterToEditCount(int count);

  /// No description provided for @photosFilterPairs.
  ///
  /// In en, this message translates to:
  /// **'Pairs'**
  String get photosFilterPairs;

  /// No description provided for @photosEditFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Edit a photo from the gallery'**
  String get photosEditFromGallery;

  /// No description provided for @photosGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get photosGroupBy;

  /// No description provided for @photosByDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get photosByDay;

  /// No description provided for @photosByPlace.
  ///
  /// In en, this message translates to:
  /// **'By place'**
  String get photosByPlace;

  /// No description provided for @photosLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the photos: {error}'**
  String photosLoadFailed(String error);

  /// No description provided for @photosEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get photosEmptyTitle;

  /// No description provided for @photosEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The photos you take with Shoot, or from a place or a stop, show up here.'**
  String get photosEmptyBody;

  /// No description provided for @photosPairsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Photos you shoot against a frame show here under it. Open a place and start shooting, or pick one from the gallery on a frame.'**
  String get photosPairsEmpty;

  /// No description provided for @photosPlaceGone.
  ///
  /// In en, this message translates to:
  /// **'A place no longer in your library'**
  String get photosPlaceGone;

  /// No description provided for @photosShareImage.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get photosShareImage;

  /// No description provided for @photosShareMax.
  ///
  /// In en, this message translates to:
  /// **'Up to {max} pairs'**
  String photosShareMax(int max);

  /// No description provided for @photosShareMake.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Pick a few pairs} =1{Make an image with 1 pair} other{Make an image with {count} pairs}}'**
  String photosShareMake(int count);

  /// No description provided for @shareImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Share image'**
  String get shareImageTitle;

  /// No description provided for @shareImagePairs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pair} other{{count} pairs}}'**
  String shareImagePairs(int count);

  /// No description provided for @shareImageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pair} other{{count} pairs}} · frame / my photo'**
  String shareImageSubtitle(int count);

  /// No description provided for @shareImageTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get shareImageTitleField;

  /// No description provided for @shareImageGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get shareImageGrid;

  /// No description provided for @shareImageStacked.
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get shareImageStacked;

  /// No description provided for @shareImageSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shareImageSave;

  /// No description provided for @shareImageShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareImageShare;

  /// No description provided for @shareImageDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'My pilgrimage'**
  String get shareImageDefaultTitle;

  /// No description provided for @shareImageNothing.
  ///
  /// In en, this message translates to:
  /// **'None of these photos or frames could be read.'**
  String get shareImageNothing;

  /// No description provided for @shareImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the image: {error}'**
  String shareImageFailed(String error);
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
