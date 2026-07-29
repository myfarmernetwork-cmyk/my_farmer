import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/nirs_monitoring_config.dart';
import '../../models/nirs_ndvi_level.dart';
import '../../models/nirs_scan_result.dart';
import 'nirs_data_provider.dart';

/// Deterministička simulacija — ista parcela daje iste vrijednosti dok ne uključite API.
class SimulatedNirsProvider implements NirsDataProvider {
  @override
  Future<NirsScanResult> fetchForParcel(List<LatLng> points) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final seed = _stableSeed(points);
    final random = math.Random(seed);

    final ndvi = (0.38 + random.nextDouble() * 0.46).clamp(0.35, 0.88);
    final moisture = (42 + random.nextDouble() * 38).clamp(35, 92);
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
      source: NirsMonitoringConfig.simulationSourceLabel,
      isSimulated: true,
    );
  }

  int _stableSeed(List<LatLng> points) {
    if (points.isEmpty) return 42;

    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    return Object.hash(
      (lat * 100000).round(),
      (lng * 100000).round(),
      points.length,
    );
  }
}
