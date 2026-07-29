import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/weather_config.dart';
import '../models/farm_weather.dart';
import '../models/farmer_shop_settings.dart';
import 'delivery_service.dart';
import 'notification_service.dart';

class WeatherService {
  WeatherService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notifications;

  final Set<String> _sentAlertKeys = {};

  Future<({double lat, double lng})?> _resolveFarmLocation(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    final settings = FarmerShopSettings.fromMap(doc.data()!);
    if (settings.hasFarmLocation &&
        _isValidCoordinate(settings.farmLat!, settings.farmLng!)) {
      return (lat: settings.farmLat!, lng: settings.farmLng!);
    }

    final data = doc.data()!;
    final location = data['location'];
    if (location is Map) {
      final lat = location['lat'];
      final lng = location['lng'];
      if (lat is num && lng is num) {
        final latD = lat.toDouble();
        final lngD = lng.toDouble();
        if (_isValidCoordinate(latD, lngD)) {
          return (lat: latD, lng: lngD);
        }
      }
    }

    return null;
  }

  static bool _isValidCoordinate(double lat, double lng) {
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  static const _httpHeaders = {
    'Accept': 'application/json',
    'User-Agent': 'MyFarmer/1.0',
  };

  Future<bool> hasFarmLocation(String uid) async {
    final coords = await _resolveFarmLocation(uid);
    return coords != null;
  }

  /// Profil farme → inače trenutni GPS uređaja.
  Future<
      ({
        FarmWeatherSnapshot? snapshot,
        bool usedDeviceGps,
        bool hasCoordinates,
      })> fetchWithFallback(
    String uid,
  ) async {
    final coords = await _resolveFarmLocation(uid);
    if (coords != null) {
      final snapshot = await _fetchForCoordinates(
        lat: coords.lat,
        lng: coords.lng,
      );
      return (
        snapshot: snapshot,
        usedDeviceGps: false,
        hasCoordinates: true,
      );
    }

    final position = await DeliveryService().getCurrentPosition();
    if (position == null) {
      return (
        snapshot: null,
        usedDeviceGps: false,
        hasCoordinates: false,
      );
    }

    final snapshot = await _fetchForCoordinates(
      lat: position.latitude,
      lng: position.longitude,
    );
    return (
      snapshot: snapshot,
      usedDeviceGps: true,
      hasCoordinates: true,
    );
  }

  Future<FarmWeatherSnapshot?> fetchForUser(String uid) async {
    final coords = await _resolveFarmLocation(uid);
    if (coords == null) return null;
    return _fetchForCoordinates(lat: coords.lat, lng: coords.lng);
  }

  Future<FarmWeatherSnapshot> _fetchForCoordinates({
    required double lat,
    required double lng,
  }) async {
    if (!_isValidCoordinate(lat, lng)) {
      return _simulatedWeather(lat: lat, lng: lng);
    }

    try {
      // Open-Meteo: besplatan, bez API ključa — siguran default za javni Play Store build.
      final openMeteo = await _fetchOpenMeteo(lat: lat, lng: lng);
      if (openMeteo != null) return openMeteo;

      if (WeatherConfig.hasApiKey) {
        final openWeather = await _fetchOpenWeather(lat: lat, lng: lng);
        if (openWeather != null) return openWeather;
      }
    } catch (_) {
      // Mreža / parsiranje — nastavi na simulaciju ispod.
    }

    return _simulatedWeather(lat: lat, lng: lng);
  }

  Future<void> checkPremiumAlerts({
    required FarmWeatherSnapshot weather,
    required bool isPremium,
  }) async {
    if (!isPremium || !weather.requiresPremiumAlert) return;

    final alerts = <String>[];

    if (weather.hasHighWind) {
      alerts.add('weather_alert_high_wind');
    }
    if (weather.hasExtremeHeat) {
      alerts.add('weather_alert_extreme_heat');
    }
    if (weather.hailRisk) {
      alerts.add('weather_alert_hail');
    }
    if (weather.frostRisk) {
      alerts.add('weather_alert_frost');
    }
    if (weather.hasStormAlert) {
      alerts.add('weather_alert_storm');
    }
    if (weather.hasHeavyRainAlert) {
      alerts.add('weather_alert_heavy_rain');
    }

    for (final alertKey in alerts) {
      if (_sentAlertKeys.contains(alertKey)) continue;
      _sentAlertKeys.add(alertKey);

      await _notifications.showWeatherAlert(
        title: 'weather_alert_title'.tr(),
        body: alertKey.tr(
          namedArgs: {
            'temp': weather.temperatureC.toStringAsFixed(0),
            'wind': weather.windSpeedKmh.toStringAsFixed(0),
            'rain': '${weather.precipitationChance}',
          },
        ),
        payload: 'weather_alert|$alertKey',
      );
    }
  }

  Future<FarmWeatherSnapshot?> _fetchOpenWeather({
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/weather',
        {
          'lat': '$lat',
          'lon': '$lng',
          'appid': WeatherConfig.openWeatherApiKey,
          'units': 'metric',
        },
      );

      final response = await http
          .get(uri, headers: _httpHeaders)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final main = data['main'] as Map<String, dynamic>? ?? {};
      final wind = data['wind'] as Map<String, dynamic>? ?? {};
      final weatherList = data['weather'] as List<dynamic>? ?? [];
      final weatherMain = weatherList.isNotEmpty
          ? (weatherList.first as Map<String, dynamic>)['main']?.toString() ?? ''
          : '';

      final temp = (main['temp'] as num?)?.toDouble() ?? 15;
      final humidity = (main['humidity'] as num?)?.round() ?? 0;
      final windMs = (wind['speed'] as num?)?.toDouble() ?? 0;
      final windKmh = windMs * 3.6;
      final clouds = (data['clouds'] as Map<String, dynamic>?)?['all'] as num?;
      final rain = data['rain'] as Map<String, dynamic>?;
      final rainMm = rain?['1h'] as num? ?? rain?['3h'] as num?;

      var precipChance = clouds?.round() ?? 0;
      if (rainMm != null && rainMm > 0) {
        precipChance = math.max(precipChance, 70);
      }

      final condition = _mapOpenWeatherCondition(weatherMain);
      final hailRisk = condition == WeatherCondition.storm ||
          (precipChance > 75 && temp < 8);
      final frostRisk = temp <= 2;

      return FarmWeatherSnapshot(
        temperatureC: temp,
        windSpeedKmh: windKmh,
        humidityPercent: humidity.clamp(0, 100),
        precipitationChance: precipChance.clamp(0, 100),
        frostRisk: frostRisk,
        hailRisk: hailRisk,
        condition: condition,
        source: 'openweather',
      );
    } catch (_) {
      return null;
    }
  }

  Future<FarmWeatherSnapshot?> _fetchOpenMeteo({
    required double lat,
    required double lng,
  }) async {
    try {
      final uri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': '$lat',
          'longitude': '$lng',
          'current':
              'temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code',
          'wind_speed_unit': 'kmh',
          'timezone': 'auto',
        },
      );

      final response = await http
          .get(uri, headers: _httpHeaders)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>? ?? {};

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 15;
      final humidity = (current['relative_humidity_2m'] as num?)?.round() ?? 0;
      final windKmh = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0;
      final weatherCode = (current['weather_code'] as num?)?.round() ?? 0;

      final condition = _mapOpenMeteoCode(weatherCode);
      final precipChance = _precipChanceFromOpenMeteoCode(weatherCode);
      final hailRisk = condition == WeatherCondition.storm ||
          (precipChance > 75 && temp < 8);
      final frostRisk = temp <= 2;

      return FarmWeatherSnapshot(
        temperatureC: temp,
        windSpeedKmh: windKmh,
        humidityPercent: humidity.clamp(0, 100),
        precipitationChance: precipChance,
        frostRisk: frostRisk,
        hailRisk: hailRisk,
        condition: condition,
        source: 'open-meteo',
      );
    } catch (_) {
      return null;
    }
  }

  FarmWeatherSnapshot _simulatedWeather({
    required double lat,
    required double lng,
  }) {
    final hourBucket = DateTime.now().millisecondsSinceEpoch ~/ (1000 * 60 * 30);
    final seed = (lat * 1000 + lng * 1000 + hourBucket).round().abs();
    final temp = 8 + (seed % 18);
    final humidity = 40 + (seed % 45);
    final windKmh = 5 + (seed % 35).toDouble();
    final precipChance = seed % 100;
    final conditions = WeatherCondition.values;
    final condition = conditions[seed % conditions.length];
    final frostRisk = temp <= 2;
    final hailRisk = condition == WeatherCondition.storm;

    return FarmWeatherSnapshot(
      temperatureC: temp.toDouble(),
      windSpeedKmh: windKmh,
      humidityPercent: humidity,
      precipitationChance: precipChance,
      frostRisk: frostRisk,
      hailRisk: hailRisk,
      condition: condition,
      source: 'simulation',
    );
  }

  WeatherCondition _mapOpenMeteoCode(int code) {
    if (code == 0) return WeatherCondition.sunny;
    if (code <= 3) return WeatherCondition.cloudy;
    if (code >= 45 && code <= 48) return WeatherCondition.cloudy;
    if (code >= 51 && code <= 67) return WeatherCondition.rainy;
    if (code >= 80 && code <= 82) return WeatherCondition.rainy;
    if (code >= 95) return WeatherCondition.storm;
    return WeatherCondition.cloudy;
  }

  int _precipChanceFromOpenMeteoCode(int code) {
    if (code >= 95) return 90;
    if (code >= 80 && code <= 82) return 75;
    if (code >= 61 && code <= 67) return 80;
    if (code >= 51 && code <= 57) return 55;
    if (code >= 71 && code <= 77) return 40;
    if (code >= 3) return 25;
    return 5;
  }

  WeatherCondition _mapOpenWeatherCondition(String main) {
    final normalized = main.toLowerCase();
    if (normalized.contains('thunder') ||
        normalized.contains('hail') ||
        normalized.contains('squall')) {
      return WeatherCondition.storm;
    }
    if (normalized.contains('rain') || normalized.contains('drizzle')) {
      return WeatherCondition.rainy;
    }
    if (normalized.contains('cloud')) {
      return WeatherCondition.cloudy;
    }
    return WeatherCondition.sunny;
  }
}

final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});
