import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/services/currency_service.dart';

void main() {
  group('CurrencyService.toStripeMinorUnits', () {
    test('converts EUR amounts to cents', () {
      expect(CurrencyService.toStripeMinorUnits(10.5, 'EUR'), 1050);
      expect(CurrencyService.toStripeMinorUnits(0.5, 'eur'), 50);
    });

    test('uses major units for zero-decimal currencies', () {
      expect(CurrencyService.toStripeMinorUnits(50000, 'IDR'), 50000);
      expect(CurrencyService.toStripeMinorUnits(50000, 'idr'), 50000);
    });
  });
}
