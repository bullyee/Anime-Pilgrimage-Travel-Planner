// The page a route's link serves (`/t/<id>/index.html`): the web app's own
// `index.html`, with the route's title, description and first picture as
// link-preview tags. Threads, X and PTT read those without running the app;
// a person opening the link gets the web app, which shows the route.
// Written after `flutter build web` by `tool/route_pages.dart`. Pure Dart, so
// the tool can run it without Flutter.

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// [indexHtml] with its title and description replaced by [title] and
/// [description], and OpenGraph and Twitter tags for [url] and [image]
/// added to its head.
String routePageHtml(
  String indexHtml, {
  required String title,
  required String url,
  String? description,
  String? image,
  String siteName = 'Trip Planner',
}) {
  final t = _escape(title);
  final d = description == null ? null : _escape(description.replaceAll(RegExp(r'\s+'), ' ').trim());
  final tags = [
    '<meta property="og:type" content="website">',
    '<meta property="og:site_name" content="${_escape(siteName)}">',
    '<meta property="og:title" content="$t">',
    '<meta property="og:url" content="${_escape(url)}">',
    if (d != null) '<meta property="og:description" content="$d">',
    if (image != null) '<meta property="og:image" content="${_escape(image)}">',
    '<meta name="twitter:card" content="${image == null ? 'summary' : 'summary_large_image'}">',
    '<meta name="twitter:title" content="$t">',
    if (d != null) '<meta name="twitter:description" content="$d">',
    if (image != null) '<meta name="twitter:image" content="${_escape(image)}">',
    '<link rel="canonical" href="${_escape(url)}">',
  ].map((tag) => '  $tag').join('\n');

  var html = indexHtml.replaceFirst(RegExp(r'<title>[\s\S]*?</title>'), '<title>$t</title>');
  if (d != null) {
    html = html.replaceFirst(RegExp(r'<meta name="description"[^>]*>'), '<meta name="description" content="$d">');
  }
  final head = html.indexOf('</head>');
  if (head < 0) throw const FormatException('index.html has no </head>');
  return '${html.substring(0, head)}$tags\n${html.substring(head)}';
}
