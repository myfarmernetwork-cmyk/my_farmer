import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/nirs_scan_result.dart';

/// Sučelje za dohvat NIRS/NDVI — zamijenite implementaciju live API-jem.
abstract class NirsDataProvider {
  Future<NirsScanResult> fetchForParcel(List<LatLng> points);
}
