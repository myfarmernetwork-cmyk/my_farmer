import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/farm_weather.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/farm_location_service.dart';
import '../services/weather_service.dart';
import '../utils/upcoming_product_helper.dart';
import 'farmer_weather_widget.dart';

/// Samostalni banner s vremenskom prognozom — osvježavanje ne rebuilda roditeljski ekran.
class FarmerWeatherBanner extends ConsumerStatefulWidget {
  const FarmerWeatherBanner({
    super.key,
    this.guideKey,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 0),
    this.checkAlertsOnPeriodicRefresh = false,
  });

  final Key? guideKey;
  final EdgeInsetsGeometry padding;
  final bool checkAlertsOnPeriodicRefresh;

  @override
  ConsumerState<FarmerWeatherBanner> createState() =>
      _FarmerWeatherBannerState();
}

class _FarmerWeatherBannerState extends ConsumerState<FarmerWeatherBanner> {
  FarmWeatherSnapshot? _weather;
  bool _loading = false;
  bool _hasLocation = false;
  bool _fromDeviceGps = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    final role = ref.read(firestoreUserRoleProvider).valueOrNull;
    if (UpcomingProductHelper.isCompanyRole(role)) return;

    unawaited(_refresh(checkAlerts: widget.checkAlertsOnPeriodicRefresh));
    _timer ??= Timer.periodic(
      const Duration(minutes: 30),
      (_) => _refresh(checkAlerts: widget.checkAlertsOnPeriodicRefresh),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool checkAlerts = false}) async {
    final role = ref.read(firestoreUserRoleProvider).valueOrNull;
    if (UpcomingProductHelper.isCompanyRole(role)) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    setState(() => _loading = true);

    try {
      final service = ref.read(weatherServiceProvider);
      final result = await service.fetchWithFallback(user.uid);

      if (!mounted) return;

      setState(() {
        _weather = result.snapshot;
        _hasLocation = result.hasCoordinates;
        _fromDeviceGps = result.usedDeviceGps;
        _loading = false;
      });

      if (checkAlerts && result.snapshot != null) {
        final isPremium = ref.read(weatherPremiumAccessProvider);
        await service.checkPremiumAlerts(
          weather: result.snapshot!,
          isPremium: isPremium,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleBannerAction() async {
    if (_loading) return;

    if (!_hasLocation) {
      await _enableLocation();
      return;
    }

    if (_weather == null) {
      setState(() => _loading = true);
      await _refresh(checkAlerts: false);
      if (!mounted) return;
      if (_weather != null) return;

      await _enableLocation();
      if (!mounted) return;
      if (_weather == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('weather_unavailable'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await _refresh(checkAlerts: true);
  }

  Future<void> _enableLocation() async {
    if (_loading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    setState(() => _loading = true);

    final result = await FarmLocationService().requestAndSave(user.uid);

    if (!mounted) return;

    if (result.outcome == FarmLocationRequestOutcome.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('profile_farm_location_saved'.tr()),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _refresh(checkAlerts: true);
      return;
    }

    setState(() => _loading = false);

    switch (result.outcome) {
      case FarmLocationRequestOutcome.servicesDisabled:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_gps_enable'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Geolocator.openLocationSettings();
      case FarmLocationRequestOutcome.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_location_permission'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Geolocator.openAppSettings();
      case FarmLocationRequestOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('location_install_gps_failed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case FarmLocationRequestOutcome.success:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(firestoreUserRoleProvider).valueOrNull;
    if (UpcomingProductHelper.isCompanyRole(role)) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: widget.guideKey,
      padding: widget.padding,
      child: FarmerWeatherWidget(
        weather: _weather,
        isLoading: _loading,
        hasLocation: _hasLocation,
        usingDeviceGps: _fromDeviceGps,
        onRefresh: _weather != null ? () => _refresh(checkAlerts: true) : null,
        onActionTap: _handleBannerAction,
      ),
    );
  }
}
