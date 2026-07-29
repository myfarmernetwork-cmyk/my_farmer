/// OpenWeather — opcionalno. Bez ključa app koristi Open-Meteo (besplatno, bez registracije).
/// Lokalno / CI: --dart-define=OPENWEATHER_API_KEY=your_key
class WeatherConfig {
  WeatherConfig._();

  static const String openWeatherApiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '',
  );

  static bool get hasApiKey => openWeatherApiKey.trim().isNotEmpty;
}
