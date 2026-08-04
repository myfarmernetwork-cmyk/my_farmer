import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/features/buyer/storefront_product_grid.dart';
import 'package:my_farmer/models/product.dart';

Product _testProduct(String id, String name) {
  return Product(
    id: id,
    name: name,
    description: name,
    price: 1,
    imageUrl: '',
    category: 'vegetables',
    productionType: 'organic',
    sellerId: 'seller',
    sellerName: 'Seller',
    lat: 0,
    lng: 0,
    createdAt: Timestamp.now(),
  );
}

void main() {
  testWidgets('StorefrontProductGrid.buildSliver renders product cells', (tester) async {
    final products = [
      _testProduct('1', 'A'),
      _testProduct('2', 'B'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CustomScrollView(
              slivers: [
                StorefrontProductGrid(
                  products: products,
                  itemBuilder: (_, product) => ColoredBox(
                    color: Colors.green,
                    child: Text(product.name),
                  ),
                ).buildSliver(context),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('StorefrontProductGrid lays out all product cells', (tester) async {
    final products = [
      _testProduct('1', 'A'),
      _testProduct('2', 'B'),
      _testProduct('3', 'C'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: StorefrontProductGrid(
                products: products,
                itemBuilder: (_, product) => ColoredBox(
                  color: Colors.green,
                  child: Text(product.name),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });
}
