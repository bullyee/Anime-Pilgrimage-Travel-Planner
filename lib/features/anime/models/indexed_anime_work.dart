import 'dart:math' as math;

import '../../../core/utils/chinese_converter.dart';
import 'bangumi_subject.dart';

/// An anime work indexed from Anitabi's static data (`g.json`) for fast,
/// offline, multilingual search.
class IndexedAnimeWork {
  final String bangumiId;
  final String japaneseTitle;
  final String chineseTitle;
  final String traditionalTitle;
  final String? englishTitle;
  final String? city;
  final int spotCount;
  final String? coverUrl;
  final double? centerLat;
  final double? centerLng;
  final String? platform;

  const IndexedAnimeWork({
    required this.bangumiId,
    required this.japaneseTitle,
    required this.chineseTitle,
    required this.traditionalTitle,
    this.englishTitle,
    this.city,
    required this.spotCount,
    this.coverUrl,
    this.centerLat,
    this.centerLng,
    this.platform,
  });

  /// Creates an [IndexedAnimeWork] from a row in `g.json`.
  ///
  /// Index layout per work:
  /// `[0]` bangumiId, `[1]` Chinese title, `[2]` English/romaji title,
  /// `[3]` Japanese/original title, `[4]` city, `[6]` image, `[8]` platform,
  /// `[9]` lat, `[10]` lng, `[12]` coords flat list.
  factory IndexedAnimeWork.fromAnitabiRow(List<dynamic> row) {
    final id = row.isNotEmpty ? row[0].toString() : '';

    String textAt(int index) {
      if (index >= row.length) return '';
      final val = row[index];
      if (val == null || val == 0 || val == false) return '';
      return val.toString().trim();
    }

    final cn = textAt(1);
    final en = textAt(2);
    final jp = textAt(3);
    final primaryTitle = jp.isNotEmpty ? jp : cn;
    final cnTitle = cn.isNotEmpty ? cn : primaryTitle;
    final tcTitle = ChineseConverter.toTraditional(cnTitle);

    final cityStr = textAt(4);
    final platformStr = textAt(8);

    double? lat;
    double? lng;
    if (row.length > 10) {
      final rLat = row[9];
      final rLng = row[10];
      if (rLat is num && rLat != 0) lat = rLat.toDouble();
      if (rLng is num && rLng != 0) lng = rLng.toDouble();
    }

    var spots = 0;
    if (row.length > 12 && row[12] is List) {
      final flat = row[12] as List<dynamic>;
      spots = flat.length ~/ 4;
    }

    String? cover;
    final rawImg = textAt(6);
    if (rawImg.isNotEmpty) {
      if (rawImg.startsWith('/images/')) {
        cover = 'https://image.anitabi.cn${rawImg.substring('/images'.length)}?plan=h160';
      } else if (rawImg.startsWith('http')) {
        cover = rawImg;
      }
    }

    return IndexedAnimeWork(
      bangumiId: id,
      japaneseTitle: primaryTitle,
      chineseTitle: cnTitle,
      traditionalTitle: tcTitle,
      englishTitle: en.isNotEmpty ? en : null,
      city: cityStr.isNotEmpty ? cityStr : null,
      spotCount: spots,
      coverUrl: cover,
      centerLat: lat,
      centerLng: lng,
      platform: platformStr.isNotEmpty ? platformStr : null,
    );
  }

  /// Calculates a relevance score for [query].
  /// Returns 0 if there is no match.
  int calculateRelevance(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return 0;

    // Direct Bangumi ID match
    if (bangumiId == trimmed) {
      return 150 + math.min(spotCount, 25);
    }

    final normQ = ChineseConverter.normalize(trimmed);
    if (normQ.isEmpty) return 0;

    final normJp = ChineseConverter.normalize(japaneseTitle);
    final normCn = ChineseConverter.normalize(chineseTitle);
    final normTc = ChineseConverter.normalize(traditionalTitle);
    final normEn = englishTitle != null ? ChineseConverter.normalize(englishTitle!) : '';

    var baseScore = 0;

    // Exact match
    if (normJp == normQ || normCn == normQ || normTc == normQ || normEn == normQ) {
      baseScore = 100;
    }
    // Prefix match
    else if (normJp.startsWith(normQ) ||
        normCn.startsWith(normQ) ||
        normTc.startsWith(normQ) ||
        (normEn.isNotEmpty && normEn.startsWith(normQ))) {
      baseScore = 80;
    }
    // Alias expansion check
    else {
      final aliases = ChineseConverter.getAliases(trimmed);
      for (final alias in aliases) {
        final normAlias = ChineseConverter.normalize(alias);
        if (normAlias.isNotEmpty &&
            (normJp.contains(normAlias) ||
                normCn.contains(normAlias) ||
                normTc.contains(normAlias) ||
                (normEn.isNotEmpty && normEn.contains(normAlias)))) {
          baseScore = 75;
          break;
        }
      }
    }

    // Substring match
    if (baseScore == 0) {
      if (normJp.contains(normQ) ||
          normCn.contains(normQ) ||
          normTc.contains(normQ) ||
          (normEn.isNotEmpty && normEn.contains(normQ))) {
        baseScore = 50;
      }
    }

    // City / Region match (e.g. searching "京都" or "宇治")
    if (baseScore == 0 && city != null && city!.isNotEmpty) {
      final normCity = ChineseConverter.normalize(city!);
      if (normCity.contains(normQ) || normQ.contains(normCity)) {
        baseScore = 40;
      }
    }

    if (baseScore == 0) return 0;

    // Spot count bonus (prioritize works with more pilgrimage spots)
    final spotBonus = math.min(spotCount, 25);
    final hasSpotsBonus = spotCount > 0 ? 5 : 0;

    return baseScore + spotBonus + hasSpotsBonus;
  }

  /// Converts this indexed work into a [BangumiSubject] compatible with
  /// UI components like [AnitabiImportScreen].
  BangumiSubject toBangumiSubject() {
    final summaryText = [
      if (city != null && city!.isNotEmpty) '取景地: $city',
      '共 $spotCount 個巡禮點',
    ].join(' · ');

    return BangumiSubject(
      id: bangumiId,
      name: japaneseTitle,
      nameCn: traditionalTitle.isNotEmpty ? traditionalTitle : chineseTitle,
      imageUrl: coverUrl,
      summary: summaryText,
      platform: platform ?? 'TV',
    );
  }

  @override
  String toString() =>
      'IndexedAnimeWork(id: $bangumiId, jp: $japaneseTitle, cn: $chineseTitle, tc: $traditionalTitle, spots: $spotCount, city: $city)';
}
