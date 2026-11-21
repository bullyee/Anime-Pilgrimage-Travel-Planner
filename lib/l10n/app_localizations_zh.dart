// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '聖地巡禮行程規劃';

  @override
  String get navHome => '首頁';

  @override
  String get navTrips => '行程';

  @override
  String get navLibrary => '景點庫';

  @override
  String get navPhotos => '相片';

  @override
  String get navShoot => '拍攝';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDone => '完成';

  @override
  String get commonClear => '清除';

  @override
  String get commonDelete => '刪除';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionApp => '應用程式';

  @override
  String get settingsSectionAccount => '帳號';

  @override
  String get settingsSectionData => '你的資料';

  @override
  String get settingsSectionAbout => '關於';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get settingsLanguageSystemSubtitle => '跟隨裝置語言設定；未支援的語言預設顯示英文。';

  @override
  String get settingsLanguageDialogTitle => '選擇語言';

  @override
  String settingsSignInFailed(String error) {
    return '無法登入：$error';
  }

  @override
  String get settingsSignedOut => '已登出。';

  @override
  String settingsSignOutFailed(String error) {
    return '無法登出：$error';
  }

  @override
  String get settingsNotSignedInTitle => '尚未登入';

  @override
  String get settingsNotSignedInSubtitle => '只有共享行程需要登入；其餘功能無需帳號即可使用。';

  @override
  String get settingsSignInButton => '登入';

  @override
  String get settingsSignedInFallbackTitle => '已登入';

  @override
  String get settingsGoogleAccountSubtitle => 'Google 帳號，用於共享行程';

  @override
  String get settingsSignOutTitle => '登出';

  @override
  String get settingsSignOutSubtitle => '只有在登入狀態下才會同步共享行程。你的景點庫與私人行程不需要登入。';

  @override
  String get settingsFrameUploadQualityTitle => '分鏡上傳畫質';

  @override
  String get settingsDriveRemoveTitle => '從我的 Google 雲端硬碟移除共享分鏡';

  @override
  String get settingsDriveRemoveSubtitle =>
      '刪除本應用程式上傳到你雲端硬碟的所有分鏡，連結將會失效；行程成員尚未下載的分鏡也會失去來源。';

  @override
  String settingsDriveRemovalsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 項移除作業正在等待處理，會在下次連線至 Google 雲端硬碟時完成。',
      one: '有 1 項移除作業正在等待處理，會在下次連線至 Google 雲端硬碟時完成。',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupTitle => '備份至檔案';

  @override
  String get settingsBackupSubtitle =>
      '將你的景點庫（含相片與分鏡）與私人行程打包為單一檔案，方便保存或移轉至新手機。';

  @override
  String get settingsRestoreTitle => '從檔案還原';

  @override
  String get settingsRestoreSubtitle => '補入備份中尚未存在於這台裝置的內容，現有資料不會被覆蓋。';

  @override
  String get settingsYourDataTitle => '景點、行程、相片與分鏡';

  @override
  String get settingsMapTilesTitle => '地圖圖磚快取';

  @override
  String settingsMapTilesSubtitle(String size) {
    return '過去 14 天內瀏覽過的地圖會保留於裝置供離線檢視。\n$size';
  }

  @override
  String get settingsCutoutModelTitle => '去背模型';

  @override
  String settingsCutoutModelSubtitle(String size) {
    return '用於人物去背合成功能，首次使用時下載。\n$size';
  }

  @override
  String get settingsStorageError => '無法計算大小';

  @override
  String get settingsStorageMeasuring => '計算中…';

  @override
  String get settingsSizeUnder1Mb => '小於 1 MB';

  @override
  String get settingsSizeLessThan1Mb => '不到 1 MB';

  @override
  String get settingsClearMapTilesDialogTitle => '要清除地圖圖磚嗎？';

  @override
  String settingsClearMapTilesDialogBody(String size) {
    return '可釋放 $size 空間。之後瀏覽地圖時會重新下載圖磚，在此之前需要網路連線。';
  }

  @override
  String get settingsDeleteModelDialogTitle => '要刪除去背模型嗎？';

  @override
  String settingsDeleteModelDialogBody(String size) {
    return '可釋放 $size 空間。下次使用「人物去背」功能時會再次下載（約 176 MB）。';
  }

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsAboutAnitabiTitle => '巡禮景點與分鏡來源：Anitabi';

  @override
  String get settingsAboutAnitabiSubtitle =>
      'anitabi.cn，依 CC BY-NC-SA 4.0 授權共享：免費使用，禁止商業販售。';

  @override
  String get settingsAboutOsmTitle => '地圖來源：OpenStreetMap';

  @override
  String get settingsAboutOsmSubtitle => '© OpenStreetMap 貢獻者';

  @override
  String get settingsAboutBangumiTitle => '動畫搜尋來源：Bangumi 番組計畫';

  @override
  String get settingsAboutBangumiSubtitle => 'bgm.tv';

  @override
  String get settingsPrivacyPolicy => '隱私權政策';

  @override
  String get settingsSourceCode => '原始碼與版本發布';

  @override
  String get settingsOpenSourceLicences => '開放原始碼授權條款';

  @override
  String get placeTitleFallback => '地點';

  @override
  String get placeGone => '這個地點已不在行程中。';

  @override
  String placeSpotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個機位',
    );
    return '$_temp0';
  }

  @override
  String placeShotCount(int count) {
    return '拍過 $count';
  }

  @override
  String placeFilterAll(int count) {
    return '全部 $count';
  }

  @override
  String placeFilterNotShot(int count) {
    return '還沒拍 $count';
  }

  @override
  String get placeNearestFirst => '由近到遠';

  @override
  String get placeAllShot => '這裡都拍過了。';

  @override
  String get placeNoSpots => '沒有符合的機位。';

  @override
  String get placeSpotShot => '拍過';

  @override
  String get placeSpotNotShot => '還沒拍';

  @override
  String placeFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 張參考圖',
    );
    return '$_temp0';
  }

  @override
  String get placeFrameNotShotLabel => '參考圖，還沒拍';

  @override
  String get placeFrameShotLabel => '你拍的這張參考圖';

  @override
  String get placeDetails => '詳細資料';

  @override
  String get placeFoldBannerText => '一組站點現在就是一個地點，組內的站點成為其中的機位。';

  @override
  String get placeFoldBannerAction => '轉為地點';

  @override
  String get placeFoldConfirmTitle => '要將群組轉為地點嗎？';

  @override
  String get placeFoldConfirmBody =>
      '每個群組會合併成一個以群組命名的站點，組內站點的參考圖、日程與標籤都會移到這個站點，每張參考圖也會記住原本的拍攝位置。行程中的所有成員都會看到這項變更。';

  @override
  String placeFoldDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已建立 $count 個地點。',
    );
    return '$_temp0';
  }

  @override
  String get placeFoldNeedsSignIn => '請先登入才能修改共享行程。';

  @override
  String get placeFoldNeedsSync => '還有變更尚未同步，請等同步完成後再試一次。';

  @override
  String placeFoldFailed(String error) {
    return '無法將群組轉為地點：$error';
  }

  @override
  String placeFilterNearby(int count) {
    return '附近 $count';
  }

  @override
  String get placeNoneNearby => '60 公尺內沒有機位。';

  @override
  String get placeEstimated => '位置待確認';

  @override
  String get placeSpotsHeading => '機位';

  @override
  String get placeSpotsHint => '每個機位是一個拍攝位置，下面是在那裡拍的參考圖';

  @override
  String get placeNotesHeading => '筆記';

  @override
  String get placeNotesHint => '交通、開放時間、拍攝時段……';

  @override
  String get placeOpenInMaps => '在 Google 地圖打開';

  @override
  String placeDistanceAway(String distance) {
    return '離你 $distance';
  }

  @override
  String placeCompass(String dir) {
    String _temp0 = intl.Intl.selectLogic(dir, {
      'n': '北',
      'ne': '東北',
      'e': '東',
      'se': '東南',
      's': '南',
      'sw': '西南',
      'w': '西',
      'nw': '西北',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String placeSpotWay(String direction, String distance) {
    return '往$direction $distance';
  }

  @override
  String placeStartShooting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '開始拍 · 還有 $count 張沒拍',
    );
    return '$_temp0';
  }

  @override
  String get placeSeePhotos => '這裡都拍過了，看成果';

  @override
  String placeNext(String spot, String distance) {
    return '下一張：$spot · $distance';
  }

  @override
  String placeNextHere(String spot) {
    return '下一張：$spot';
  }

  @override
  String get placeShoot => '拍';

  @override
  String get placeSpotNoteLabel => '備註（機位沒有名字，用備註分辨）';

  @override
  String get placeSpotNoteHint => '例如：第 3 根柱子北側、往上游拍';

  @override
  String get placeSaveNote => '儲存備註';

  @override
  String get placeSetPosition => '在地圖上調整位置';

  @override
  String get placeSetPositionEstimated => '現在的位置是估的';

  @override
  String get placeShootSpot => '拍這個機位';

  @override
  String placePlacing(String spot) {
    return '拖動地圖，把十字對準「$spot」的拍攝位置';
  }

  @override
  String get placeSetHere => '設在這裡';

  @override
  String get placePositionSaved => '位置改好了';

  @override
  String placeSpotOptions(String spot) {
    return '「$spot」的選項';
  }

  @override
  String get placeMenu => '地點選項';

  @override
  String get placeDayUnsorted => '未分類';

  @override
  String placeDayN(int n) {
    return '第 $n 天';
  }

  @override
  String get placeNoDate => '沒有日期';

  @override
  String placeDayChip(String day) {
    return '分類：$day，點一下換分類';
  }

  @override
  String placeMoveTitle(String place) {
    return '「$place」放在哪個分類';
  }

  @override
  String placeMovedTo(String day) {
    return '移到「$day」';
  }

  @override
  String placeCountInDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點',
    );
    return '$_temp0';
  }

  @override
  String get placeMerge => '把另一個地點合併進來';

  @override
  String placeMergePick(String place) {
    return '合併到「$place」';
  }

  @override
  String placeMergeConfirm(String other, String place) {
    return '把「$other」合併到「$place」？';
  }

  @override
  String placeMergeBody(String other) {
    return '它的參考圖、標籤和日程會移到這裡，每張參考圖保留拍攝位置；「$other」會從行程移除，所有成員都會看到。';
  }

  @override
  String get placeMergeAction => '合併';

  @override
  String placeMerged(String other) {
    return '已把「$other」合併進來。';
  }

  @override
  String get placeTakePhoto => '開相機拍';

  @override
  String get placeCompare => '看對照';

  @override
  String get placeFrameTitle => '參考圖';

  @override
  String get placeNoFrames => '還沒有參考圖';

  @override
  String get placeSpotNoFrames => '這個機位還沒有參考圖。';

  @override
  String get placeCancel => '取消';

  @override
  String get tripTabPlaces => '地點';

  @override
  String get tripTabMembers => '成員';

  @override
  String get tripSchedule => '時間表';

  @override
  String get placesSearchHint => '找地點、機位備註或參考圖';

  @override
  String get placesClearSearch => '清除搜尋';

  @override
  String get placesSortNearest => '離我最近';

  @override
  String get placesSortByDay => '我的分類';

  @override
  String get placesNearestHeading => '離你最近';

  @override
  String get placesToday => '今天';

  @override
  String placesTodayTitle(String date, String day) {
    return '今天 $date · $day';
  }

  @override
  String placesTodayNearest(int count, String place, String distance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點，離你最近的是「$place」$distance',
    );
    return '$_temp0';
  }

  @override
  String placesTodayStart(int count, String place) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點，從「$place」開始',
    );
    return '$_temp0';
  }

  @override
  String placesNoMatch(String query) {
    return '找不到「$query」。';
  }

  @override
  String get placesEmptyDay => '還沒有地點。打開地點，按分類就能移過來。';

  @override
  String get placesEmpty => '這趟行程還沒有地點。';

  @override
  String get placesNewDay => '＋ 新分類';

  @override
  String get placesAddPlaces => '新增地點';

  @override
  String placesDayOptions(String day) {
    return '「$day」的選項';
  }

  @override
  String get placesRename => '重新命名';

  @override
  String get placesSetDate => '加上日期';

  @override
  String placesChangeDate(String date) {
    return '改日期（$date）';
  }

  @override
  String get placesClearDate => '拿掉日期';

  @override
  String get placesClearDateHint => '只留名字';

  @override
  String get placesReorder => '調整順序';

  @override
  String get placesDeleteDay => '刪除分類';

  @override
  String get placesDeleteDayHint => '裡面的地點會移到「未分類」';

  @override
  String placesDeleteDayTitle(String day) {
    return '刪除「$day」？';
  }

  @override
  String get placesDeleteDayBody => '分類裡的地點不會刪掉，會移到「未分類」。';

  @override
  String get placesDayName => '名稱';

  @override
  String get placesDayNameHint => '例如：西宮、下次再去、6/22 奈良';

  @override
  String get placesNewDayTitle => '新分類';

  @override
  String get placesRenameTitle => '編輯分類';

  @override
  String get placesWithDate => '加上日期（可以不填）';

  @override
  String get placesCreate => '建立分類';

  @override
  String get placesSave => '儲存';

  @override
  String get placesMoveUp => '上移';

  @override
  String get placesMoveDown => '下移';

  @override
  String get placesMatchName => '地點名稱';

  @override
  String placesMatchSpots(String notes) {
    return '機位：$notes';
  }

  @override
  String placesMatchFrames(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 張參考圖：$names',
    );
    return '$_temp0';
  }

  @override
  String get placesDone => '完成';

  @override
  String get placesAddFromLibrary => '從景點庫';

  @override
  String get placesAddFromLibraryHint => '你存過的地點';

  @override
  String get placesAddNewSpot => '新地點';

  @override
  String get placesAddNewSpotHint => '在地圖上選';

  @override
  String get placesShowAs => '顯示方式';

  @override
  String get placesViewList => '清單';

  @override
  String get placesViewMap => '地圖';

  @override
  String get mapAllDays => '全部';

  @override
  String get mapDays => '分類';

  @override
  String get mapYourLocation => '你的位置';

  @override
  String get mapOpenPlace => '打開地點';

  @override
  String get mapShootHere => '拍這裡';

  @override
  String get mapClose => '關閉';

  @override
  String mapPlaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點',
    );
    return '$_temp0';
  }

  @override
  String get mapCrowded => '這一帶太擠，點一個看看';

  @override
  String get mapNoPlaces => '這裡還沒有地點';

  @override
  String get placePickFromGallery => '從相簿選';

  @override
  String get placePickedSaved => '存好了，這張參考圖算拍過了';

  @override
  String placePickFailed(String error) {
    return '加不進這張照片：$error';
  }

  @override
  String get photosFilterAll => '全部';

  @override
  String get photosFilterToEdit => '待編輯';

  @override
  String photosFilterToEditCount(int count) {
    return '待編輯 · $count';
  }

  @override
  String get photosFilterPairs => '成果';

  @override
  String get photosEditFromGallery => '編輯相簿裡的照片';

  @override
  String get photosGroupBy => '分組';

  @override
  String get photosByDay => '按日期';

  @override
  String get photosByPlace => '按地點';

  @override
  String photosLoadFailed(String error) {
    return '載入不了照片：$error';
  }

  @override
  String get photosEmptyTitle => '還沒有照片';

  @override
  String get photosEmptyBody => '用「拍攝」或在地點裡拍的照片，會出現在這裡。';

  @override
  String get photosPairsEmpty => '打開一個地點，按「開始拍」，或在參考圖上選「從相簿選」。拍過的照片會和參考圖排在一起。';

  @override
  String get photosPlaceGone => '已經不在景點庫的地點';

  @override
  String get photosShareImage => '做分享圖';

  @override
  String photosShareMax(int max) {
    return '最多 $max 組';
  }

  @override
  String photosShareMake(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '用 $count 組做分享圖',
      zero: '選幾組照片',
    );
    return '$_temp0';
  }

  @override
  String get shareImageTitle => '分享圖';

  @override
  String shareImagePairs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組對照',
    );
    return '$_temp0';
  }

  @override
  String shareImageSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組 · 參考圖 ／ 我的照片',
    );
    return '$_temp0';
  }

  @override
  String get shareImageTitleField => '標題';

  @override
  String get shareImageGrid => '方格';

  @override
  String get shareImageStacked => '直排';

  @override
  String get shareImageSave => '存起來';

  @override
  String get shareImageShare => '分享';

  @override
  String get shareImageDefaultTitle => '聖地巡禮';

  @override
  String get shareImageNothing => '這些照片或參考圖都讀不到。';

  @override
  String shareImageFailed(String error) {
    return '做不出分享圖：$error';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => '聖地巡禮行程規劃';

  @override
  String get navHome => '首頁';

  @override
  String get navTrips => '行程';

  @override
  String get navLibrary => '景點庫';

  @override
  String get navPhotos => '相片';

  @override
  String get navShoot => '拍攝';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDone => '完成';

  @override
  String get commonClear => '清除';

  @override
  String get commonDelete => '刪除';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionApp => '應用程式';

  @override
  String get settingsSectionAccount => '帳號';

  @override
  String get settingsSectionData => '你的資料';

  @override
  String get settingsSectionAbout => '關於';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get settingsLanguageSystemSubtitle => '跟隨裝置語言設定；未支援的語言預設顯示英文。';

  @override
  String get settingsLanguageDialogTitle => '選擇語言';

  @override
  String settingsSignInFailed(String error) {
    return '無法登入：$error';
  }

  @override
  String get settingsSignedOut => '已登出。';

  @override
  String settingsSignOutFailed(String error) {
    return '無法登出：$error';
  }

  @override
  String get settingsNotSignedInTitle => '尚未登入';

  @override
  String get settingsNotSignedInSubtitle => '只有共享行程需要登入；其餘功能無需帳號即可使用。';

  @override
  String get settingsSignInButton => '登入';

  @override
  String get settingsSignedInFallbackTitle => '已登入';

  @override
  String get settingsGoogleAccountSubtitle => 'Google 帳號，用於共享行程';

  @override
  String get settingsSignOutTitle => '登出';

  @override
  String get settingsSignOutSubtitle => '只有在登入狀態下才會同步共享行程。你的景點庫與私人行程不需要登入。';

  @override
  String get settingsFrameUploadQualityTitle => '分鏡上傳畫質';

  @override
  String get settingsDriveRemoveTitle => '從我的 Google 雲端硬碟移除共享分鏡';

  @override
  String get settingsDriveRemoveSubtitle =>
      '刪除本應用程式上傳到你雲端硬碟的所有分鏡，連結將會失效；行程成員尚未下載的分鏡也會失去來源。';

  @override
  String settingsDriveRemovalsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 項移除作業正在等待處理，會在下次連線至 Google 雲端硬碟時完成。',
      one: '有 1 項移除作業正在等待處理，會在下次連線至 Google 雲端硬碟時完成。',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupTitle => '備份至檔案';

  @override
  String get settingsBackupSubtitle =>
      '將你的景點庫（含相片與分鏡）與私人行程打包為單一檔案，方便保存或移轉至新手機。';

  @override
  String get settingsRestoreTitle => '從檔案還原';

  @override
  String get settingsRestoreSubtitle => '補入備份中尚未存在於這台裝置的內容，現有資料不會被覆蓋。';

  @override
  String get settingsYourDataTitle => '景點、行程、相片與分鏡';

  @override
  String get settingsMapTilesTitle => '地圖圖磚快取';

  @override
  String settingsMapTilesSubtitle(String size) {
    return '過去 14 天內瀏覽過的地圖會保留於裝置供離線檢視。\n$size';
  }

  @override
  String get settingsCutoutModelTitle => '去背模型';

  @override
  String settingsCutoutModelSubtitle(String size) {
    return '用於人物去背合成功能，首次使用時下載。\n$size';
  }

  @override
  String get settingsStorageError => '無法計算大小';

  @override
  String get settingsStorageMeasuring => '計算中…';

  @override
  String get settingsSizeUnder1Mb => '小於 1 MB';

  @override
  String get settingsSizeLessThan1Mb => '不到 1 MB';

  @override
  String get settingsClearMapTilesDialogTitle => '要清除地圖圖磚嗎？';

  @override
  String settingsClearMapTilesDialogBody(String size) {
    return '可釋放 $size 空間。之後瀏覽地圖時會重新下載圖磚，在此之前需要網路連線。';
  }

  @override
  String get settingsDeleteModelDialogTitle => '要刪除去背模型嗎？';

  @override
  String settingsDeleteModelDialogBody(String size) {
    return '可釋放 $size 空間。下次使用「人物去背」功能時會再次下載（約 176 MB）。';
  }

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsAboutAnitabiTitle => '巡禮景點與分鏡來源：Anitabi';

  @override
  String get settingsAboutAnitabiSubtitle =>
      'anitabi.cn，依 CC BY-NC-SA 4.0 授權共享：免費使用，禁止商業販售。';

  @override
  String get settingsAboutOsmTitle => '地圖來源：OpenStreetMap';

  @override
  String get settingsAboutOsmSubtitle => '© OpenStreetMap 貢獻者';

  @override
  String get settingsAboutBangumiTitle => '動畫搜尋來源：Bangumi 番組計畫';

  @override
  String get settingsAboutBangumiSubtitle => 'bgm.tv';

  @override
  String get settingsPrivacyPolicy => '隱私權政策';

  @override
  String get settingsSourceCode => '原始碼與版本發布';

  @override
  String get settingsOpenSourceLicences => '開放原始碼授權條款';

  @override
  String get placeTitleFallback => '地點';

  @override
  String get placeGone => '這個地點已不在行程中。';

  @override
  String placeSpotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個機位',
    );
    return '$_temp0';
  }

  @override
  String placeShotCount(int count) {
    return '拍過 $count';
  }

  @override
  String placeFilterAll(int count) {
    return '全部 $count';
  }

  @override
  String placeFilterNotShot(int count) {
    return '還沒拍 $count';
  }

  @override
  String get placeNearestFirst => '由近到遠';

  @override
  String get placeAllShot => '這裡都拍過了。';

  @override
  String get placeNoSpots => '沒有符合的機位。';

  @override
  String get placeSpotShot => '拍過';

  @override
  String get placeSpotNotShot => '還沒拍';

  @override
  String placeFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 張參考圖',
    );
    return '$_temp0';
  }

  @override
  String get placeFrameNotShotLabel => '參考圖，還沒拍';

  @override
  String get placeFrameShotLabel => '你拍的這張參考圖';

  @override
  String get placeDetails => '詳細資料';

  @override
  String get placeFoldBannerText => '一組站點現在就是一個地點，組內的站點成為其中的機位。';

  @override
  String get placeFoldBannerAction => '轉為地點';

  @override
  String get placeFoldConfirmTitle => '要將群組轉為地點嗎？';

  @override
  String get placeFoldConfirmBody =>
      '每個群組會合併成一個以群組命名的站點，組內站點的參考圖、日程與標籤都會移到這個站點，每張參考圖也會記住原本的拍攝位置。行程中的所有成員都會看到這項變更。';

  @override
  String placeFoldDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已建立 $count 個地點。',
    );
    return '$_temp0';
  }

  @override
  String get placeFoldNeedsSignIn => '請先登入才能修改共享行程。';

  @override
  String get placeFoldNeedsSync => '還有變更尚未同步，請等同步完成後再試一次。';

  @override
  String placeFoldFailed(String error) {
    return '無法將群組轉為地點：$error';
  }

  @override
  String placeFilterNearby(int count) {
    return '附近 $count';
  }

  @override
  String get placeNoneNearby => '60 公尺內沒有機位。';

  @override
  String get placeEstimated => '位置待確認';

  @override
  String get placeSpotsHeading => '機位';

  @override
  String get placeSpotsHint => '每個機位是一個拍攝位置，下面是在那裡拍的參考圖';

  @override
  String get placeNotesHeading => '筆記';

  @override
  String get placeNotesHint => '交通、開放時間、拍攝時段……';

  @override
  String get placeOpenInMaps => '在 Google 地圖打開';

  @override
  String placeDistanceAway(String distance) {
    return '離你 $distance';
  }

  @override
  String placeCompass(String dir) {
    String _temp0 = intl.Intl.selectLogic(dir, {
      'n': '北',
      'ne': '東北',
      'e': '東',
      'se': '東南',
      's': '南',
      'sw': '西南',
      'w': '西',
      'nw': '西北',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String placeSpotWay(String direction, String distance) {
    return '往$direction $distance';
  }

  @override
  String placeStartShooting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '開始拍 · 還有 $count 張沒拍',
    );
    return '$_temp0';
  }

  @override
  String get placeSeePhotos => '這裡都拍過了，看成果';

  @override
  String placeNext(String spot, String distance) {
    return '下一張：$spot · $distance';
  }

  @override
  String placeNextHere(String spot) {
    return '下一張：$spot';
  }

  @override
  String get placeShoot => '拍';

  @override
  String get placeSpotNoteLabel => '備註（機位沒有名字，用備註分辨）';

  @override
  String get placeSpotNoteHint => '例如：第 3 根柱子北側、往上游拍';

  @override
  String get placeSaveNote => '儲存備註';

  @override
  String get placeSetPosition => '在地圖上調整位置';

  @override
  String get placeSetPositionEstimated => '現在的位置是估的';

  @override
  String get placeShootSpot => '拍這個機位';

  @override
  String placePlacing(String spot) {
    return '拖動地圖，把十字對準「$spot」的拍攝位置';
  }

  @override
  String get placeSetHere => '設在這裡';

  @override
  String get placePositionSaved => '位置改好了';

  @override
  String placeSpotOptions(String spot) {
    return '「$spot」的選項';
  }

  @override
  String get placeMenu => '地點選項';

  @override
  String get placeDayUnsorted => '未分類';

  @override
  String placeDayN(int n) {
    return '第 $n 天';
  }

  @override
  String get placeNoDate => '沒有日期';

  @override
  String placeDayChip(String day) {
    return '分類：$day，點一下換分類';
  }

  @override
  String placeMoveTitle(String place) {
    return '「$place」放在哪個分類';
  }

  @override
  String placeMovedTo(String day) {
    return '移到「$day」';
  }

  @override
  String placeCountInDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點',
    );
    return '$_temp0';
  }

  @override
  String get placeMerge => '把另一個地點合併進來';

  @override
  String placeMergePick(String place) {
    return '合併到「$place」';
  }

  @override
  String placeMergeConfirm(String other, String place) {
    return '把「$other」合併到「$place」？';
  }

  @override
  String placeMergeBody(String other) {
    return '它的參考圖、標籤和日程會移到這裡，每張參考圖保留拍攝位置；「$other」會從行程移除，所有成員都會看到。';
  }

  @override
  String get placeMergeAction => '合併';

  @override
  String placeMerged(String other) {
    return '已把「$other」合併進來。';
  }

  @override
  String get placeTakePhoto => '開相機拍';

  @override
  String get placeCompare => '看對照';

  @override
  String get placeFrameTitle => '參考圖';

  @override
  String get placeNoFrames => '還沒有參考圖';

  @override
  String get placeSpotNoFrames => '這個機位還沒有參考圖。';

  @override
  String get placeCancel => '取消';

  @override
  String get tripTabPlaces => '地點';

  @override
  String get tripTabMembers => '成員';

  @override
  String get tripSchedule => '時間表';

  @override
  String get placesSearchHint => '找地點、機位備註或參考圖';

  @override
  String get placesClearSearch => '清除搜尋';

  @override
  String get placesSortNearest => '離我最近';

  @override
  String get placesSortByDay => '我的分類';

  @override
  String get placesNearestHeading => '離你最近';

  @override
  String get placesToday => '今天';

  @override
  String placesTodayTitle(String date, String day) {
    return '今天 $date · $day';
  }

  @override
  String placesTodayNearest(int count, String place, String distance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點，離你最近的是「$place」$distance',
    );
    return '$_temp0';
  }

  @override
  String placesTodayStart(int count, String place) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點，從「$place」開始',
    );
    return '$_temp0';
  }

  @override
  String placesNoMatch(String query) {
    return '找不到「$query」。';
  }

  @override
  String get placesEmptyDay => '還沒有地點。打開地點，按分類就能移過來。';

  @override
  String get placesEmpty => '這趟行程還沒有地點。';

  @override
  String get placesNewDay => '＋ 新分類';

  @override
  String get placesAddPlaces => '新增地點';

  @override
  String placesDayOptions(String day) {
    return '「$day」的選項';
  }

  @override
  String get placesRename => '重新命名';

  @override
  String get placesSetDate => '加上日期';

  @override
  String placesChangeDate(String date) {
    return '改日期（$date）';
  }

  @override
  String get placesClearDate => '拿掉日期';

  @override
  String get placesClearDateHint => '只留名字';

  @override
  String get placesReorder => '調整順序';

  @override
  String get placesDeleteDay => '刪除分類';

  @override
  String get placesDeleteDayHint => '裡面的地點會移到「未分類」';

  @override
  String placesDeleteDayTitle(String day) {
    return '刪除「$day」？';
  }

  @override
  String get placesDeleteDayBody => '分類裡的地點不會刪掉，會移到「未分類」。';

  @override
  String get placesDayName => '名稱';

  @override
  String get placesDayNameHint => '例如：西宮、下次再去、6/22 奈良';

  @override
  String get placesNewDayTitle => '新分類';

  @override
  String get placesRenameTitle => '編輯分類';

  @override
  String get placesWithDate => '加上日期（可以不填）';

  @override
  String get placesCreate => '建立分類';

  @override
  String get placesSave => '儲存';

  @override
  String get placesMoveUp => '上移';

  @override
  String get placesMoveDown => '下移';

  @override
  String get placesMatchName => '地點名稱';

  @override
  String placesMatchSpots(String notes) {
    return '機位：$notes';
  }

  @override
  String placesMatchFrames(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 張參考圖：$names',
    );
    return '$_temp0';
  }

  @override
  String get placesDone => '完成';

  @override
  String get placesAddFromLibrary => '從景點庫';

  @override
  String get placesAddFromLibraryHint => '你存過的地點';

  @override
  String get placesAddNewSpot => '新地點';

  @override
  String get placesAddNewSpotHint => '在地圖上選';

  @override
  String get placesShowAs => '顯示方式';

  @override
  String get placesViewList => '清單';

  @override
  String get placesViewMap => '地圖';

  @override
  String get mapAllDays => '全部';

  @override
  String get mapDays => '分類';

  @override
  String get mapYourLocation => '你的位置';

  @override
  String get mapOpenPlace => '打開地點';

  @override
  String get mapShootHere => '拍這裡';

  @override
  String get mapClose => '關閉';

  @override
  String mapPlaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個地點',
    );
    return '$_temp0';
  }

  @override
  String get mapCrowded => '這一帶太擠，點一個看看';

  @override
  String get mapNoPlaces => '這裡還沒有地點';

  @override
  String get placePickFromGallery => '從相簿選';

  @override
  String get placePickedSaved => '存好了，這張參考圖算拍過了';

  @override
  String placePickFailed(String error) {
    return '加不進這張照片：$error';
  }

  @override
  String get photosFilterAll => '全部';

  @override
  String get photosFilterToEdit => '待編輯';

  @override
  String photosFilterToEditCount(int count) {
    return '待編輯 · $count';
  }

  @override
  String get photosFilterPairs => '成果';

  @override
  String get photosEditFromGallery => '編輯相簿裡的照片';

  @override
  String get photosGroupBy => '分組';

  @override
  String get photosByDay => '按日期';

  @override
  String get photosByPlace => '按地點';

  @override
  String photosLoadFailed(String error) {
    return '載入不了照片：$error';
  }

  @override
  String get photosEmptyTitle => '還沒有照片';

  @override
  String get photosEmptyBody => '用「拍攝」或在地點裡拍的照片，會出現在這裡。';

  @override
  String get photosPairsEmpty => '打開一個地點，按「開始拍」，或在參考圖上選「從相簿選」。拍過的照片會和參考圖排在一起。';

  @override
  String get photosPlaceGone => '已經不在景點庫的地點';

  @override
  String get photosShareImage => '做分享圖';

  @override
  String photosShareMax(int max) {
    return '最多 $max 組';
  }

  @override
  String photosShareMake(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '用 $count 組做分享圖',
      zero: '選幾組照片',
    );
    return '$_temp0';
  }

  @override
  String get shareImageTitle => '分享圖';

  @override
  String shareImagePairs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組對照',
    );
    return '$_temp0';
  }

  @override
  String shareImageSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組 · 參考圖 ／ 我的照片',
    );
    return '$_temp0';
  }

  @override
  String get shareImageTitleField => '標題';

  @override
  String get shareImageGrid => '方格';

  @override
  String get shareImageStacked => '直排';

  @override
  String get shareImageSave => '存起來';

  @override
  String get shareImageShare => '分享';

  @override
  String get shareImageDefaultTitle => '聖地巡禮';

  @override
  String get shareImageNothing => '這些照片或參考圖都讀不到。';

  @override
  String shareImageFailed(String error) {
    return '做不出分享圖：$error';
  }
}
