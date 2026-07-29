import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/farm_weather.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';
import 'farmer_help_widgets.dart';

class FarmerWeatherWidget extends ConsumerWidget {
  const FarmerWeatherWidget({
    super.key,
    required this.weather,
    this.isLoading = false,
    this.hasLocation = true,
    this.usingDeviceGps = false,
    this.onRefresh,
    this.onActionTap,
  });

  final FarmWeatherSnapshot? weather;
  final bool isLoading;
  final bool hasLocation;
  final bool usingDeviceGps;
  final VoidCallback? onRefresh;
  final VoidCallback? onActionTap;

  IconData _iconFor(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny_rounded;
      case WeatherCondition.cloudy:
        return Icons.cloud_rounded;
      case WeatherCondition.rainy:
        return Icons.grain_rounded;
      case WeatherCondition.storm:
        return Icons.thunderstorm_rounded;
    }
  }

  Color _accentFor(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return Colors.amber.shade700;
      case WeatherCondition.cloudy:
        return Colors.blueGrey.shade600;
      case WeatherCondition.rainy:
        return Colors.blue.shade700;
      case WeatherCondition.storm:
        return Colors.deepPurple.shade700;
    }
  }

  String _conditionLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return 'weather_condition_sunny'.tr();
      case WeatherCondition.cloudy:
        return 'weather_condition_cloudy'.tr();
      case WeatherCondition.rainy:
        return 'weather_condition_rainy'.tr();
      case WeatherCondition.storm:
        return 'weather_condition_storm'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDocProvider).valueOrNull ??
        ref.watch(authStateProvider).valueOrNull;
    final hasWeatherAccess = ref.watch(weatherPremiumAccessProvider);
    final showPremiumCta =
        (user?.isFarmerRole ?? false) && !hasWeatherAccess;

    if (!hasLocation) {
      return _WeatherActionCard(
        icon: Icons.location_off_rounded,
        iconColor: Colors.orange.shade800,
        title: farmerGuideTr(context, 'weather_location_missing'),
        subtitle: farmerGuideTr(context, 'weather_location_tap'),
        buttonLabel: farmerGuideTr(context, 'weather_action_gps_button'),
        isLoading: isLoading,
        onAction: onActionTap,
      );
    }

    if (isLoading && weather == null) {
      return _WeatherActionCard(
        icon: Icons.cloud_queue_rounded,
        iconColor: Colors.green.shade700,
        title: 'weather_loading'.tr(),
        subtitle: farmerGuideTr(context, 'weather_loading_hint'),
        buttonLabel: farmerGuideTr(context, 'weather_action_gps_button'),
        isLoading: true,
        onAction: null,
      );
    }

    final snapshot = weather;
    if (snapshot == null) {
      return _WeatherActionCard(
        icon: Icons.cloud_off_rounded,
        iconColor: Colors.blueGrey.shade700,
        title: 'weather_unavailable'.tr(),
        subtitle: farmerGuideTr(context, 'weather_unavailable_tap'),
        buttonLabel: farmerGuideTr(context, 'weather_action_retry_button'),
        isLoading: isLoading,
        onAction: onActionTap,
      );
    }

    final accent = _accentFor(snapshot.condition);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeatherShell(
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconFor(snapshot.condition),
                  color: accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _conditionLabel(snapshot.condition),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.green.shade900,
                      ),
                    ),
                    if (usingDeviceGps) ...[
                      const SizedBox(height: 2),
                      Text(
                        farmerGuideTr(context, 'weather_using_device_gps'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (snapshot.isSimulated) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          farmerGuideTr(context, 'weather_simulation_badge'),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _MetricChip(
                          icon: Icons.thermostat,
                          label:
                              '${snapshot.temperatureC.toStringAsFixed(0)}°C',
                        ),
                        const SizedBox(width: 8),
                        _MetricChip(
                          icon: Icons.air,
                          label:
                              '${snapshot.windSpeedKmh.toStringAsFixed(0)} km/h',
                        ),
                        const SizedBox(width: 8),
                        _MetricChip(
                          icon: Icons.water_drop_outlined,
                          label: '${snapshot.humidityPercent}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  onPressed: isLoading ? null : onRefresh,
                  icon: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green.shade700,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'weather_refresh'.tr(),
                ),
            ],
          ),
        ),
        if (showPremiumCta) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text('weather_premium_cta'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ] else if (hasWeatherAccess && snapshot.requiresPremiumAlert) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'weather_premium_active_alerts'.tr(),
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _WeatherActionCard extends StatelessWidget {
  const _WeatherActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.isLoading,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool isLoading;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _WeatherShell(
      emphasized: onAction != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onAction != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onAction,
                icon: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20),
                label: Text(
                  isLoading
                      ? farmerGuideTr(context, 'weather_loading_action')
                      : buttonLabel,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.shade600,
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherShell extends StatelessWidget {
  const _WeatherShell({
    required this.child,
    this.emphasized = false,
  });

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.lightBlue.shade50,
            Colors.green.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized ? Colors.green.shade400 : Colors.green.shade100,
          width: emphasized ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
