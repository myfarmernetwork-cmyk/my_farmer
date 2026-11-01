enum WeatherCondition {
  sunny,
  cloudy,
  rainy,
  storm,
}

class FarmWeatherSnapshot {
  const FarmWeatherSnapshot({
    required this.temperatureC,
    required this.windSpeedKmh,
    required this.humidityPercent,
    required this.precipitationChance,
    required this.frostRisk,
    required this.hailRisk,
    required this.condition,
    required this.source,
  });

  final double temperatureC;
  final double windSpeedKmh;
  final int humidityPercent;
  final int precipitationChance;
  final bool frostRisk;
  final bool hailRisk;
  final WeatherCondition condition;
  final String source;

  bool get isSimulated => source == 'simulation';

  bool get hasHighWind => windSpeedKmh > 40;

  bool get hasExtremeHeat => temperatureC > 35;

  bool get hasSevereRisk => hailRisk || frostRisk;

  bool get hasStormAlert => condition == WeatherCondition.storm;

  bool get hasHeavyRainAlert =>
      condition == WeatherCondition.rainy && precipitationChance >= 70;

  bool get requiresPremiumAlert => activeAlertKeys.isNotEmpty;

  /// Aktivne vrste nepogode — ista logika kao [functions/weather_alerts.js].
  List<String> get activeAlertKeys {
    final keys = <String>[];
    if (hasHighWind) keys.add('weather_alert_high_wind');
    if (hasExtremeHeat) keys.add('weather_alert_extreme_heat');
    if (hailRisk) keys.add('weather_alert_hail');
    if (frostRisk) keys.add('weather_alert_frost');
    if (hasStormAlert) keys.add('weather_alert_storm');
    if (hasHeavyRainAlert) keys.add('weather_alert_heavy_rain');
    return keys;
  }

  Map<String, String> get alertMessageArgs => {
        'temp': temperatureC.toStringAsFixed(0),
        'wind': windSpeedKmh.toStringAsFixed(0),
        'rain': '$precipitationChance',
      };
}
