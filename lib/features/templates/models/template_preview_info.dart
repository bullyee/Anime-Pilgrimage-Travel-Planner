import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolved preview metadata for a public trip template.
///
/// Suitable for web preview rendering, social card scrapers, and in-app resolution dialogs.
class TemplatePreviewInfo {
  final String code;
  final String templateId;
  final String title;
  final String? description;
  final String authorName;
  final int dayCount;
  final int stopCount;
  final String? coverImageUrl;
  final List<String> animeNames;
  final List<String> areas;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TemplatePreviewInfo({
    required this.code,
    required this.templateId,
    required this.title,
    this.description,
    this.authorName = 'Pilgrim',
    required this.dayCount,
    required this.stopCount,
    this.coverImageUrl,
    this.animeNames = const [],
    this.areas = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Canonical public web URL for this template.
  String get webUrl => 'https://trip-planner-2775c.web.app/t/$code';

  /// Deep link URI scheme for launching directly in the mobile app.
  String get appDeepLink => 'tripplanner://template/$code';

  Map<String, dynamic> toMap() => {
        'code': code,
        'templateId': templateId,
        'title': title,
        if (description != null) 'description': description,
        'authorName': authorName,
        'dayCount': dayCount,
        'stopCount': stopCount,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        'animeNames': animeNames,
        'areas': areas,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory TemplatePreviewInfo.fromMap(
    Map<String, dynamic> map, {
    String? code,
    String? templateId,
  }) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final animeList = <String>[];
    final areaList = <String>[];
    String? cover;

    // Extract stops metadata if full template snapshot is present
    final rawStops = map['stops'];
    if (rawStops is List) {
      for (final s in rawStops) {
        if (s is Map<String, dynamic>) {
          if (cover == null && s['coverRemoteUrl'] is String) {
            cover = s['coverRemoteUrl'] as String;
          }
          final area = s['area'];
          if (area is String && area.isNotEmpty && !areaList.contains(area)) {
            areaList.add(area);
          }
          final labels = s['labels'];
          if (labels is List) {
            for (final l in labels) {
              if (l is Map<String, dynamic> &&
                  l['kind'] == 'anime' &&
                  l['name'] is String) {
                final aName = l['name'] as String;
                if (!animeList.contains(aName)) animeList.add(aName);
              }
            }
          }
        }
      }
    }

    // Direct metadata fields if stored in summary
    if (map['animeNames'] is List) {
      for (final a in map['animeNames'] as List) {
        if (a is String && !animeList.contains(a)) animeList.add(a);
      }
    }
    if (map['areas'] is List) {
      for (final a in map['areas'] as List) {
        if (a is String && !areaList.contains(a)) areaList.add(a);
      }
    }

    return TemplatePreviewInfo(
      code: code ?? (map['code'] as String? ?? ''),
      templateId: templateId ?? (map['templateId'] as String? ?? map['id'] as String? ?? ''),
      title: map['title'] as String? ?? 'Trip Template',
      description: map['description'] as String?,
      authorName: map['authorName'] as String? ?? 'Pilgrim',
      dayCount: (map['dayCount'] as num?)?.toInt() ?? 1,
      stopCount: (map['stopCount'] as num?)?.toInt() ?? 0,
      coverImageUrl: cover ?? (map['coverImageUrl'] as String?),
      animeNames: animeList,
      areas: areaList,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  @override
  String toString() =>
      'TemplatePreviewInfo($code: "$title" by $authorName, $dayCount days, $stopCount stops)';
}
