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
  String get placeFrameNotShotLabel => '比較画像、未撮影。タップして撮影';

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
}
