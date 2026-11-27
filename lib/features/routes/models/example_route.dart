// An example route: one of our own trips made into a public route that
// anyone can open (`/t/<id>`) and copy into a private trip. Each route is a
// JSON file in `web/routes/`, served by Hosting next to the web app, and
// listed in `web/routes/index.json` (roadmap v0.5.0, part C).
//
// A route has its groups (the trip's days, without dates), their places in
// order, and each place's frames with where they're shot from. It never has
// dates, members, photos or private notes.

/// The format version a route file is written in. A file with a newer one
/// is refused rather than read wrong.
const exampleRouteFormat = 1;

/// The longest id a route takes: it's a path segment (`/t/kansai-uji`).
const maxExampleRouteIdLength = 60;

final _routeId = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Whether [id] can name a route: lower-case letters, digits and single
/// hyphens, at most [maxExampleRouteIdLength] long.
bool isExampleRouteId(String id) => id.length <= maxExampleRouteIdLength && _routeId.hasMatch(id);

/// A route file that can't be read.
class ExampleRouteFormatException implements Exception {
  final String message;
  const ExampleRouteFormatException(this.message);
  @override
  String toString() => 'ExampleRouteFormatException: $message';
}

/// Where a frame is shot from.
class RouteShot {
  final double lat;
  final double lng;

  /// The compass direction the shot faces, in degrees from north.
  final double? heading;

  /// A short name for the spot ("三の間").
  final String? note;

  const RouteShot({required this.lat, required this.lng, this.heading, this.note});

  factory RouteShot.fromJson(Map<String, dynamic> json) => RouteShot(
        lat: _double(json, 'lat'),
        lng: _double(json, 'lng'),
        heading: _doubleOrNull(json, 'heading'),
        note: _stringOrNull(json, 'note'),
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (heading != null) 'heading': heading,
        if (note != null) 'note': note,
      };
}

/// A frame of a place: an anime scene, with its picture when it can be
/// shown (an Anitabi image), and where it's shot from.
class RouteFrame {
  /// The picture's link, or null for a frame shown by its spot only (one
  /// whose picture is ours to keep, not to publish).
  final String? image;

  final String? anime;
  final String? episode;

  /// Where in the episode, in seconds.
  final int? seconds;

  final RouteShot? shot;

  /// Where the frame comes from ("anitabi") and its page.
  final String? source;
  final String? sourceUrl;

  const RouteFrame({this.image, this.anime, this.episode, this.seconds, this.shot, this.source, this.sourceUrl});

  factory RouteFrame.fromJson(Map<String, dynamic> json) {
    final image = _stringOrNull(json, 'image');
    if (image != null && !_isHttps(image)) throw ExampleRouteFormatException('a frame image must be an https link: $image');
    final shot = json['shot'];
    return RouteFrame(
      image: image,
      anime: _stringOrNull(json, 'anime'),
      episode: _stringOrNull(json, 'episode'),
      seconds: _intOrNull(json, 'seconds'),
      shot: shot == null ? null : RouteShot.fromJson(_map(shot, 'shot')),
      source: _stringOrNull(json, 'source'),
      sourceUrl: _stringOrNull(json, 'sourceUrl'),
    );
  }

  Map<String, dynamic> toJson() => {
        if (image != null) 'image': image,
        if (anime != null) 'anime': anime,
        if (episode != null) 'episode': episode,
        if (seconds != null) 'seconds': seconds,
        if (shot != null) 'shot': shot!.toJson(),
        if (source != null) 'source': source,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      };
}

/// A place of the route, with its frames.
class RoutePlace {
  final String name;
  final double lat;
  final double lng;

  /// What's worth knowing there (open hours, where to stand), never a
  /// member's private note.
  final String? about;

  final List<RouteFrame> frames;

  const RoutePlace({required this.name, required this.lat, required this.lng, this.about, this.frames = const []});

  factory RoutePlace.fromJson(Map<String, dynamic> json) => RoutePlace(
        name: _string(json, 'name'),
        lat: _double(json, 'lat'),
        lng: _double(json, 'lng'),
        about: _stringOrNull(json, 'about'),
        frames: [for (final f in _list(json, 'frames')) RouteFrame.fromJson(_map(f, 'frame'))],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        if (about != null) 'about': about,
        'frames': [for (final f in frames) f.toJson()],
      };

  /// The frames that have a picture.
  Iterable<RouteFrame> get pictured => frames.where((f) => f.image != null);
}

/// A group of the route's places, from one of the trip's days.
class RouteGroup {
  /// The day's name ("宇治"), or null for an untitled one.
  final String? title;
  final List<RoutePlace> places;

  const RouteGroup({this.title, this.places = const []});

  factory RouteGroup.fromJson(Map<String, dynamic> json) => RouteGroup(
        title: _stringOrNull(json, 'title'),
        places: [for (final p in _list(json, 'places')) RoutePlace.fromJson(_map(p, 'place'))],
      );

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        'places': [for (final p in places) p.toJson()],
      };
}

/// Who a route's data comes from, and under which licence.
class RouteCredit {
  final String name;
  final String? url;
  final String? license;

  const RouteCredit({required this.name, this.url, this.license});

  /// Anitabi's spots and frames are CC BY-NC-SA 4.0.
  static const anitabi = RouteCredit(name: 'Anitabi', url: 'https://www.anitabi.cn', license: 'CC BY-NC-SA 4.0');

  factory RouteCredit.fromJson(Map<String, dynamic> json) =>
      RouteCredit(name: _string(json, 'name'), url: _stringOrNull(json, 'url'), license: _stringOrNull(json, 'license'));

  Map<String, dynamic> toJson() => {
        'name': name,
        if (url != null) 'url': url,
        if (license != null) 'license': license,
      };
}

/// One example route.
class ExampleRoute {
  final String id;
  final String title;
  final String? description;
  final List<String> anime;
  final String? area;

  /// When it was last changed, as `yyyy-mm-dd`.
  final String? updated;

  final List<RouteGroup> groups;
  final List<RouteCredit> credits;

  const ExampleRoute({
    required this.id,
    required this.title,
    this.description,
    this.anime = const [],
    this.area,
    this.updated,
    this.groups = const [],
    this.credits = const [],
  });

  factory ExampleRoute.fromJson(Map<String, dynamic> json) {
    final format = _intOrNull(json, 'format') ?? 0;
    if (format < 1 || format > exampleRouteFormat) throw ExampleRouteFormatException('unknown format $format');
    final id = _string(json, 'id');
    if (!isExampleRouteId(id)) throw ExampleRouteFormatException('bad route id "$id"');
    return ExampleRoute(
      id: id,
      title: _string(json, 'title'),
      description: _stringOrNull(json, 'description'),
      anime: [for (final a in _list(json, 'anime')) if (a is String && a.trim().isNotEmpty) a.trim()],
      area: _stringOrNull(json, 'area'),
      updated: _stringOrNull(json, 'updated'),
      groups: [for (final g in _list(json, 'groups')) RouteGroup.fromJson(_map(g, 'group'))],
      credits: [for (final c in _list(json, 'credits')) RouteCredit.fromJson(_map(c, 'credit'))],
    );
  }

  Map<String, dynamic> toJson() => {
        'format': exampleRouteFormat,
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'anime': anime,
        if (area != null) 'area': area,
        if (updated != null) 'updated': updated,
        'groups': [for (final g in groups) g.toJson()],
        'credits': [for (final c in credits) c.toJson()],
      };

  Iterable<RoutePlace> get places => groups.expand((g) => g.places);
  int get placeCount => places.length;
  int get frameCount => places.fold(0, (n, p) => n + p.frames.length);

  /// The first picture, for the list and the link preview.
  String? get cover => places.expand((p) => p.pictured).firstOrNull?.image;

  /// Its line in `index.json`.
  ExampleRouteSummary get summary => ExampleRouteSummary(
        id: id,
        title: title,
        description: description,
        anime: anime,
        area: area,
        places: placeCount,
        frames: frameCount,
        cover: cover,
      );
}

/// A route as `index.json` lists it, enough for the list of routes.
class ExampleRouteSummary {
  final String id;
  final String title;
  final String? description;
  final List<String> anime;
  final String? area;
  final int places;
  final int frames;
  final String? cover;

  const ExampleRouteSummary({
    required this.id,
    required this.title,
    this.description,
    this.anime = const [],
    this.area,
    this.places = 0,
    this.frames = 0,
    this.cover,
  });

  factory ExampleRouteSummary.fromJson(Map<String, dynamic> json) {
    final id = _string(json, 'id');
    if (!isExampleRouteId(id)) throw ExampleRouteFormatException('bad route id "$id"');
    final cover = _stringOrNull(json, 'cover');
    return ExampleRouteSummary(
      id: id,
      title: _string(json, 'title'),
      description: _stringOrNull(json, 'description'),
      anime: [for (final a in _list(json, 'anime')) if (a is String && a.trim().isNotEmpty) a.trim()],
      area: _stringOrNull(json, 'area'),
      places: _intOrNull(json, 'places') ?? 0,
      frames: _intOrNull(json, 'frames') ?? 0,
      cover: cover != null && _isHttps(cover) ? cover : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (description != null) 'description': description,
        'anime': anime,
        if (area != null) 'area': area,
        'places': places,
        'frames': frames,
        if (cover != null) 'cover': cover,
      };
}

/// `index.json`: every route, in the order the list shows them.
List<ExampleRouteSummary> exampleRouteIndexFromJson(Map<String, dynamic> json) {
  final format = _intOrNull(json, 'format') ?? 0;
  if (format < 1 || format > exampleRouteFormat) throw ExampleRouteFormatException('unknown format $format');
  return [for (final r in _list(json, 'routes')) ExampleRouteSummary.fromJson(_map(r, 'route'))];
}

Map<String, dynamic> exampleRouteIndexToJson(List<ExampleRouteSummary> routes) => {
      'format': exampleRouteFormat,
      'routes': [for (final r in routes) r.toJson()],
    };

// ---- reading JSON

bool _isHttps(String url) => Uri.tryParse(url)?.scheme == 'https';

Map<String, dynamic> _map(Object? v, String what) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  throw ExampleRouteFormatException('$what is not an object');
}

List<Object?> _list(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return const [];
  if (v is List) return v;
  throw ExampleRouteFormatException('$key is not a list');
}

String _string(Map<String, dynamic> json, String key) {
  final v = _stringOrNull(json, key);
  if (v == null) throw ExampleRouteFormatException('$key is missing');
  return v;
}

String? _stringOrNull(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is! String) throw ExampleRouteFormatException('$key is not text');
  final t = v.trim();
  return t.isEmpty ? null : t;
}

double _double(Map<String, dynamic> json, String key) {
  final v = _doubleOrNull(json, key);
  if (v == null) throw ExampleRouteFormatException('$key is missing');
  return v;
}

double? _doubleOrNull(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is! num || !v.isFinite) throw ExampleRouteFormatException('$key is not a number');
  final d = v.toDouble();
  if (key == 'lat' && (d < -90 || d > 90)) throw ExampleRouteFormatException('lat $d is out of range');
  if (key == 'lng' && (d < -180 || d > 180)) throw ExampleRouteFormatException('lng $d is out of range');
  return d;
}

int? _intOrNull(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num && v.isFinite && v == v.roundToDouble()) return v.toInt();
  throw ExampleRouteFormatException('$key is not a whole number');
}
