/// Tržnica: My Farmer ne procesira uplate između kupca i prodavača.
class MarketplacePaymentConfig {
  /// Uvijek true — platforma nije platni posrednik za narudžbe proizvoda.
  static const bool peerToPeerOnly = true;
}
