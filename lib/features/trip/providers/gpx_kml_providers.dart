import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gpx_kml_porter_service.dart';

/// Provider for [GpxKmlPorterService].
final gpxKmlPorterServiceProvider = Provider<GpxKmlPorterService>((ref) {
  return const GpxKmlPorterService();
});
