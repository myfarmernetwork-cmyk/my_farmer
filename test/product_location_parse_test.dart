import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/models/product.dart';

void main() {
  test('Product.fromFirestore accepts GeoPoint location', () {
    final product = Product.fromFirestore(
      _FakeDoc({
        'name': 'Test',
        'description': 'Desc',
        'price': 5,
        'imageUrl': '',
        'category': 'vegetables',
        'productionType': 'organic',
        'sellerId': 'seller',
        'sellerName': 'Seller',
        'location': const GeoPoint(45.8, 15.9),
        'createdAt': Timestamp.now(),
      }),
    );

    expect(product.lat, closeTo(45.8, 0.001));
    expect(product.lng, closeTo(15.9, 0.001));
  });

  test('Product.fromFirestore accepts map location', () {
    final product = Product.fromFirestore(
      _FakeDoc({
        'name': 'Test',
        'description': 'Desc',
        'price': 5,
        'imageUrl': '',
        'category': 'vegetables',
        'productionType': 'organic',
        'sellerId': 'seller',
        'sellerName': 'Seller',
        'location': {'lat': 44.1, 'lng': 16.2},
        'createdAt': Timestamp.now(),
      }),
    );

    expect(product.lat, closeTo(44.1, 0.001));
    expect(product.lng, closeTo(16.2, 0.001));
  });
}

class _FakeDoc implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDoc(this._data, {this.id = 'test-product'});

  final Map<String, dynamic> _data;

  @override
  final String id;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
