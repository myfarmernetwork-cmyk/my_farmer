import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../config/nirs_monitoring_config.dart';
import '../../features/land/utils/polygon_geo_utils.dart';
import '../../models/nirs_ndvi_level.dart';
import '../../models/nirs_scan_result.dart';
import 'nirs_data_provider.dart';

/// Live Sentinel-2 NIRS/NDVI — spreman za vaš backend proxy.
///
/// Očekivani JSON odgovor:
/// ```json
/// {
///   "ndviMean": 0.72,
///   "moistureIndex": 58.3,
///   "captureDate": "2026-07-19T12:00:00Z"
/// }
/// ```
class Sentinel2NirsProvider implements NirsDataProvider {
  Sentinel2NirsProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<NirsScanResult> fetchForParcel(List<LatLng> points) async {
    if (!NirsMonitoringConfig.hasLiveApi) {
      throw StateError(
        'Sentinel-2 API nije konfiguriran. '
        'Postavite NIRS_USE_LIVE_API, SENTINEL2_API_BASE_URL i SENTINEL2_API_KEY.',
      );
    }

    final bounds = PolygonGeoUtils.computeBounds(points);
    final uri = Uri.parse(NirsMonitoringConfig.resolvedApiBaseUrl.trim());

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${NirsMonitoringConfig.sentinelApiKey}',
          },
          body: jsonEncode({
            'minLat': bounds.southwest.latitude,
            'minLng': bounds.southwest.longitude,
            'maxLat': bounds.northeast.latitude,
            'maxLng': bounds.northeast.longitude,
            'points': points
                .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Sentinel-2 API HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final ndvi = (data['ndviMean'] as num?)?.toDouble();
    final moisture = (data['moistureIndex'] as num?)?.toDouble();
    if (ndvi == null || moisture == null) {
      throw FormatException('Sentinel-2 API: nedostaju ndviMean ili moistureIndex');
    }

    final captureRaw = data['captureDate']?.toString();
    final imageryCaptureDate =
        captureRaw != null ? DateTime.tryParse(captureRaw) : null;
    final cloudCover = (data['cloudCoverPercent'] as num?)?.toDouble();

    final ndviRounded = double.parse(ndvi.toStringAsFixed(3));
    final moistureRounded = double.parse(moisture.toStringAsFixed(1));

    return NirsScanResult(
      ndviMean: ndviRounded,
      moistureIndex: moistureRounded,
      healthKey: NirsNdviLevel.healthKeyFor(ndviRounded),
      adviceKey: NirsNdviLevel.adviceKeyFor(
        ndvi: ndviRounded,
        moistureIndex: moistureRounded,
      ),
      scannedAt: DateTime.now(),
      imageryCaptureDate: imageryCaptureDate,
      cloudCoverPercent: cloudCover,
      source: data['source']?.toString() ?? NirsMonitoringConfig.liveSourceLabel,
      isSimulated: false,
    );
  }
}
