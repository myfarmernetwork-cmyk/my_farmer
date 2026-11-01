/// Remote app flags (Firestore `config/app`).
class AppConfig {
  const AppConfig({
    this.closedTestingFreeWeatherAlerts = false,
    this.closedTestingFreeChat = false,
    this.closedTestingFreeVetIntake = false,
  });

  /// Closed testing — meteo-alarmi besplatni za farmere (bez ostalog Premiuma).
  final bool closedTestingFreeWeatherAlerts;

  /// Closed testing — chat besplatni za sve uloge.
  final bool closedTestingFreeChat;

  /// Closed testing — kartoteka pacijenata besplatna za veterinare.
  final bool closedTestingFreeVetIntake;

  factory AppConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const AppConfig();
    return AppConfig(
      closedTestingFreeWeatherAlerts:
          data['closedTestingFreeWeatherAlerts'] == true,
      closedTestingFreeChat: data['closedTestingFreeChat'] == true,
      closedTestingFreeVetIntake: data['closedTestingFreeVetIntake'] == true,
    );
  }
}
