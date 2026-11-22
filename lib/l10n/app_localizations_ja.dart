// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '聖地巡礼プランナー';

  @override
  String get navHome => 'ホーム';

  @override
  String get navTrips => '旅行';

  @override
  String get navLibrary => 'ライブラリ';

  @override
  String get navPhotos => '写真';

  @override
  String get navShoot => '撮影';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonDone => '完了';

  @override
  String get commonClear => '消去';

  @override
  String get commonDelete => '削除';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionApp => 'アプリ';

  @override
  String get settingsSectionAccount => 'アカウント';

  @override
  String get settingsSectionData => 'データ管理';

  @override
  String get settingsSectionAbout => 'このアプリについて';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageSystem => 'システム設定に従う';

  @override
  String get settingsLanguageSystemSubtitle => '端末の言語設定に従います。未対応の言語は英語で表示されます。';

  @override
  String get settingsLanguageDialogTitle => '言語を選択';

  @override
  String settingsSignInFailed(String error) {
    return 'ログインできませんでした：$error';
  }

  @override
  String get settingsSignedOut => 'ログアウトしました。';

  @override
  String settingsSignOutFailed(String error) {
    return 'ログアウトできませんでした：$error';
  }

  @override
  String get settingsNotSignedInTitle => '未ログイン';

  @override
  String get settingsNotSignedInSubtitle =>
      'ログインは旅行の共有にのみ必要です。その他の機能はアカウント不要で使えます。';

  @override
  String get settingsSignInButton => 'ログイン';

  @override
  String get settingsSignedInFallbackTitle => 'ログイン済み';

  @override
  String get settingsGoogleAccountSubtitle => 'Google アカウント（共有旅行用）';

  @override
  String get settingsSignOutTitle => 'ログアウト';

  @override
  String get settingsSignOutSubtitle =>
      '共有旅行の同期はログイン中のみ有効です。ライブラリや非公開の旅行には不要です。';

  @override
  String get settingsFrameUploadQualityTitle => '比較画像のアップロード画質';

  @override
  String get settingsDriveRemoveTitle => 'Google ドライブから共有比較画像を削除';

  @override
  String get settingsDriveRemoveSubtitle =>
      'このアプリがドライブに保存したすべての比較画像を削除します。リンクは無効になり、他のメンバーの未ダウンロード画像も取得できなくなります。';

  @override
  String settingsDriveRemovalsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の削除が待機中です。Google ドライブへ接続でき次第完了します。',
      one: '1 件の削除が待機中です。Google ドライブへ接続でき次第完了します。',
    );
    return '$_temp0';
  }

  @override
  String get settingsBackupTitle => 'ファイルへバックアップ';

  @override
  String get settingsBackupSubtitle =>
      'ライブラリ（写真や比較画像を含む）と非公開の旅行を 1 つのファイルに保存します。';

  @override
  String get settingsRestoreTitle => 'ファイルから復元';

  @override
  String get settingsRestoreSubtitle =>
      'バックアップ内のこの端末にない項目のみを追加します。現在のデータは変更されません。';

  @override
  String get settingsYourDataTitle => 'スポット・旅行・写真・比較画像';

  @override
  String get settingsMapTilesTitle => '地図タイルキャッシュ';

  @override
  String settingsMapTilesSubtitle(String size) {
    return '過去 14 日間に表示した地図をオフライン表示用に保持しています。\n$size';
  }

  @override
  String get settingsCutoutModelTitle => '切り抜きモデル';

  @override
  String settingsCutoutModelSubtitle(String size) {
    return 'キャラクター切り抜き合成用（初回利用時にダウンロード）。\n$size';
  }

  @override
  String get settingsStorageError => '計測できませんでした';

  @override
  String get settingsStorageMeasuring => '計測中…';

  @override
  String get settingsSizeUnder1Mb => '1 MB 未満';

  @override
  String get settingsSizeLessThan1Mb => '1 MB 未満';

  @override
  String get settingsClearMapTilesDialogTitle => '地図タイルを消去しますか？';

  @override
  String settingsClearMapTilesDialogBody(String size) {
    return '$size の空き容量を確保します。次回地図を表示するときに再度読み込むため、それまで通信が必要です。';
  }

  @override
  String get settingsDeleteModelDialogTitle => '切り抜きモデルを削除しますか？';

  @override
  String settingsDeleteModelDialogBody(String size) {
    return '$size の空き容量を確保します。次回「キャラクター切り抜き」を使う際に再ダウンロード（約 176 MB）されます。';
  }

  @override
  String settingsVersion(String version) {
    return 'バージョン $version';
  }

  @override
  String get settingsAboutAnitabiTitle => 'スポット・比較画像提供：Anitabi';

  @override
  String get settingsAboutAnitabiSubtitle =>
      'anitabi.cn（CC BY-NC-SA 4.0：無料利用・商用販売不可）';

  @override
  String get settingsAboutOsmTitle => '地図データ：OpenStreetMap';

  @override
  String get settingsAboutOsmSubtitle => '© OpenStreetMap contributors';

  @override
  String get settingsAboutBangumiTitle => 'アニメ検索：Bangumi 番組計画';

  @override
  String get settingsAboutBangumiSubtitle => 'bgm.tv';

  @override
  String get settingsPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get settingsSourceCode => 'ソースコードとリリース';

  @override
  String get settingsOpenSourceLicences => 'オープンソースライセンス';

  @override
  String get placeTitleFallback => '場所';

  @override
  String get placeGone => 'この場所は旅程から外れています。';

  @override
  String placeSpotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か所',
    );
    return '$_temp0';
  }

  @override
  String placeShotCount(int count) {
    return '撮影済み $count';
  }

  @override
  String placeFilterAll(int count) {
    return 'すべて $count';
  }

  @override
  String placeFilterNotShot(int count) {
    return '未撮影 $count';
  }

  @override
  String get placeNearestFirst => '近い順';

  @override
  String get placeAllShot => 'ここはすべて撮影済みです。';

  @override
  String get placeNoSpots => 'スポットがありません。';

  @override
  String get placeSpotShot => '撮影済み';

  @override
  String get placeSpotNotShot => '未撮影';

  @override
  String placeFrameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '比較画像 $count 枚',
    );
    return '$_temp0';
  }

  @override
  String get placeFrameNotShotLabel => '比較画像、未撮影';

  @override
  String get placeFrameShotLabel => 'この比較画像に合わせて撮った写真';

  @override
  String get placeDetails => '詳細';

  @override
  String get placeFoldBannerText => 'グループは一つの場所になり、中の各スポットは撮影位置になりました。';

  @override
  String get placeFoldBannerAction => '場所に変換';

  @override
  String get placeFoldConfirmTitle => 'グループを場所に変換しますか？';

  @override
  String get placeFoldConfirmBody =>
      '各グループはグループ名の一つのスポットにまとまります。中のスポットの比較画像・日程・ラベルはそこへ移り、比較画像ごとに撮影位置が残ります。旅程のメンバー全員に反映されます。';

  @override
  String placeFoldDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か所の場所にまとめました。',
    );
    return '$_temp0';
  }

  @override
  String get placeFoldNeedsSignIn => '共有旅程を変更するにはログインしてください。';

  @override
  String get placeFoldNeedsSync => '未同期の変更があります。同期が終わってからもう一度お試しください。';

  @override
  String placeFoldFailed(String error) {
    return 'グループを場所に変換できませんでした：$error';
  }

  @override
  String placeFilterNearby(int count) {
    return '近く $count';
  }

  @override
  String get placeNoneNearby => '60 m 以内に撮影位置はありません。';

  @override
  String get placeEstimated => '位置は推定';

  @override
  String get placeSpotsHeading => '撮影位置';

  @override
  String get placeSpotsHint => '撮影位置ごとに、そこで撮る比較画像が並びます';

  @override
  String get placeNotesHeading => 'メモ';

  @override
  String get placeNotesHint => 'アクセス、営業時間、撮る時間帯…';

  @override
  String get placeOpenInMaps => 'Google マップで開く';

  @override
  String placeDistanceAway(String distance) {
    return 'ここから $distance';
  }

  @override
  String placeCompass(String dir) {
    String _temp0 = intl.Intl.selectLogic(dir, {
      'n': '北',
      'ne': '北東',
      'e': '東',
      'se': '南東',
      's': '南',
      'sw': '南西',
      'w': '西',
      'nw': '北西',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String placeSpotWay(String direction, String distance) {
    return '$directionへ $distance';
  }

  @override
  String placeStartShooting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '撮影を始める · 未撮影 $count 枚',
    );
    return '$_temp0';
  }

  @override
  String get placeSeePhotos => 'ここはすべて撮影済み · 写真を見る';

  @override
  String placeNext(String spot, String distance) {
    return '次：$spot · $distance';
  }

  @override
  String placeNextHere(String spot) {
    return '次：$spot';
  }

  @override
  String get placeShoot => '撮影';

  @override
  String get placeSpotNoteLabel => 'メモ（撮影位置に名前はなく、メモで見分けます）';

  @override
  String get placeSpotNoteHint => '例：3 本目の柱の北側';

  @override
  String get placeSaveNote => 'メモを保存';

  @override
  String get placeSetPosition => '地図で位置を調整';

  @override
  String get placeSetPositionEstimated => '今の位置は推定です';

  @override
  String get placeShootSpot => 'この位置で撮影';

  @override
  String placePlacing(String spot) {
    return '地図を動かして、「$spot」の撮影位置に十字を合わせてください';
  }

  @override
  String get placeSetHere => 'ここに設定';

  @override
  String get placePositionSaved => '位置を保存しました。';

  @override
  String placeSpotOptions(String spot) {
    return '「$spot」のオプション';
  }

  @override
  String get placeMenu => '場所のオプション';

  @override
  String get placeDayUnsorted => '未分類';

  @override
  String placeDayN(int n) {
    return '$n 日目';
  }

  @override
  String get placeNoDate => '日付なし';

  @override
  String placeDayChip(String day) {
    return '分類：$day。タップで移動';
  }

  @override
  String placeMoveTitle(String place) {
    return '「$place」の分類';
  }

  @override
  String placeMovedTo(String day) {
    return '「$day」に移動しました。';
  }

  @override
  String placeCountInDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か所',
    );
    return '$_temp0';
  }

  @override
  String get placeMerge => '別の場所をここに統合';

  @override
  String placeMergePick(String place) {
    return '「$place」に統合';
  }

  @override
  String placeMergeConfirm(String other, String place) {
    return '「$other」を「$place」に統合しますか？';
  }

  @override
  String placeMergeBody(String other) {
    return '比較画像・ラベル・日程はここへ移り、比較画像ごとに撮影位置が残ります。「$other」は旅程から外れ、メンバー全員に反映されます。';
  }

  @override
  String get placeMergeAction => '統合';

  @override
  String placeMerged(String other) {
    return '「$other」をここに統合しました。';
  }

  @override
  String get placeTakePhoto => '撮影';

  @override
  String get placeCompare => '写真を見る';

  @override
  String get placeFrameTitle => '比較画像';

  @override
  String get placeNoFrames => '比較画像はまだありません';

  @override
  String get placeSpotNoFrames => 'この撮影位置にはまだ比較画像がありません。';

  @override
  String get placeCancel => 'キャンセル';

  @override
  String get tripTabPlaces => '場所';

  @override
  String get tripTabMembers => 'メンバー';

  @override
  String get tripSchedule => 'スケジュール';

  @override
  String get placesSearchHint => '場所・メモ・比較画像を検索';

  @override
  String get placesClearSearch => '検索をクリア';

  @override
  String get placesSortNearest => '近い順';

  @override
  String get placesSortByDay => '分類順';

  @override
  String get placesNearestHeading => '近い順';

  @override
  String get placesToday => '今日';

  @override
  String placesTodayTitle(String date, String day) {
    return '今日 $date · $day';
  }

  @override
  String placesTodayNearest(int count, String place, String distance) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か所、いちばん近いのは「$place」$distance',
    );
    return '$_temp0';
  }

  @override
  String placesTodayStart(int count, String place) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か所、「$place」から',
    );
    return '$_temp0';
  }

  @override
  String placesNoMatch(String query) {
    return '「$query」は見つかりません。';
  }

  @override
  String get placesEmptyDay => 'まだ場所がありません。場所を開いて分類をタップすると移せます。';

  @override
  String get placesEmpty => 'この旅程にはまだ場所がありません。';

  @override
  String get placesNewDay => '＋ 新しい日／分類';

  @override
  String get placesAddPlaces => '場所を追加';

  @override
  String placesDayOptions(String day) {
    return '「$day」のオプション';
  }

  @override
  String get placesRename => '名前を変更';

  @override
  String get placesSetDate => '日付を付ける';

  @override
  String placesChangeDate(String date) {
    return '日付を変更（$date）';
  }

  @override
  String get placesClearDate => '日付を外す';

  @override
  String get placesClearDateHint => '名前だけ残します';

  @override
  String get placesReorder => '並べ替え';

  @override
  String get placesDeleteDay => '削除';

  @override
  String get placesDeleteDayHint => '中の場所は「未分類」に移ります';

  @override
  String placesDeleteDayTitle(String day) {
    return '「$day」を削除しますか？';
  }

  @override
  String get placesDeleteDayBody => '中の場所は削除されず、「未分類」に移ります。';

  @override
  String get placesDayName => '名前';

  @override
  String get placesDayNameHint => '例：西宮、次回';

  @override
  String get placesNewDayTitle => '新しい日／分類';

  @override
  String get placesRenameTitle => '分類を編集';

  @override
  String get placesWithDate => '日付を付ける（任意）';

  @override
  String get placesCreate => '作成';

  @override
  String get placesSave => '保存';

  @override
  String get placesMoveUp => '上へ';

  @override
  String get placesMoveDown => '下へ';

  @override
  String get placesMatchName => '場所の名前';

  @override
  String placesMatchSpots(String notes) {
    return '撮影位置：$notes';
  }

  @override
  String placesMatchFrames(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '比較画像 $count 枚：$names',
    );
    return '$_temp0';
  }

  @override
  String get placesDone => '完了';

  @override
  String get placesAddFromLibrary => 'ライブラリから';

  @override
  String get placesAddFromLibraryHint => '保存した場所';

  @override
  String get placesAddNewSpot => '新しい場所';

  @override
  String get placesAddNewSpotHint => '地図で選ぶ';

  @override
  String get placesShowAs => '表示';

  @override
  String get placesViewList => 'リスト';

  @override
  String get placesViewMap => '地図';

  @override
  String get mapAllDays => 'すべて';

  @override
  String get mapDays => '日';

  @override
  String get mapYourLocation => '現在地';

  @override
  String get mapOpenPlace => '場所を開く';

  @override
  String get mapShootHere => 'ここで撮る';

  @override
  String get mapClose => '閉じる';

  @override
  String mapPlaceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count か所',
    );
    return '$_temp0';
  }

  @override
  String get mapCrowded => 'このあたりは混み合っています。ひとつ選んでください';

  @override
  String get mapNoPlaces => 'まだ場所がありません';

  @override
  String get placePickFromGallery => 'ギャラリーから選ぶ';

  @override
  String get placePickEmpty => 'この写真は開けないので使えません';

  @override
  String get placePickedSaved => 'この比較画像の写真として保存しました';

  @override
  String placePickFailed(String error) {
    return '写真を追加できませんでした：$error';
  }

  @override
  String get photosFilterAll => 'すべて';

  @override
  String get photosFilterToEdit => '編集待ち';

  @override
  String photosFilterToEditCount(int count) {
    return '編集待ち · $count';
  }

  @override
  String get photosFilterPairs => '成果';

  @override
  String get photosEditFromGallery => 'ギャラリーの写真を編集';

  @override
  String get photosGroupBy => 'グループ';

  @override
  String get photosByDay => '日付ごと';

  @override
  String get photosByPlace => '場所ごと';

  @override
  String photosLoadFailed(String error) {
    return '写真を読み込めませんでした：$error';
  }

  @override
  String get photosEmptyTitle => 'まだ写真がありません';

  @override
  String get photosEmptyBody => '撮影や場所のページで撮った写真がここに表示されます。';

  @override
  String get photosPairsEmpty =>
      '場所を開いて撮影するか、比較画像で「ギャラリーから選ぶ」を選んでください。撮った写真が比較画像と並んで表示されます。';

  @override
  String get photosPlaceGone => 'ライブラリにない場所';

  @override
  String get photosShareImage => '共有画像';

  @override
  String photosShareMax(int max) {
    return '最大 $max 組';
  }

  @override
  String photosShareMake(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組で画像を作る',
      zero: 'いくつか選んでください',
    );
    return '$_temp0';
  }

  @override
  String get shareImageTitle => '共有画像';

  @override
  String shareImagePairs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組',
    );
    return '$_temp0';
  }

  @override
  String shareImageSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 組 · 比較画像 ／ 自分の写真',
    );
    return '$_temp0';
  }

  @override
  String get shareImageTitleField => 'タイトル';

  @override
  String get shareImageGrid => 'グリッド';

  @override
  String get shareImageStacked => '縦並び';

  @override
  String get shareImageSave => '保存';

  @override
  String get shareImageShare => '共有';

  @override
  String get shareImageDefaultTitle => '聖地巡礼';

  @override
  String get shareImageNothing => '写真も比較画像も読み込めませんでした。';

  @override
  String shareImageFailed(String error) {
    return '画像を作れませんでした：$error';
  }
}
