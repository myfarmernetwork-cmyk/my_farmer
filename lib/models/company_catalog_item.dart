import 'package:cloud_firestore/cloud_firestore.dart';

/// Artikal u internom katalogu firme (prije objave na tržište).
class CompanyCatalogItem {
  final String id;
  final String sellerId;
  final String skuCode;
  final String name;
  final String productDescription;
  final double price;
  final double stock;
  final String unit;
  final String category;
  final String? publishedProductId;
  final DateTime? updatedAt;

  const CompanyCatalogItem({
    required this.id,
    required this.sellerId,
    required this.skuCode,
    required this.name,
    this.productDescription = '',
    required this.price,
    required this.stock,
    this.unit = 'kom',
    this.category = 'seeds_planting',
    this.publishedProductId,
    this.updatedAt,
  });

  bool get isPublished =>
      publishedProductId != null && publishedProductId!.isNotEmpty;

  bool get isLowStock => stock > 0 && stock <= 10;

  factory CompanyCatalogItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CompanyCatalogItem(
      id: doc.id,
      sellerId: data['sellerId'] as String? ?? '',
      skuCode: data['skuCode'] as String? ?? '',
      name: data['name'] as String? ?? '',
      productDescription: data['productDescription'] as String? ?? '',
      price: _asDouble(data['price']),
      stock: _asDouble(data['stock']),
      unit: data['unit'] as String? ?? 'kom',
      category: data['category'] as String? ?? 'seeds_planting',
      publishedProductId: data['publishedProductId'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'skuCode': skuCode.trim(),
      'name': name.trim(),
      'productDescription': productDescription.trim(),
      'price': price,
      'stock': stock,
      'unit': unit,
      'category': category,
      if (publishedProductId != null && publishedProductId!.isNotEmpty)
        'publishedProductId': publishedProductId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return 0;
  }
}
