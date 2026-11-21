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
  String get placeAllShot => 'Everything here is shot.';

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
  String get placeFrameNotShotLabel => 'Frame, not shot';

  @override
  String get placeFrameShotLabel => 'Your photo of this frame';

  @override
  String get placeDetails => 'Stop details';

  @override
  String get placeFoldBannerText =>
      'A group of stops is one place now, its stops the spots inside it.';

  @override
  String get placeFoldBannerAction => 'Turn into places';

  @override
  String get placeFoldConfirmTitle => 'Turn groups into places?';

  @override
  String get placeFoldConfirmBody =>
      'Each group becomes one stop with the group\'s name. Its stops\' frames, days and labels move onto it, and each frame keeps where it was shot from. Everyone in the trip sees the change.';

  @override
  String placeFoldDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Made $count places.',
      one: 'Made 1 place.',
    );
    return '$_temp0';
  }

  @override
  String get placeFoldNeedsSignIn => 'Sign in to change a shared trip.';

  @override
  String get placeFoldNeedsSync =>
      'Some changes haven\'t synced yet. Try again once they have.';

  @override
  String placeFoldFailed(String error) {
    return 'Couldn\'t turn the groups into places: $error';
  }

  @override
  String placeFilterNearby(int count) {
    return 'Nearby $count';
  }

  @override
  String get placeNoneNearby => 'No spots within 60 m.';

  @override
  String get placeEstimated => 'Position estimated';

  @override
  String get placeSpotsHeading => 'Spots';

  @override
  String get placeSpotsHint =>
      'Each spot is a place to shoot from, with the frames shot there.';

  @override
  String get placeNotesHeading => 'Notes';

  @override
  String get placeNotesHint => 'Getting there, opening hours, when to shoot…';

  @override
  String get placeOpenInMaps => 'Open in Google Maps';

  @override
  String placeDistanceAway(String distance) {
    return '$distance away';
  }

  @override
  String placeCompass(String dir) {
    String _temp0 = intl.Intl.selectLogic(dir, {
      'n': 'N',
      'ne': 'NE',
      'e': 'E',
      'se': 'SE',
      's': 'S',
      'sw': 'SW',
      'w': 'W',
      'nw': 'NW',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String placeSpotWay(String direction, String distance) {
    return '$direction $distance';
  }

  @override
  String placeStartShooting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Start shooting · $count not shot',
      one: 'Start shooting · 1 not shot',
    );
    return '$_temp0';
  }

  @override
  String get placeSeePhotos => 'Everything here is shot · See photos';

  @override
  String placeNext(String spot, String distance) {
    return 'Next: $spot · $distance';
  }

  @override
  String placeNextHere(String spot) {
    return 'Next: $spot';
  }

  @override
  String get placeShoot => 'Shoot';

  @override
  String get placeSpotNoteLabel =>
      'Note (a spot has no name; its note tells it apart)';

  @override
  String get placeSpotNoteHint => 'e.g. north side of the 3rd pillar';

  @override
  String get placeSaveNote => 'Save note';

  @override
  String get placeSetPosition => 'Set its position on the map';

  @override
  String get placeSetPositionEstimated => 'The position now is estimated';

  @override
  String get placeShootSpot => 'Shoot this spot';

  @override
  String placePlacing(String spot) {
    return 'Drag the map to put the cross on where “$spot” is shot from';
  }

  @override
  String get placeSetHere => 'Set here';

  @override
  String get placePositionSaved => 'Position saved.';

  @override
  String placeSpotOptions(String spot) {
    return 'Options for “$spot”';
  }

  @override
  String get placeMenu => 'Place options';

  @override
  String get placeDayUnsorted => 'Unsorted';

  @override
  String placeDayN(int n) {
    return 'Day $n';
  }

  @override
  String get placeNoDate => 'No date';

  @override
  String placeDayChip(String day) {
    return 'Day: $day. Tap to move the place';
  }

  @override
  String placeMoveTitle(String place) {
    return 'Where “$place” goes';
  }

  @override
  String placeMovedTo(String day) {
    return 'Moved to $day.';
  }

  @override
  String placeCountInDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String get placeMerge => 'Merge another place into this one';

  @override
  String placeMergePick(String place) {
    return 'Merge into “$place”';
  }

  @override
  String placeMergeConfirm(String other, String place) {
    return 'Merge “$other” into “$place”?';
  }

  @override
  String placeMergeBody(String other) {
    return 'Its frames, labels and days come here, each frame keeping where it was shot from, and “$other” leaves the trip, for everyone in it.';
  }

  @override
  String get placeMergeAction => 'Merge';

  @override
  String placeMerged(String other) {
    return 'Merged “$other” into this place.';
  }

  @override
  String get placeTakePhoto => 'Take photo';

  @override
  String get placeCompare => 'See your photo';

  @override
  String get placeFrameTitle => 'Anime frame';

  @override
  String get placeNoFrames => 'No frames yet';

  @override
  String get placeSpotNoFrames => 'No frames at this spot yet.';

  @override
  String get placeCancel => 'Cancel';

  @override
  String get tripTabPlaces => 'Places';

  @override
  String get tripTabMembers => 'Members';

  @override
  String get tripSchedule => 'Schedule';

  @override
  String get placesSearchHint => 'Find places, spot notes or frames';

  @override
  String get placesClearSearch => 'Clear search';

  @override
  String get placesSortNearest => 'Nearest';

  @override
  String get placesSortByDay => 'By day';

  @override
  String get placesNearestHeading => 'Nearest to you';

  @override
  String get placesToday => 'Today';

  @override
  String placesTodayTitle(String date, String day) {
    return 'Today $date · $day';
  }

  @override
  String placesTodayNearest(int count, String place, String distance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places, nearest is “$place” $distance',
      one: '1 place, nearest is “$place” $distance',
    );
    return '$_temp0';
  }

  @override
  String placesTodayStart(int count, String place) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places, start with “$place”',
      one: '1 place, start with “$place”',
    );
    return '$_temp0';
  }

  @override
  String placesNoMatch(String query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String get placesEmptyDay =>
      'No places yet. Open a place and tap its day to move it here.';

  @override
  String get placesEmpty => 'No places in this trip yet.';

  @override
  String get placesNewDay => '+ New day / category';

  @override
  String get placesAddPlaces => 'Add places';

  @override
  String placesDayOptions(String day) {
    return 'Options for “$day”';
  }

  @override
  String get placesRename => 'Rename';

  @override
  String get placesSetDate => 'Add a date';

  @override
  String placesChangeDate(String date) {
    return 'Change the date ($date)';
  }

  @override
  String get placesClearDate => 'Remove the date';

  @override
  String get placesClearDateHint => 'Keeps just the name';

  @override
  String get placesReorder => 'Reorder';

  @override
  String get placesDeleteDay => 'Delete';

  @override
  String get placesDeleteDayHint => 'Its places move to Unsorted';

  @override
  String placesDeleteDayTitle(String day) {
    return 'Delete “$day”?';
  }

  @override
  String get placesDeleteDayBody =>
      'Its places aren\'t deleted; they move to Unsorted.';

  @override
  String get placesDayName => 'Name';

  @override
  String get placesDayNameHint => 'e.g. Nishinomiya, Next time';

  @override
  String get placesNewDayTitle => 'New day / category';

  @override
  String get placesRenameTitle => 'Rename the day';

  @override
  String get placesWithDate => 'Add a date (optional)';

  @override
  String get placesCreate => 'Create';

  @override
  String get placesSave => 'Save';

  @override
  String get placesMoveUp => 'Move up';

  @override
  String get placesMoveDown => 'Move down';

  @override
  String get placesMatchName => 'Place name';

  @override
  String placesMatchSpots(String notes) {
    return 'Spots: $notes';
  }

  @override
  String placesMatchFrames(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count frames: $names',
      one: '1 frame: $names',
    );
    return '$_temp0';
  }

  @override
  String get placesDone => 'Done';

  @override
  String get placesAddFromLibrary => 'From my library';

  @override
  String get placesAddFromLibraryHint => 'Places you have saved';

  @override
  String get placesAddNewSpot => 'New spot';

  @override
  String get placesAddNewSpotHint => 'Pick it on the map';

  @override
  String get placesShowAs => 'Show as';

  @override
  String get placesViewList => 'List';

  @override
  String get placesViewMap => 'Map';

  @override
  String get mapAllDays => 'All';

  @override
  String get mapDays => 'Days';

  @override
  String get mapYourLocation => 'Your location';

  @override
  String get mapOpenPlace => 'Open place';

  @override
  String get mapShootHere => 'Shoot here';

  @override
  String get mapClose => 'Close';

  @override
  String mapPlaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String get mapCrowded => 'Too crowded here; pick one';

  @override
  String get mapNoPlaces => 'No places here yet';

  @override
  String get placePickFromGallery => 'Pick from gallery';

  @override
  String get placePickedSaved => 'Saved as your photo of this frame';

  @override
  String placePickFailed(String error) {
    return 'Couldn\'t add the photo: $error';
  }
}
