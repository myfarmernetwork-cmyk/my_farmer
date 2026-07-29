import 'package:cloud_firestore/cloud_firestore.dart';



import '../services/product_upload_service.dart';
import '../utils/product_categories.dart';

import '../utils/production_types.dart';
import '../utils/upcoming_product_helper.dart';

import '../services/currency_service.dart';

import 'product_units.dart';



class Product {

  final String id;

  final String name;

  final String description;

  final String? skuCode;

  final String? productDescription;

  final double price;

  final String originalCurrency;

  final String unit;

  final String servicePriceUnit;

  final String unitDescription;

  final String imageUrl;

  final String category;

  final String? subCategory;

  final List<String> searchTags;

  final String productionType;

  final String sellerId;

  final String sellerName;

  final double lat;

  final double lng;

  final bool isService;

  final double stock;

  final bool isSoldOut;

  final bool isUpcoming;

  final DateTime? harvestDateTime;

  final String upcomingMode;

  final bool requiresFinalPhoto;

  final Timestamp createdAt;



  Product({

    required this.id,

    required this.name,

    required this.description,

    this.skuCode,

    this.productDescription,

    required this.price,

    this.originalCurrency = CurrencyService.bam,

    this.unit = 'kom',

    this.servicePriceUnit = '',

    this.unitDescription = '',

    required this.imageUrl,

    required this.category,

    this.subCategory,

    this.searchTags = const [],

    required this.productionType,

    required this.sellerId,

    required this.sellerName,

    required this.lat,

    required this.lng,

    this.isService = false,

    this.stock = 999.0,

    this.isSoldOut = false,

    this.isUpcoming = false,

    this.harvestDateTime,

    this.upcomingMode = UpcomingProductHelper.harvestMode,

    this.requiresFinalPhoto = false,

    required this.createdAt,

  });



  String get displayUnit =>

      isService && servicePriceUnit.isNotEmpty ? servicePriceUnit : unit;



  /// Canonical unit code for storage and filtering.

  String get normalizedDisplayUnit => ProductUnits.normalize(displayUnit);



  /// Localized short unit label for UI (e.g. kom, kg, pak).

  String get localizedDisplayUnit => ProductUnits.shortLabel(displayUnit);



  String get categoryCode {
    if (ProductUploadService.categoryById(category) != null) {
      return category;
    }
    return ProductCategories.normalize(category);
  }

  String categoryLabel(String languageCode) {
    if (ProductUploadService.categoryById(category) != null) {
      return ProductUploadService.companyCategoryLabel(category, languageCode);
    }
    return ProductCategories.label(categoryCode);
  }

  String get localizedCategory => categoryLabel('hr');



  bool get isUnavailable => isSoldOut || stock <= 0;



  bool get isVisibleToBuyers => !requiresFinalPhoto;



  bool get isHarvestCountdownActive {

    if (!isUpcoming || requiresFinalPhoto || isService) return false;

    final harvest = harvestDateTime;

    if (harvest == null) return false;

    return harvest.isAfter(DateTime.now());

  }



  bool get needsHarvestTransition {

    if (!isUpcoming || requiresFinalPhoto || isService) return false;

    final harvest = harvestDateTime;

    if (harvest == null) return false;

    return !harvest.isAfter(DateTime.now());

  }



  bool get isAwaitingFinalPhoto => requiresFinalPhoto;

  bool get isDeliveryUpcoming =>
      UpcomingProductHelper.isDeliveryMode(upcomingMode);



  static String _resolveStoredCategory(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (ProductUploadService.categoryById(value) != null) return value;
    return ProductCategories.normalize(raw);
  }

  static DateTime? _parseDateTime(dynamic raw) {

    if (raw is Timestamp) return raw.toDate();

    if (raw is DateTime) return raw;

    if (raw is String) return DateTime.tryParse(raw);

    return null;

  }



  factory Product.fromFirestore(DocumentSnapshot doc) {

    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;



    double parsedPrice = 0.0;

    var rawPrice = data['price'];

    if (rawPrice is num) {

      parsedPrice = rawPrice.toDouble();

    } else if (rawPrice is String) {

      parsedPrice = double.tryParse(rawPrice) ?? 0.0;

    }



    double parsedStock = 999.0;

    final rawStock = data['stock'];

    if (rawStock is num) {

      parsedStock = rawStock.toDouble();

    } else if (rawStock is String) {

      parsedStock = double.tryParse(rawStock) ?? 999.0;

    }



    double parsedLat = 0.0;

    double parsedLng = 0.0;

    if (data['location'] != null) {

      parsedLat = (data['location']['lat'] ?? 0.0).toDouble();

      parsedLng = (data['location']['lng'] ?? 0.0).toDouble();

    }



    final isService = data['isService'] as bool? ?? false;



    return Product(

      id: doc.id,

      name: data['name'] ?? '',

      description: data['description'] ?? '',

      skuCode: data['skuCode'] as String?,

      productDescription: data['productDescription'] as String?,

      price: parsedPrice,

      originalCurrency: CurrencyService.normalizeCode(

        data['originalCurrency'] as String?,

      ),

      unit: ProductUnits.normalize(data['unit'] as String? ?? 'kom'),

      servicePriceUnit: ProductUnits.normalize(

        data['servicePriceUnit'] as String? ?? '',

      ),

      unitDescription: data['unitDescription'] as String? ?? '',

      imageUrl: data['imageUrl'] ?? '',

      category: _resolveStoredCategory(data['category']),

      subCategory: data['subCategory'] as String?,

      searchTags: (data['searchTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],

      productionType: ProductionTypes.normalize(data['productionType']),

      sellerId: data['sellerId'] ?? '',

      sellerName: data['sellerName'] ?? 'Farmer',

      lat: parsedLat,

      lng: parsedLng,

      isService: isService,

      stock: parsedStock,

      isSoldOut: data['isSoldOut'] as bool? ?? false,

      isUpcoming: data['isUpcoming'] as bool? ?? false,

      harvestDateTime: _parseDateTime(data['harvestDateTime']),

      upcomingMode: UpcomingProductHelper.normalizeMode(
        data['upcomingMode'] as String?,
      ),

      requiresFinalPhoto: data['requiresFinalPhoto'] as bool? ?? false,

      createdAt: data['createdAt'] ?? Timestamp.now(),

    );

  }



  Map<String, dynamic> toMap() {

    return {

      'name': name,

      'description': description,

      if (skuCode != null && skuCode!.trim().isNotEmpty) 'skuCode': skuCode!.trim(),

      if (productDescription != null && productDescription!.trim().isNotEmpty)
        'productDescription': productDescription!.trim(),

      'price': price,

      'originalCurrency': originalCurrency,

      'unit': unit,

      if (isService) 'servicePriceUnit': servicePriceUnit,

      if (unitDescription.trim().isNotEmpty)

        'unitDescription': unitDescription.trim(),

      'imageUrl': imageUrl,

      'category': category,

      if (subCategory != null && subCategory!.isNotEmpty) 'subCategory': subCategory,

      if (searchTags.isNotEmpty) 'searchTags': searchTags,

      'productionType': productionType,

      'sellerId': sellerId,

      'sellerName': sellerName,

      'location': {'lat': lat, 'lng': lng},

      'isService': isService,

      'stock': stock,

      'isSoldOut': isSoldOut,

      'isUpcoming': isUpcoming,

      if (harvestDateTime != null)

        'harvestDateTime': Timestamp.fromDate(harvestDateTime!),

      if (isUpcoming) 'upcomingMode': upcomingMode,

      'requiresFinalPhoto': requiresFinalPhoto,

      'createdAt': createdAt,

    };

  }

}

