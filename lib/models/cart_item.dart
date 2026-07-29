import '../services/currency_service.dart';



class CartItem {

  final String id;

  final String name;

  final double price;

  final String originalCurrency;

  final String unit;

  final String unitDescription;

  final double quantity;

  final String imageUrl;

  final String sellerId;

  final String sellerName;

  final bool isUpcoming;



  CartItem({

    required this.id,

    required this.name,

    required this.price,

    this.originalCurrency = CurrencyService.bam,

    this.unit = 'kom',

    this.unitDescription = '',

    this.quantity = 1.0,

    required this.imageUrl,

    required this.sellerId,

    required this.sellerName,

    this.isUpcoming = false,

  });



  double get lineTotal => price * quantity;



  CartItem copyWith({

    double? quantity,

    String? unit,

    String? unitDescription,

    String? originalCurrency,

    bool? isUpcoming,

  }) {

    return CartItem(

      id: id,

      name: name,

      price: price,

      originalCurrency: originalCurrency ?? this.originalCurrency,

      unit: unit ?? this.unit,

      unitDescription: unitDescription ?? this.unitDescription,

      quantity: quantity ?? this.quantity,

      imageUrl: imageUrl,

      sellerId: sellerId,

      sellerName: sellerName,

      isUpcoming: isUpcoming ?? this.isUpcoming,

    );

  }



  Map<String, dynamic> toJson() {

    return {

      'productId': id,

      'name': name,

      'price': price,

      'originalCurrency': originalCurrency,

      'unit': unit,

      if (unitDescription.trim().isNotEmpty) 'unitDescription': unitDescription,

      'quantity': quantity,

      'imageUrl': imageUrl,

      'isUpcoming': isUpcoming,

    };

  }

}

