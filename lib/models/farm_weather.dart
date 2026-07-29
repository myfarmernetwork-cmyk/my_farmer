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

  bool get requiresPremiumAlert =>
      hasHighWind ||
      hasExtremeHeat ||
      hasSevereRisk ||
      hasStormAlert ||
      hasHeavyRainAlert;
}
