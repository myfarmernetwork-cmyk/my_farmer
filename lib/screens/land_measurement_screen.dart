import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../features/land/models/land_parcel.dart';
import '../features/land/repositories/land_parcel_repository.dart';
import '../features/land/utils/polygon_geo_utils.dart';
import '../config/subscription_limits.dart';
import '../models/app_user.dart';
import '../models/nirs_quota.dart';
import '../models/premium_access.dart';
import '../models/screen_guide_step.dart';
import '../providers/subscription_provider.dart';
import '../services/nirs_limit_service.dart';
import '../services/nirs_monitoring_flow.dart';
import '../widgets/farmer_helper_button.dart';
import '../widgets/premium_gate.dart';

import 'land_parcel_detail_screen.dart';

class LandMeasurementScreen extends ConsumerStatefulWidget {
  const LandMeasurementScreen({super.key});

  @override
  ConsumerState<LandMeasurementScreen> createState() =>
      _LandMeasurementScreenState();
}

class _LandMeasurementScreenState extends ConsumerState<LandMeasurementScreen> {
  final LandParcelRepository _repository = LandParcelRepository();
  final List<LatLng> _points = [];
  LatLng? _initialPosition;
  bool _loadingLocation = true;
  bool _mapReady = false;
  bool _mapFullscreen = false;
  bool _isParcelClosed = false;
  Offset? _minimizeFabOffset;
  NirsQuotaStatus? _nirsQuota;
  bool _loadingNirsQuota = true;
  String? _activeParcelId;
  String? _activeParcelName;

  final GlobalKey _guideNirsButtonKey = GlobalKey();
  final GlobalKey _guideNirsQuotaKey = GlobalKey();

  List<ScreenGuideStep> get _guideSteps => [
        ScreenGuideStep(
          targetKey: _guideNirsQuotaKey,
          titleKey: 'guide_land_nirs_quota_title',
          bodyKey: 'guide_land_nirs_quota_body',
        ),
        ScreenGuideStep(
          targetKey: _guideNirsButtonKey,
          titleKey: 'land_nirs_premium_title',
          bodyKey: 'land_nirs_premium_body',
        ),
      ];

  bool get _canShowMetrics => _isParcelClosed && _points.length >= 3;

  double get _areaM2 =>
      _canShowMetrics ? PolygonGeoUtils.computeAreaSquareMeters(_points) : 0;

  double get _areaHa => PolygonGeoUtils.squareMetersToHectares(_areaM2);

  double get _perimeterM =>
      _canShowMetrics ? PolygonGeoUtils.computePerimeterMeters(_points) : 0;

  @override
  void initState() {
    super.initState();
    _resolveInitialPosition();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNirsQuota());
  }

  void _scheduleMapReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _mapReady = true);
      });
    });
  }

  Future<void> _refreshNirsQuota() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _nirsQuota = null;
          _loadingNirsQuota = false;
        });
      }
      return;
    }

    final access = ref.read(premiumAccessProvider);
    final status = await ref.read(nirsLimitServiceProvider).getQuotaStatus(
          userId: userId,
          access: access,
        );

    if (mounted) {
      setState(() {
        _nirsQuota = status;
        _loadingNirsQuota = false;
      });
    }
  }

  Future<void> _resolveInitialPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('location_disabled');

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('location_denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      if (!mounted) return;
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
      _scheduleMapReady();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialPosition = const LatLng(45.8150, 15.9819);
        _loadingLocation = false;
      });
      _scheduleMapReady();
    }
  }

  void _enterFullscreenMap() => setState(() => _mapFullscreen = true);

  void _exitFullscreenMap() => setState(() {
        _mapFullscreen = false;
        _minimizeFabOffset = null;
      });

  void _invalidateActiveParcel() {
    if (_activeParcelId != null || _activeParcelName != null) {
      setState(() {
        _activeParcelId = null;
        _activeParcelName = null;
      });
    }
  }

  void _onMapTap(LatLng position) {
    if (!_mapFullscreen) {
      _enterFullscreenMap();
      return;
    }
    if (_isParcelClosed) return;
    _invalidateActiveParcel();
    setState(() => _points.add(position));
  }

  void _onMarkerDragEnd(int index, LatLng newPosition) {
    if (index < 0 || index >= _points.length) return;
    _invalidateActiveParcel();
    setState(() => _points[index] = newPosition);
  }

  void _closeParcel() {
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('land_draw_hint'.tr())),
      );
      return;
    }

    final ordered = PolygonGeoUtils.orderPointsCounterClockwise(_points);
    if (PolygonGeoUtils.hasSelfIntersection(ordered)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('land_self_intersect'.tr()),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _points
        ..clear()
        ..addAll(ordered);
      _isParcelClosed = true;
    });
  }

  void _clearAll() {
    setState(() {
      _points.clear();
      _isParcelClosed = false;
      _activeParcelId = null;
      _activeParcelName = null;
    });
  }

  void _openSavedParcel(LandParcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LandParcelDetailScreen(parcel: parcel),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return _points.asMap().entries.map((entry) {
      final index = entry.key;
      return Marker(
        markerId: MarkerId('point_$index'),
        position: entry.value,
        draggable: true,
        onDragEnd: (newPosition) => _onMarkerDragEnd(index, newPosition),
      );
    }).toSet();
  }

  Set<Polygon> _buildPolygons() {
    if (!_isParcelClosed || _points.length < 3) return {};
    return {
      Polygon(
        polygonId: const PolygonId('parcel'),
        points: List<LatLng>.from(_points),
        strokeColor: Colors.green.shade700,
        strokeWidth: 3,
        fillColor: Colors.green.withValues(alpha: 0.28),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    if (_isParcelClosed || _points.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('parcel_draft'),
        points: List<LatLng>.from(_points),
        color: Colors.amber.shade700,
        width: 3,
        geodesic: true,
      ),
    };
  }

  Future<String?> _promptParcelName() async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (sheetContext) => _SaveParcelNameSheet(
        onCancel: () => Navigator.pop(sheetContext),
        onSave: (name) => Navigator.pop(sheetContext, name),
      ),
    );
  }

  Future<void> _showParcelLimitDialog(PremiumAccess access) async {
    final isHobby = access.role == UserRole.hobbyFarmer;
    final hasPremium = access.hasPaidOrPromoAccess &&
        access.maxSavedParcels > SubscriptionLimits.farmerFreeMaxParcels;

    final title = 'land_parcel_limit_title'.tr();
    final body = hasPremium
        ? 'land_parcel_limit_max'.tr(namedArgs: {
            'count': '${access.maxSavedParcels}',
          })
        : isHobby
            ? 'land_parcel_premium_required_hobby'.tr(namedArgs: {
                'count': '${SubscriptionLimits.hobbyPremiumMaxParcels}',
              })
            : 'land_parcel_premium_required_pro'.tr(namedArgs: {
                'count': '${SubscriptionLimits.proPremiumMaxParcels}',
              });

    final upgrade = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.landscape_outlined, color: Colors.green.shade800),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(
          body,
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cart_cancel'.tr()),
          ),
          if (!hasPremium)
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
              ),
              child: Text('paywall_start_premium'.tr()),
            ),
        ],
      ),
    );

    if (upgrade == true && mounted) {
      await PremiumGate.run(
        context,
        ref,
        feature: PremiumFeature.landMeasurement,
        onUnlocked: () {},
      );
    }
  }

  Future<void> _saveParcel() async {
    if (!_canShowMetrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('land_draw_hint'.tr())),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final access = ref.read(premiumAccessProvider);
    final existing = await _repository.fetchUserParcels(userId);
    if (existing.length >= access.maxSavedParcels) {
      if (!mounted) return;
      await _showParcelLimitDialog(access);
      return;
    }

    final enteredName = await _promptParcelName();
    if (!mounted || enteredName == null) return;

    final parcelName = enteredName.trim().isEmpty
        ? 'land_unnamed_parcel'.tr()
        : enteredName.trim();

    try {
      final parcelId = await _repository.saveParcel(
        ownerId: userId,
        name: parcelName,
        points: List<LatLng>.from(_points),
        areaSquareMeters: _areaM2,
        perimeterMeters: _perimeterM,
      );
      if (mounted) {
        setState(() {
          _activeParcelId = parcelId;
          _activeParcelName = parcelName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('land_save_success'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildMetricsPanel() {
    if (!_canShowMetrics) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Text(
          'land_draw_hint'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Colors.grey.shade800,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            label: 'land_area_m2'.tr(),
            value: _areaM2.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'land_area_ha'.tr(),
            value: _areaHa.toStringAsFixed(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricTile(
            label: 'land_perimeter'.tr(),
            value: '${_perimeterM.toStringAsFixed(1)} m',
          ),
        ),
      ],
    );
  }

  Widget _buildSavedParcels(String userId) {
    return StreamBuilder<List<LandParcel>>(
      stream: _repository.watchUserParcels(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'land_no_parcels'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          );
        }

        final parcels = snapshot.data ?? const <LandParcel>[];
        if (parcels.isEmpty) {
          return Text(
            'land_no_parcels'.tr(),
            style: TextStyle(color: Colors.grey.shade600),
          );
        }

        return SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: parcels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final parcel = parcels[index];
              final scan = parcel.lastNirsScan;
              return SizedBox(
                width: 168,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openSavedParcel(parcel),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  parcel.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${parcel.areaSquareMeters.toStringAsFixed(0)} m² · ${parcel.areaHectares.toStringAsFixed(3)} ha',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          if (scan != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scan.ndviColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'NDVI ${scan.ndviMean.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scan.ndviColor,
                                ),
                              ),
                            )
                          else
                            Text(
                              'land_parcel_tap_open'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.teal.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openNirsMonitoring() async {
    final access = ref.read(premiumAccessProvider);
    if (!access.canUseNirsMonitoring) {
      await NirsMonitoringFlow.showPremiumRequiredDialog(context, ref);
      return;
    }

    if (!_isParcelClosed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('land_nirs_close_parcel_first'.tr()),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final result = await NirsMonitoringFlow.confirmAndRun(
      context: context,
      ref: ref,
      points: _points,
      parcelId: _activeParcelId,
      repository: _repository,
    );

    await _refreshNirsQuota();
    if (!mounted || result == null) return;

    final parcel = LandParcel(
      id: _activeParcelId ?? '',
      ownerId: userId,
      name: _activeParcelName ?? 'land_unnamed_parcel'.tr(),
      points: List<LatLng>.from(_points),
      areaSquareMeters: _areaM2,
      perimeterMeters: _perimeterM,
    );

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LandParcelDetailScreen(
          parcel: parcel,
          initialScanResult: result,
        ),
      ),
    );
  }

  Widget _buildNirsQuotaBanner(NirsQuotaStatus quota) {
    final subscriptionLocked =
        quota.blockReasonKey == 'land_nirs_subscription_required';

    if (!quota.canLoad) {
      return Container(
        key: _guideNirsQuotaKey,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: subscriptionLocked
              ? Colors.amber.shade50
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: subscriptionLocked
                ? Colors.amber.shade200
                : Colors.orange.shade200,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              subscriptionLocked ? Icons.lock_outline : Icons.warning_amber_rounded,
              color: subscriptionLocked
                  ? Colors.amber.shade900
                  : Colors.orange.shade800,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subscriptionLocked
                    ? 'land_nirs_locked_quota'.tr(namedArgs: {
                        'limit': '${quota.limit}',
                      })
                    : 'land_nirs_limit_monthly'.tr(),
                style: TextStyle(
                  color: subscriptionLocked
                      ? Colors.amber.shade900
                      : Colors.orange.shade900,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: _guideNirsQuotaKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.satellite_alt, color: Colors.green.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _nirsLabel(
                'land_nirs_quota_remaining',
                hr:
                    'Dostupnih NIRS satelitskih nadzora za ovaj mjesec: {remaining} / {limit}',
                de:
                    'Verfügbare NIRS-Satellitenüberwachungen in diesem Monat: {remaining} / {limit}',
                en:
                    'Available NIRS satellite monitoring sessions this month: {remaining} / {limit}',
              ).replaceAll('{remaining}', '${quota.remaining}').replaceAll(
                    '{limit}',
                    '${quota.limit}',
                  ),
              style: TextStyle(color: Colors.green.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _nirsLabel(
    String key, {
    required String hr,
    required String de,
    required String en,
  }) {
    final translated = key.tr();
    if (translated != key) return translated;
    final language = context.locale.languageCode;
    if (language == 'de') return de;
    if (language == 'en') return en;
    return hr;
  }

  Widget _buildGoogleMapView() {
    if (!_mapReady) {
      return ColoredBox(
        color: _mapFullscreen ? Colors.black : Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _initialPosition!,
        zoom: 17,
      ),
      mapType: MapType.satellite,
      markers: _buildMarkers(),
      polygons: _buildPolygons(),
      polylines: _buildPolylines(),
      onTap: _onMapTap,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: _mapFullscreen,
    );
  }

  String _landMapLabel(
    String key, {
    required String hr,
    required String de,
    required String en,
  }) {
    final translated = key.tr();
    if (translated != key) return translated;
    final language = context.locale.languageCode;
    if (language == 'de') return de;
    if (language == 'en') return en;
    return hr;
  }

  Widget _buildExpandMapButton({bool centered = false}) {
    final label = _landMapLabel(
      'land_map_expand',
      hr: 'Otvori kartu',
      de: 'Karte öffnen',
      en: 'Open map',
    );
    final button = Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: Colors.green.shade800,
      child: InkWell(
        onTap: _enterFullscreenMap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: centered ? 20 : 14,
            vertical: centered ? 12 : 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fullscreen, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (centered) {
      return Center(child: button);
    }

    return button;
  }

  Widget _buildDraggableMinimizeFab({
    required Size screenSize,
    required EdgeInsets padding,
  }) {
    const fabWidth = 108.0;
    const fabHeight = 36.0;
    final defaultOffset = Offset(12, padding.top + 8);
    final offset = _minimizeFabOffset ?? defaultOffset;
    final label = _landMapLabel(
      'land_map_minimize',
      hr: 'Umanji',
      de: 'Verkleinern',
      en: 'Minimize',
    );

    return Positioned(
      left: offset.dx.clamp(8.0, screenSize.width - fabWidth - 8),
      top: offset.dy.clamp(
        padding.top + 4,
        screenSize.height - fabHeight - 160,
      ),
      child: GestureDetector(
        onPanUpdate: (details) {
          final base = _minimizeFabOffset ?? defaultOffset;
          final next = base + details.delta;
          setState(() {
            _minimizeFabOffset = Offset(
              next.dx.clamp(8.0, screenSize.width - fabWidth - 8),
              next.dy.clamp(
                padding.top + 4,
                screenSize.height - fabHeight - 160,
              ),
            );
          });
        },
        child: Material(
          elevation: 5,
          borderRadius: BorderRadius.circular(18),
          color: Colors.green.shade800,
          child: InkWell(
            onTap: _exitFullscreenMap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fullscreen_exit, color: Colors.white, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMap() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildGoogleMapView(),
        Positioned.fill(
          child: Material(
            color: Colors.black.withValues(alpha: 0.22),
            child: InkWell(
              onTap: _enterFullscreenMap,
              child: _buildExpandMapButton(centered: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullscreenMapBody() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitFullscreenMap();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.paddingOf(context);
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildGoogleMapView(),
              _buildDraggableMinimizeFab(
                screenSize: screenSize,
                padding: padding,
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.95),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isParcelClosed
                                ? 'land_closed_hint'.tr()
                                : 'land_tap_hint'.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),
                          if (_points.length >= 3 && !_isParcelClosed) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _closeParcel,
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: Text('land_close_parcel'.tr()),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                          if (_canShowMetrics) ...[
                            const SizedBox(height: 10),
                            _buildMetricsPanel(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(premiumAccessProvider);
    final isAdmin = ref.watch(adminPremiumBypassProvider);
    final canUseNirs = access.canUseNirsMonitoring;

    if (!isAdmin && !access.canUse(PremiumFeature.landMeasurement)) {
      return PremiumLockedView(
        feature: PremiumFeature.landMeasurement,
        titleKey: 'land_premium_title',
        descriptionKey: 'land_premium_desc',
        buttonKey: 'land_premium_activate',
        icon: Icons.satellite_alt,
      );
    }

    if (_loadingLocation || _initialPosition == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('land_title'.tr()),
          backgroundColor: Colors.green.shade800,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bottomPanelMaxHeight = screenHeight * 0.28;
    final topControlsMaxHeight = screenHeight * 0.34;

    if (_mapFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: _buildFullscreenMapBody(),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('land_title'.tr()),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          FarmerHelperIconButton(guideSteps: _guideSteps),
        ],
      ),
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: topControlsMaxHeight.clamp(
                        0,
                        constraints.maxHeight * 0.4,
                      ),
                    ),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _points.length >= 3 && !_isParcelClosed
                                          ? _closeParcel
                                          : null,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text('land_close_parcel'.tr()),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: KeyedSubtree(
                                  key: _guideNirsButtonKey,
                                  child: OutlinedButton.icon(
                                    onPressed: _openNirsMonitoring,
                                    icon: Icon(
                                      canUseNirs
                                          ? Icons.grass_outlined
                                          : Icons.lock_outline,
                                      size: 18,
                                      color: canUseNirs
                                          ? Colors.teal.shade800
                                          : Colors.grey.shade600,
                                    ),
                                    label: Text(
                                      canUseNirs
                                          ? _nirsLabel(
                                              'land_nirs_button',
                                              hr:
                                                  'Multispektralni NIRS/NDVI nadzor',
                                              de:
                                                  'Multispektraler NIRS/NDVI-Monitor',
                                              en:
                                                  'Multispectral NIRS/NDVI monitoring',
                                            )
                                          : 'land_nirs_button_locked'.tr(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: canUseNirs
                                            ? Colors.teal.shade800
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: canUseNirs
                                          ? Colors.teal.shade800
                                          : Colors.grey.shade700,
                                      side: BorderSide(
                                        color: canUseNirs
                                            ? Colors.teal.shade300
                                            : Colors.grey.shade400,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _loadingNirsQuota
                              ? Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(
                                    color: Colors.green.shade700,
                                    backgroundColor: Colors.green.shade100,
                                  ),
                                )
                              : _nirsQuota != null
                                  ? _buildNirsQuotaBanner(_nirsQuota!)
                                  : const SizedBox.shrink(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _points.isEmpty ? null : _clearAll,
                                  icon: const Icon(Icons.clear_all),
                                  label: Text('land_clear_all'.tr()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade300),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _isParcelClosed
                                  ? 'land_closed_hint'.tr()
                                  : 'land_tap_hint'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Text(
                            _landMapLabel(
                              'land_map_compact_hint',
                              hr: 'Dodirnite kartu za puni ekran.',
                              de: 'Tippen Sie für Vollbild.',
                              en: 'Tap the map for full screen.',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildCompactMap(),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: bottomPanelMaxHeight.clamp(
                      0,
                      constraints.maxHeight * 0.36,
                    ),
                  ),
                  child: Material(
                    color: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMetricsPanel(),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _canShowMetrics ? _saveParcel : null,
                            icon: const Icon(Icons.save_outlined),
                            label: Text('land_save'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                          if (userId != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              'land_saved_parcels'.tr(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildSavedParcels(userId),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

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
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveParcelNameSheet extends StatefulWidget {
  const _SaveParcelNameSheet({
    required this.onCancel,
    required this.onSave,
  });

  final VoidCallback onCancel;
  final ValueChanged<String> onSave;

  @override
  State<_SaveParcelNameSheet> createState() => _SaveParcelNameSheetState();
}

class _SaveParcelNameSheetState extends State<_SaveParcelNameSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() => widget.onSave(_nameController.text);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'land_save_title'.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'land_parcel_name'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      child: Text('cart_cancel'.tr()),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('land_save'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
