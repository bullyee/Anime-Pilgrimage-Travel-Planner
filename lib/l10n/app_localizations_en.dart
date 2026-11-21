// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trip Planner';

  @override
  String get navHome => 'Home';

  @override
  String get navTrips => 'Trips';

  @override
  String get navLibrary => 'Library';

  @override
  String get navPhotos => 'Photos';

  @override
  String get navShoot => 'Shoot';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonDelete => 'Delete';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionData => 'Your data';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageSystemSubtitle =>
      'Follows your device language; defaults to English for unsupported languages.';

  @override
  String get settingsLanguageDialogTitle => 'Language';

  @override
  String settingsSignInFailed(String error) {
    return 'Couldn\'t sign in: $error';
  }

  @override
  String get settingsSignedOut => 'Signed out.';

  @override
  String settingsSignOutFailed(String error) {
    return 'Couldn\'t sign out: $error';
  }

  @override
  String get settingsNotSignedInTitle => 'Not signed in';

  @override
  String get settingsNotSignedInSubtitle =>
      'Signing in is only for sharing trips. Everything else works without an account.';

  @override
  String get settingsSignInButton => 'Sign in';

  @override
  String get settingsSignedInFallbackTitle => 'Signed in';

  @override
  String get settingsGoogleAccountSubtitle =>
      'Google account, for shared trips';

  @override
  String get settingsSignOutTitle => 'Sign out';

  @override
  String get settingsSignOutSubtitle =>
      'Shared trips sync only while you\'re signed in. Your library and private trips don\'t need it.';

  @override
  String get settingsFrameUploadQualityTitle => 'Frame upload quality';

  @override
  String get settingsDriveRemoveTitle =>
      'Remove shared frames from my Google Drive';

  @override
  String get settingsDriveRemoveSubtitle =>
      'Deletes every frame Trip Planner put in your Drive; anyone with a link loses it. People in your trips lose the frames they haven\'t downloaded.';

  @override
  String settingsDriveRemovalsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count removals are waiting, and will finish the next time Google Drive can be reached.',
      one:
          'One removal is waiting, and will finish the next time Google Drive can be reached.',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupTitle => 'Back up to a file';

  @override
  String get settingsBackupSubtitle =>
      'Your library with its photos and frames, and your private trips, in one file to keep or send to a new phone.';

  @override
  String get settingsRestoreTitle => 'Restore from a file';

  @override
  String get settingsRestoreSubtitle =>
      'Adds what\'s in a backup and isn\'t on this phone yet. Nothing here is changed.';

  @override
  String get settingsYourDataTitle => 'Your places, trips, photos and frames';

  @override
  String get settingsMapTilesTitle => 'Map tiles';

  @override
  String settingsMapTilesSubtitle(String size) {
    return 'The maps you looked at in the last 14 days, kept for using offline.\n$size';
  }

  @override
  String get settingsCutoutModelTitle => 'Cutout model';

  @override
  String settingsCutoutModelSubtitle(String size) {
    return 'For Cut out character, downloaded the first time.\n$size';
  }

  @override
  String get settingsStorageError => 'Couldn\'t measure';

  @override
  String get settingsStorageMeasuring => 'Measuring…';

  @override
  String get settingsSizeUnder1Mb => 'Under 1 MB';

  @override
  String get settingsSizeLessThan1Mb => 'less than 1 MB';

  @override
  String get settingsClearMapTilesDialogTitle => 'Clear map tiles?';

  @override
  String settingsClearMapTilesDialogBody(String size) {
    return 'Frees $size. Maps load their tiles again the next time you look at them, so they need a connection until then.';
  }

  @override
  String get settingsDeleteModelDialogTitle => 'Delete the cutout model?';

  @override
  String settingsDeleteModelDialogBody(String size) {
    return 'Frees $size. Cut out character downloads it again (about 176 MB) the next time you use it.';
  }

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsAboutAnitabiTitle => 'Spots and frames from Anitabi';

  @override
  String get settingsAboutAnitabiSubtitle =>
      'anitabi.cn, shared under CC BY-NC-SA 4.0: free to use, never sold.';

  @override
  String get settingsAboutOsmTitle => 'Maps from OpenStreetMap';

  @override
  String get settingsAboutOsmSubtitle => '© OpenStreetMap contributors';

  @override
  String get settingsAboutBangumiTitle => 'Anime search from Bangumi';

  @override
  String get settingsAboutBangumiSubtitle => 'bgm.tv';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsSourceCode => 'Source code and releases';

  @override
  String get settingsOpenSourceLicences => 'Open-source licences';

  @override
  String get placeTitleFallback => 'Place';

  @override
  String get placeGone => 'This place is no longer in the trip.';

  @override
  String placeSpotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots',
      one: '1 spot',
    );
    return '$_temp0';
  }

  @override
  String placeShotCount(int count) {
    return '$count shot';
  }

  @override
  String placeFilterAll(int count) {
    return 'All $count';
  }

  @override
  String placeFilterNotShot(int count) {
    return 'Not shot $count';
  }

  @override
  String get placeNearestFirst => 'Nearest first';

  @override
  String get placeAllShot => 'Every spot here is shot.';

  @override
  String get placeNoSpots => 'No spots.';

  @override
  String get placeSpotShot => 'Shot';

  @override
  String get placeSpotNotShot => 'Not shot';

  @override
  String placeFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames',
      one: '1 frame',
    );
    return '$_temp0';
  }

  @override
  String get placeFrameNotShotLabel => 'Frame, not shot. Shoot it';

  @override
  String get placeFrameShotLabel => 'Your photo of this frame';

  @override
  String get placeDetails => 'Details';
}
