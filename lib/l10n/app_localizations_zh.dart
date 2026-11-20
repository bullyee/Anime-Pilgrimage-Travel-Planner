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
}
