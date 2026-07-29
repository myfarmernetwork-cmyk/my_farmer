class PaymentResult {
  const PaymentResult({
    required this.paymentMethod,
    required this.paymentStatus,
    this.transactionId,
  });

  final String paymentMethod;
  final String paymentStatus;
  final String? transactionId;

  bool get isPaid => paymentStatus == PaymentStatus.paid;

  factory PaymentResult.cashPending() {
    return const PaymentResult(
      paymentMethod: 'cash',
      paymentStatus: PaymentStatus.pending,
    );
  }
}

class PaymentStatus {
  static const String paid = 'PAID';
  static const String pending = 'PENDING';
  static const String failed = 'FAILED';
}
