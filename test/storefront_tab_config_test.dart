import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/features/buyer/storefront_tab_config.dart';

void main() {
  group('StorefrontTabConfig', () {
    test('hobby farmer: products + gallery', () {
      final config = StorefrontTabConfig.fromRole('hobby_farmer');
      expect(config.tabCount, 2);
      expect(config.showServicesTab, isFalse);
    });

    test('professional farmer: products + services + gallery', () {
      final config = StorefrontTabConfig.fromRole('professional_farmer');
      expect(config.tabCount, 3);
      expect(config.showServicesTab, isTrue);
    });

    test('company / pharmacy: products + gallery', () {
      final config = StorefrontTabConfig.fromRole('pharmacy');
      expect(config.tabCount, 2);
      expect(config.showServicesTab, isFalse);
    });

    test('veterinarian: products + gallery', () {
      final config = StorefrontTabConfig.fromRole('veterinarian');
      expect(config.tabCount, 2);
      expect(config.showServicesTab, isFalse);
    });

    test('role aliases normalize consistently', () {
      expect(
        StorefrontTabConfig.fromRole('pro_farmer').tabCount,
        3,
      );
      expect(
        StorefrontTabConfig.fromRole('firma').showServicesTab,
        isFalse,
      );
      expect(
        StorefrontTabConfig.fromRole('veterinar').tabCount,
        2,
      );
    });

    test('seller data resolves role from profile fields', () {
      final config = StorefrontTabConfig.fromSellerData({
        'role': 'buyer',
        'companyRegistrationNumber': '12345678901',
      });
      expect(config.canonicalRole, 'pharmacy');
      expect(config.tabCount, 2);
    });
  });
}
