import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/locale_settings_provider.dart';
import '../services/location_install_prefs.dart';
import '../services/payment_service.dart';

/// Blokira app dok korisnik ne odobri GPS — sprječava zloupotrebu jezičnih cijena.
class LocationRequiredGate extends ConsumerStatefulWidget {
  const LocationRequiredGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocationRequiredGate> createState() =>
      _LocationRequiredGateState();
}

class _LocationRequiredGateState extends ConsumerState<LocationRequiredGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _granted = false;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_checking &&
        !_granted &&
        !_working) {
      _ensureGps(showErrors: false);
    }
  }

  Future<void> _bootstrap() async {
    if (await LocationInstallPrefs.isCompleted()) {
      final savedCountry = await LocationInstallPrefs.loadGpsCountry();
      if (savedCountry != null) {
        PaymentService.restoreGpsCountry(savedCountry);
        if (!mounted) return;
        final locale = context.locale;
        final region = resolveCurrencyRegionForUser(
          locale: locale,
          deviceCountryCode: savedCountry,
          paymentCountryCode: PaymentService.cachedPaymentCountryCode,
        );
        ref.read(currencyRegionProvider.notifier).state = region;
        setState(() {
          _checking = false;
          _granted = true;
        });
        return;
      }
    }

    if (PaymentService.hasGpsVerifiedLocation) {
      if (mounted) {
        setState(() {
          _checking = false;
          _granted = true;
        });
      }
      return;
    }

    // Ne drži splash/checker dok GPS + geocoding traju (do ~25 s).
    if (mounted) {
      setState(() => _checking = false);
    }
    unawaited(_ensureGps(showErrors: false));
  }

  void _showFeedback(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _ensureGps({required bool showErrors}) async {
    if (_working) return;

    setState(() {
      _working = true;
      if (showErrors) _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        const messageKey = 'location_install_services_off';
        if (mounted) {
          setState(() {
            _error = messageKey.tr();
            _granted = false;
          });
          if (showErrors) _showFeedback(messageKey.tr());
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        const messageKey = 'location_install_permission_denied';
        if (mounted) {
          setState(() {
            _error = messageKey.tr();
            _granted = false;
          });
          if (showErrors) {
            _showFeedback(messageKey.tr());
          }
        }
        return;
      }

      PaymentService.clearCountryCache();
      final device = await PaymentService.resolveDeviceCountryForPricing().timeout(
        const Duration(seconds: 25),
        onTimeout: () => null,
      );
      if (device == null) {
        const messageKey = 'location_install_gps_failed';
        if (mounted) {
          setState(() {
            _error = messageKey.tr();
            _granted = false;
          });
          if (showErrors) _showFeedback(messageKey.tr());
        }
        return;
      }

      if (!mounted) return;

      final locale = context.locale;
      final region = resolveCurrencyRegionForUser(
        locale: locale,
        deviceCountryCode: device.countryCode,
        paymentCountryCode: PaymentService.cachedPaymentCountryCode,
      );
      ref.read(currencyRegionProvider.notifier).state = region;

      await LocationInstallPrefs.markCompleted();
      await LocationInstallPrefs.saveGpsCountry(device.countryCode);

      if (mounted) {
        setState(() {
          _granted = true;
          _error = null;
        });
        if (showErrors) {
          _showFeedback('location_install_success'.tr(), isError: false);
        }
      }
    } catch (_) {
      const messageKey = 'location_install_gps_failed';
      if (mounted) {
        setState(() {
          _error = messageKey.tr();
          _granted = false;
        });
        if (showErrors) _showFeedback(messageKey.tr());
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_granted) {
      return widget.child;
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final minHeight = constraints.maxHeight - bottomInset;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.location_on, size: 72, color: Colors.green[800]),
                    const SizedBox(height: 24),
                    Text(
                      'location_install_title'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'location_install_body'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _working
                          ? null
                          : () => _ensureGps(showErrors: true),
                      icon: _working
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: Text('location_install_enable'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _working ? null : Geolocator.openLocationSettings,
                      child: Text('location_install_open_settings'.tr()),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
