import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/nirs_monitoring_config.dart';
import '../features/land/models/land_parcel.dart';
import '../features/land/repositories/land_parcel_repository.dart';
import '../features/land/utils/polygon_geo_utils.dart';
import '../models/nirs_scan_result.dart';
import '../services/nirs_monitoring_flow.dart';
import '../utils/nirs_labels.dart';
import '../widgets/nirs_field_advice_banner.dart';
import '../widgets/nirs_ndvi_legend.dart';
import '../widgets/nirs_scan_comparison.dart';

class LandParcelDetailScreen extends ConsumerStatefulWidget {
  const LandParcelDetailScreen({
    super.key,
    required this.parcel,
    this.initialScanResult,
  });

  final LandParcel parcel;
  final NirsScanResult? initialScanResult;

  @override
  ConsumerState<LandParcelDetailScreen> createState() =>
      _LandParcelDetailScreenState();
}

class _LandParcelDetailScreenState extends ConsumerState<LandParcelDetailScreen> {
  final LandParcelRepository _repository = LandParcelRepository();
  GoogleMapController? _mapController;
  NirsScanResult? _latestScan;
  List<NirsScanResult> _history = const [];
  bool _runningScan = false;

  LandParcel get _parcel => widget.parcel;

  @override
  void initState() {
    super.initState();
    _latestScan = widget.initialScanResult ?? _parcel.lastNirsScan;
  }

  Future<void> _fitMapToParcel() async {
    final controller = _mapController;
    if (controller == null || _parcel.points.length < 3) return;

    final bounds = PolygonGeoUtils.computeBounds(_parcel.points);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 48),
    );
  }

  Future<void> _runNirsScan() async {
    if (_runningScan || _parcel.points.length < 3) return;

    setState(() => _runningScan = true);
    try {
      final result = await NirsMonitoringFlow.confirmAndRun(
        context: context,
        ref: ref,
        points: _parcel.points,
        parcelId: _parcel.id.isEmpty ? null : _parcel.id,
        repository: _repository,
      );

      if (!mounted || result == null) return;

      setState(() {
        _latestScan = result;
        _history = [result, ..._history.where((s) => s.id != result.id)];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nirsLabel(context, 'land_nirs_load_success')),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningScan = false);
    }
  }

  Set<Polygon> _buildPolygons() {
    if (_parcel.points.length < 3) return {};

    final scan = _latestScan;
    return {
      Polygon(
        polygonId: PolygonId(_parcel.id.isEmpty ? 'preview' : _parcel.id),
        points: List<LatLng>.from(_parcel.points),
        strokeColor: scan?.ndviColor ?? Colors.green.shade700,
        strokeWidth: 3,
        fillColor: scan?.polygonFillColor ??
            Colors.green.withValues(alpha: 0.28),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final centroid = PolygonGeoUtils.computeCentroid(_parcel.points);
    final hasParcelId = _parcel.id.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_parcel.name),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: centroid,
                    zoom: 17,
                  ),
                  mapType: MapType.satellite,
                  polygons: _buildPolygons(),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) async {
                    _mapController = controller;
                    await _fitMapToParcel();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                elevation: 8,
                child: hasParcelId
                    ? StreamBuilder<List<NirsScanResult>>(
                        stream: _repository.watchNirsHistory(_parcel.id),
                        builder: (context, snapshot) {
                          final history = snapshot.data ?? _history;
                          final latest = _latestScan ??
                              (history.isNotEmpty ? history.first : null);
                          final previous =
                              history.length > 1 ? history[1] : null;

                          return _buildDetailsPanel(
                            scan: latest,
                            previousScan: previous,
                            history: history,
                          );
                        },
                      )
                    : _buildDetailsPanel(
                        scan: _latestScan,
                        previousScan: null,
                        history: _history,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel({
    required NirsScanResult? scan,
    required NirsScanResult? previousScan,
    required List<NirsScanResult> history,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMetricsRow(),
          const SizedBox(height: 14),
          if (scan != null) ...[
            const NirsNdviLegend(),
            const SizedBox(height: 12),
            if (scan.isSimulated || !NirsMonitoringConfig.hasLiveApi)
              _buildSimulationBadge(),
            if (scan.isSimulated || !NirsMonitoringConfig.hasLiveApi)
              const SizedBox(height: 10),
            if (scan.isImageryStale) ...[
              _buildStaleImageryBanner(scan),
              const SizedBox(height: 10),
            ],
            _buildNirsResults(scan),
            const SizedBox(height: 12),
            NirsFieldAdviceBanner(scan: scan),
            if (previousScan != null) ...[
              const SizedBox(height: 12),
              NirsScanComparisonCard(latest: scan, previous: previousScan),
            ],
            if (history.length > 1) ...[
              const SizedBox(height: 14),
              NirsScanHistoryList(scans: history),
            ],
            const SizedBox(height: 14),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nirsLabel(context, 'land_nirs_no_scan_yet'),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          FilledButton.icon(
            onPressed: _runningScan ? null : _runNirsScan,
            icon: _runningScan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('🍃', style: TextStyle(fontSize: 16)),
            label: Text(
              scan == null
                  ? nirsLabel(context, 'land_nirs_run_scan')
                  : nirsLabel(context, 'land_nirs_run_again'),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaleImageryBanner(NirsScanResult scan) {
    final days = scan.imageryAgeDays ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 16, color: Colors.orange.shade900),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              nirsLabelArgs(context, 'land_nirs_imagery_stale', {
                'days': '$days',
              }),
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science_outlined, size: 16, color: Colors.amber.shade900),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              nirsLabel(context, 'land_nirs_simulation_badge'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _MetricChip(
            label: 'land_area_m2'.tr(),
            value: '${_parcel.areaSquareMeters.toStringAsFixed(0)} m²',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricChip(
            label: 'land_area_ha'.tr(),
            value: _parcel.areaHectares.toStringAsFixed(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricChip(
            label: 'land_perimeter'.tr(),
            value: '${_parcel.perimeterMeters.toStringAsFixed(0)} m',
          ),
        ),
      ],
    );
  }

  Widget _buildNirsResults(NirsScanResult scan) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scan.ndviColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scan.ndviColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.satellite_alt, color: scan.ndviColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nirsLabel(context, 'land_nirs_results_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResultLine(
            label: nirsLabel(context, 'land_nirs_ndvi_mean'),
            value: scan.ndviMean.toStringAsFixed(3),
            valueColor: scan.ndviColor,
          ),
          const SizedBox(height: 8),
          _ResultLine(
            label: nirsLabel(context, 'land_nirs_moisture'),
            value: '${scan.moistureIndex.toStringAsFixed(1)} %',
          ),
          const SizedBox(height: 8),
          _ResultLine(
            label: nirsLabel(context, 'land_nirs_health'),
            value: nirsLabel(context, scan.healthKey),
            valueColor: scan.ndviColor,
          ),
          const SizedBox(height: 8),
          _ResultLine(
            label: nirsLabel(context, 'land_nirs_scan_date'),
            value: DateFormat.yMMMd(context.locale.toString())
                .add_Hm()
                .format(scan.displayImageryDate),
          ),
          if (scan.imageryCaptureDate != null &&
              scan.scannedAt.difference(scan.imageryCaptureDate!).inHours.abs() >
                  1) ...[
            const SizedBox(height: 8),
            _ResultLine(
              label: nirsLabel(context, 'land_nirs_analysis_date'),
              value: DateFormat.yMMMd(context.locale.toString())
                  .add_Hm()
                  .format(scan.scannedAt),
            ),
          ],
          if (scan.cloudCoverPercent != null) ...[
            const SizedBox(height: 8),
            _ResultLine(
              label: nirsLabel(context, 'land_nirs_cloud_cover'),
              value: nirsLabelArgs(context, 'land_nirs_cloud_cover_value', {
                'percent': scan.cloudCoverPercent!.toStringAsFixed(0),
              }),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'land_nirs_source'.tr(namedArgs: {'source': scan.source}),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (!scan.isSimulated && NirsMonitoringConfig.hasLiveApi) ...[
            const SizedBox(height: 4),
            Text(
              nirsLabel(context, 'land_nirs_basemap_note'),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: valueColor ?? Colors.grey.shade900,
            ),
          ),
        ),
      ],
    );
  }
}
