import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/features/buyer/storefront_seller_data.dart';
import 'package:my_farmer/models/farmer_shop_settings.dart';
import 'package:my_farmer/utils/currency_region_parse.dart';

void main() {
  group('FarmerShopSettings.fromMap', () {
    test('uses safe defaults when delivery fields are missing', () {
      final settings = FarmerShopSettings.fromMap({
        'name': 'Dario',
        'workingDays': ['mon'],
      });

      expect(settings.deliveryDays, isEmpty);
      expect(settings.deliveryHoursFrom, '');
      expect(settings.deliveryHoursTo, '');
      expect(settings.deliveryZone1MaxKm, 0);
      expect(settings.deliveryZone1MinOrder, 0);
      expect(settings.deliveryZone2MaxKm, 0);
      expect(settings.deliveryZone2MinOrder, 0);
      expect(settings.maxDeliveryDistanceKm, 0);
      expect(settings.hasDeliveryZonesConfigured, isFalse);
      expect(settings.hasDeliveryScheduleConfigured, isFalse);
    });

    test('accepts malformed delivery values without throwing', () {
      final settings = FarmerShopSettings.fromMap({
        'deliveryDays': 'invalid',
        'deliveryHoursFrom': 123,
        'deliveryZone1MaxKm': '7.5',
        'deliveryZone1MinOrder': null,
        'offersDelivery': 'true',
      });

      expect(settings.deliveryDays, isEmpty);
      expect(settings.deliveryHoursFrom, '123');
      expect(settings.deliveryZone1MaxKm, 7.5);
      expect(settings.deliveryZone1MinOrder, 0);
      expect(settings.offersDelivery, isTrue);
    });

    test('fromMap(null) returns empty settings', () {
      final settings = FarmerShopSettings.fromMap(null);
      expect(settings.deliveryDays, isEmpty);
      expect(settings.deliveryHoursFrom, '');
      expect(settings.deliveryZone1MaxKm, 0);
    });
  });

  group('CurrencyRegionParse', () {
    test('normalizes bih aliases', () {
      expect(CurrencyRegionParse.normalize('bih'), 'bih');
      expect(CurrencyRegionParse.normalize('BA'), 'bih');
      expect(CurrencyRegionParse.normalize('Bosnia'), 'bih');
    });

    test('returns null for empty values', () {
      expect(CurrencyRegionParse.normalize(null), isNull);
      expect(CurrencyRegionParse.normalize(''), isNull);
    });

    test('orDefault falls back to eu for unknown values', () {
      expect(CurrencyRegionParse.orDefault('unknown'), 'eu');
      expect(CurrencyRegionParse.orDefault('bih'), 'bih');
    });
  });

  group('StorefrontSellerData', () {
    test('normalizes missing delivery fields and bih currency region', () {
      final seller = StorefrontSellerData.fromMap({
        'name': 'Dragana',
        'currencyRegion': 'bih',
      });

      expect(seller.currencyRegion, 'bih');
      expect(seller.raw['deliveryDays'], isEmpty);
      expect(seller.raw['deliveryHoursFrom'], '');
      expect(seller.raw['deliveryZone1MaxKm'], 0);
      expect(seller.raw['deliveryZone2MinOrder'], 0);
    });
  });
}
