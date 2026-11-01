/// Zatvoreno testiranje (Closed testing).
///
/// Način 1 — compile-time (beta AAB):
/// ```bash
/// flutter build appbundle --release \
///   --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
///   --dart-define=BETA_FREE_PREMIUM=true
/// ```
/// Ili: `.\scripts\build_beta.ps1`
///
/// Način 2 — runtime (release AAB + Firestore):
/// - `closedTestingFreeWeatherAlerts: true` — meteo-alarmi za farmere
/// - `closedTestingFreeChat: true` — chat za sve uloge
/// - `closedTestingFreeVetIntake: true` — kartoteka pacijenata za veterinare
///
/// Produkcija — oba načina isključena (default false).
class BetaConfig {
  BetaConfig._();

  static const bool closedTestFreePremium = bool.fromEnvironment(
    'BETA_FREE_PREMIUM',
    defaultValue: false,
  );
}
