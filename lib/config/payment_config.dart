class PaymentConfig {
  /// false za Play Store. Dev: --dart-define=PAYMENT_SIMULATION=true
  static const bool simulationMode = bool.fromEnvironment(
    'PAYMENT_SIMULATION',
    defaultValue: false,
  );

  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String paypalClientId = String.fromEnvironment(
    'PAYPAL_CLIENT_ID',
    defaultValue: '',
  );

  static const String merchantDisplayName = 'My Farmer';

  static const String merchantCountryCode = 'BA';

  static const String defaultCurrency = 'EUR';

  static bool get isStripeConfigured => stripePublishableKey.isNotEmpty;

  static bool get isPayPalConfigured => paypalClientId.isNotEmpty;

  /// Stripe/Google Pay koriste simulacijski dijalog umjesto payment sheeta.
  static bool get isStripeSimulated =>
      simulationMode || !isStripeConfigured;

  /// PayPal koristi simulacijski dijalog umjesto sandbox stranice.
  static bool get isPayPalSimulated =>
      simulationMode || !isPayPalConfigured;

  static bool get isAnyMarketplacePaymentSimulated =>
      isStripeSimulated || isPayPalSimulated;
}
