enum CartPaymentMethod {
  cash,
  stripe,
  googlePay,
  paypal,
  directPaypal,
  bankTransfer;

  String get firestoreValue => switch (this) {
        CartPaymentMethod.cash => 'cash',
        CartPaymentMethod.stripe => 'stripe',
        CartPaymentMethod.googlePay => 'google_pay',
        CartPaymentMethod.paypal => 'paypal',
        CartPaymentMethod.directPaypal => 'direct_paypal',
        CartPaymentMethod.bankTransfer => 'bank_transfer',
      };

  /// Platforma (Stripe/PayPal API) — ne koristi se na tržnici u P2P modu.
  bool get requiresPlatformProcessing => switch (this) {
        CartPaymentMethod.stripe ||
        CartPaymentMethod.googlePay ||
        CartPaymentMethod.paypal =>
          true,
        _ => false,
      };

  bool get requiresDigitalProcessing => requiresPlatformProcessing;

  bool get isDigital => this != CartPaymentMethod.cash;

  bool get isPeerToPeer => switch (this) {
        CartPaymentMethod.directPaypal ||
        CartPaymentMethod.bankTransfer ||
        CartPaymentMethod.cash =>
          true,
        _ => false,
      };

  static CartPaymentMethod fromValue(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'stripe' || 'card' => CartPaymentMethod.stripe,
      'google_pay' || 'googlepay' || 'apple_pay' || 'applepay' =>
        CartPaymentMethod.googlePay,
      'paypal' => CartPaymentMethod.paypal,
      'direct_paypal' => CartPaymentMethod.directPaypal,
      'bank_transfer' || 'bank' || 'iban' => CartPaymentMethod.bankTransfer,
      _ => CartPaymentMethod.cash,
    };
  }

  static const List<CartPaymentMethod> platformDigitalMethods = [
    CartPaymentMethod.stripe,
    CartPaymentMethod.googlePay,
    CartPaymentMethod.paypal,
  ];

  static const List<CartPaymentMethod> peerToPeerCheckoutMethods = [
    CartPaymentMethod.cash,
    CartPaymentMethod.directPaypal,
    CartPaymentMethod.bankTransfer,
  ];
}
