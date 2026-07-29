import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/nirs_monitoring_config.dart';
import '../../models/nirs_scan_result.dart';
import 'nirs_data_provider.dart';
import 'sentinel2_nirs_provider.dart';
import 'simulated_nirs_provider.dart';

/// Jedinstvena ulazna točka za NIRS — bira live API ili simulaciju.
class NirsMonitoringService {
  NirsMonitoringService({
    NirsDataProvider? liveProvider,
    NirsDataProvider? simulationProvider,
  })  : _liveProvider = liveProvider ?? Sentinel2NirsProvider(),
        _simulationProvider = simulationProvider ?? SimulatedNirsProvider();

  final NirsDataProvider _liveProvider;
  final NirsDataProvider _simulationProvider;

  Future<NirsScanResult> analyzeParcel(List<LatLng> points) async {
    if (NirsMonitoringConfig.hasLiveApi) {
      try {
        return await _liveProvider.fetchForParcel(points);
      } catch (error, stack) {
        if (kReleaseMode) {
          rethrow;
        }
        debugPrint('Sentinel-2 NIRS failed, falling back to simulation: $error');
        debugPrint('$stack');
      }
    }

    if (kReleaseMode && NirsMonitoringConfig.useLiveSentinelApi) {
      throw StateError(
        'NIRS live API nije konfiguriran u release buildu.',
      );
    }

    return _simulationProvider.fetchForParcel(points);
  }

  bool get isLiveApiConfigured => NirsMonitoringConfig.hasLiveApi;
}

final nirsMonitoringServiceProvider = Provider<NirsMonitoringService>(
  (ref) => NirsMonitoringService(),
);
