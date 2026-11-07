import 'package:cloud_firestore/cloud_firestore.dart';

/// Single day in a trip template.
/// Strips specific calendar dates (`startDate`, `pinnedDate`) and backup tags.
class TemplateDay {
  final int dayNumber;
  final String? title;
  final String? note;

  const TemplateDay({
    required this.dayNumber,
    this.title,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'dayNumber': dayNumber,
        if (title != null) 'title': title,
        if (note != null) 'note': note,
      };

  factory TemplateDay.fromMap(Map<String, dynamic> map) {
    return TemplateDay(
      dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 1,
      title: map['title'] as String?,
      note: map['note'] as String?,
    );
  }
}

/// Tag, anime title, or region label associated with a spot.
class TemplateLabel {
  final String name;
  final String kind;

  const TemplateLabel({
    required this.name,
    required this.kind,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'kind': kind,
      };

  factory TemplateLabel.fromMap(Map<String, dynamic> map) {
    return TemplateLabel(
      name: map['name'] as String? ?? '',
      kind: map['kind'] as String? ?? 'tag',
    );
  }
}

/// Anime reference frame for camera overlay comparison.
/// Strips device local file paths, only keeping public remote URLs.
class TemplateReferenceImage {
  final String? remoteUrl;
  final String? source;
  final String? sourceUrl;
  final String? episode;
  final int? timestampS;

  const TemplateReferenceImage({
    this.remoteUrl,
    this.source,
    this.sourceUrl,
    this.episode,
    this.timestampS,
  });

  Map<String, dynamic> toMap() => {
        if (remoteUrl != null) 'remoteUrl': remoteUrl,
        if (source != null) 'source': source,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (episode != null) 'episode': episode,
        if (timestampS != null) 'timestampS': timestampS,
      };

  factory TemplateReferenceImage.fromMap(Map<String, dynamic> map) {
    return TemplateReferenceImage(
      remoteUrl: map['remoteUrl'] as String?,
      source: map['source'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
      episode: map['episode'] as String?,
      timestampS: (map['timestampS'] as num?)?.toInt(),
    );
  }
}

/// A stop / spot included in the template snapshot.
/// Strips personal photos, visit history, and local file paths.
class TemplateStop {
  final String id;
  final String placeKey;
  final String name;
  final double lat;
  final double lng;
  final String? description;
  final String? address;
  final String? businessHours;
  final String? contactInfo;
  final String? accessTips;
  final String? links;
  final String? coverRemoteUrl;
  final String? source;
  final String? sourceUrl;
  final String? area;
  final String? note;
  final List<TemplateLabel> labels;
  final List<TemplateReferenceImage> referenceImages;

  const TemplateStop({
    required this.id,
    required this.placeKey,
    required this.name,
    required this.lat,
    required this.lng,
    this.description,
    this.address,
    this.businessHours,
    this.contactInfo,
    this.accessTips,
    this.links,
    this.coverRemoteUrl,
    this.source,
    this.sourceUrl,
    this.area,
    this.note,
    this.labels = const [],
    this.referenceImages = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'placeKey': placeKey,
        'name': name,
        'lat': lat,
        'lng': lng,
        if (description != null) 'description': description,
        if (address != null) 'address': address,
        if (businessHours != null) 'businessHours': businessHours,
        if (contactInfo != null) 'contactInfo': contactInfo,
        if (accessTips != null) 'accessTips': accessTips,
        if (links != null) 'links': links,
        if (coverRemoteUrl != null) 'coverRemoteUrl': coverRemoteUrl,
        if (source != null) 'source': source,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (area != null) 'area': area,
        if (note != null) 'note': note,
        if (labels.isNotEmpty) 'labels': labels.map((l) => l.toMap()).toList(),
        if (referenceImages.isNotEmpty)
          'referenceImages': referenceImages.map((r) => r.toMap()).toList(),
      };

  factory TemplateStop.fromMap(Map<String, dynamic> map) {
    return TemplateStop(
      id: map['id'] as String? ?? '',
      placeKey: map['placeKey'] as String? ?? '',
      name: map['name'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      address: map['address'] as String?,
      businessHours: map['businessHours'] as String?,
      contactInfo: map['contactInfo'] as String?,
      accessTips: map['accessTips'] as String?,
      links: map['links'] as String?,
      coverRemoteUrl: map['coverRemoteUrl'] as String?,
      source: map['source'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
      area: map['area'] as String?,
      note: map['note'] as String?,
      labels: (map['labels'] as List<dynamic>?)
              ?.map((e) => TemplateLabel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      referenceImages: (map['referenceImages'] as List<dynamic>?)
              ?.map((e) =>
                  TemplateReferenceImage.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// A scheduled stop inside a relative day block.
class TemplateScheduleItem {
  final int dayNumber;
  final String stopId;
  final String sortKey;
  final int stayMinutes;
  final int transitMinutes;
  final int? fixedTime;
  final String status;

  const TemplateScheduleItem({
    required this.dayNumber,
    required this.stopId,
    required this.sortKey,
    this.stayMinutes = 60,
    this.transitMinutes = 0,
    this.fixedTime,
    this.status = 'planned',
  });

  Map<String, dynamic> toMap() => {
        'dayNumber': dayNumber,
        'stopId': stopId,
        'sortKey': sortKey,
        'stayMinutes': stayMinutes,
        'transitMinutes': transitMinutes,
        if (fixedTime != null) 'fixedTime': fixedTime,
        'status': status,
      };

  factory TemplateScheduleItem.fromMap(Map<String, dynamic> map) {
    return TemplateScheduleItem(
      dayNumber: (map['dayNumber'] as num?)?.toInt() ?? 1,
      stopId: map['stopId'] as String? ?? '',
      sortKey: map['sortKey'] as String? ?? '',
      stayMinutes: (map['stayMinutes'] as num?)?.toInt() ?? 60,
      transitMinutes: (map['transitMinutes'] as num?)?.toInt() ?? 0,
      fixedTime: (map['fixedTime'] as num?)?.toInt(),
      status: map['status'] as String? ?? 'planned',
    );
  }
}

/// Public Trip Template snapshot for sharing and one-click cloning.
class TripTemplate {
  final String id;
  final String code;
  final String title;
  final String? description;
  final String authorName;
  final int dayCount;
  final int stopCount;
  final List<TemplateDay> days;
  final List<TemplateStop> stops;
  final List<TemplateScheduleItem> scheduleItems;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripTemplate({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    this.authorName = 'Pilgrim',
    required this.dayCount,
    required this.stopCount,
    this.days = const [],
    this.stops = const [],
    this.scheduleItems = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'title': title,
        if (description != null) 'description': description,
        'authorName': authorName,
        'dayCount': dayCount,
        'stopCount': stopCount,
        'days': days.map((d) => d.toMap()).toList(),
        'stops': stops.map((s) => s.toMap()).toList(),
        'scheduleItems': scheduleItems.map((i) => i.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  factory TripTemplate.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return TripTemplate(
      id: docId ?? (map['id'] as String? ?? ''),
      code: map['code'] as String? ?? '',
      title: map['title'] as String? ?? 'Trip Template',
      description: map['description'] as String?,
      authorName: map['authorName'] as String? ?? 'Pilgrim',
      dayCount: (map['dayCount'] as num?)?.toInt() ?? 1,
      stopCount: (map['stopCount'] as num?)?.toInt() ?? 0,
      days: (map['days'] as List<dynamic>?)
              ?.map((e) => TemplateDay.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      stops: (map['stops'] as List<dynamic>?)
              ?.map((e) => TemplateStop.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      scheduleItems: (map['scheduleItems'] as List<dynamic>?)
              ?.map((e) =>
                  TemplateScheduleItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }
}
