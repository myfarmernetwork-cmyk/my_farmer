/// Zatvoreno testiranje (Closed testing) — samo u tom buildu.
///
/// Closed testing AAB:
/// ```bash
/// flutter build appbundle --release \
///   --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx \
///   --dart-define=BETA_FREE_PREMIUM=true
/// ```
///
/// Produkcija — **bez** BETA_FREE_PREMIUM (default false).
class BetaConfig {
  BetaConfig._();

  static const bool closedTestFreePremium = bool.fromEnvironment(
    'BETA_FREE_PREMIUM',
    defaultValue: false,
  );
}
