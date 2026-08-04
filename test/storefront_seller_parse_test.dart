import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/features/buyer/storefront_seller_data.dart';
import 'package:my_farmer/models/product.dart';
import 'package:my_farmer/utils/firestore_parse.dart';

void main() {
  group('FirestoreParse', () {
    test('stringOrEmpty handles null and non-string values', () {
      expect(FirestoreParse.stringOrEmpty(null), '');
      expect(FirestoreParse.stringOrEmpty(42), '42');
      expect(FirestoreParse.stringOrEmpty('  Ana  '), 'Ana');
      expect(FirestoreParse.stringOrEmpty('null'), '');
    });

    test('boolOr handles bool, num, and string values', () {
      expect(FirestoreParse.boolOr(true), isTrue);
      expect(FirestoreParse.boolOr(1), isTrue);
      expect(FirestoreParse.boolOr('false'), isFalse);
      expect(FirestoreParse.boolOr(null, fallback: true), isTrue);
    });

    test('intOr handles int, double, and string values', () {
      expect(FirestoreParse.intOr(12), 12);
      expect(FirestoreParse.intOr(12.9), 12);
      expect(FirestoreParse.intOr('7'), 7);
      expect(FirestoreParse.intOr(null), 0);
    });

    test('stringListOrEmpty returns empty list for invalid values', () {
      expect(FirestoreParse.stringListOrEmpty(null), isEmpty);
      expect(FirestoreParse.stringListOrEmpty('bad'), isEmpty);
      expect(
        FirestoreParse.stringListOrEmpty(['Mon', 2, '']),
        ['Mon', '2'],
      );
    });
  });

  group('StorefrontSellerData', () {
    test('normalizes incomplete seller profile map', () {
      final seller = StorefrontSellerData.fromMap({
        'name': null,
        'profileImageUrl': 123,
        'reviewCount': 4.8,
        'isPublicProfile': 'true',
      });

      expect(seller.name, 'Farmer');
      expect(seller.profileImageUrl, '123');
      expect(seller.reviewCount, 4);
      expect(seller.isPublicProfile, isTrue);
      expect(seller.raw['workingDays'], isEmpty);
      expect(seller.raw['pickupDays'], isEmpty);
      expect(seller.raw['deliveryDays'], isEmpty);
    });

    test('fromMap(null) returns safe defaults', () {
      final seller = StorefrontSellerData.fromMap(null);

      expect(seller.name, 'Farmer');
      expect(seller.avgRating, 0);
      expect(seller.reviewCount, 0);
      expect(seller.isPublicProfile, isTrue);
    });
  });

  group('Product.fromFirestore', () {
    test('accepts missing and malformed fields without throwing', () {
      final product = Product.fromFirestore(
        _FakeDoc({
          'price': '12.5',
          'stock': null,
          'isService': 'true',
          'searchTags': 'invalid',
          'createdAt': null,
        }),
      );

      expect(product.name, '');
      expect(product.price, 12.5);
      expect(product.stock, 999);
      expect(product.isService, isTrue);
      expect(product.searchTags, isEmpty);
      expect(product.createdAt, isA<Timestamp>());
    });

    test('accepts null document data', () {
      final product = Product.fromFirestore(_FakeDoc(null));

      expect(product.id, 'test-product');
      expect(product.name, '');
      expect(product.sellerName, 'Farmer');
    });
  });
}

class _FakeDoc implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this._data, {this.id = 'test-product'});

  final Map<String, dynamic>? _data;

  @override
  final String id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
