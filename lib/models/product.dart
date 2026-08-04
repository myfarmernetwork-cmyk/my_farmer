import 'package:cloud_firestore/cloud_firestore.dart';



import '../services/product_upload_service.dart';
import '../utils/firestore_parse.dart';
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



  static ({double lat, double lng}) _readLocation(dynamic raw) {
    if (raw == null) return (lat: 0.0, lng: 0.0);
    if (raw is GeoPoint) {
      return (lat: raw.latitude, lng: raw.longitude);
    }
    if (raw is Map) {
      final latValue = raw['lat'] ?? raw['latitude'];
      final lngValue = raw['lng'] ?? raw['longitude'];
      return (
        lat: _readCoordinate(latValue),
        lng: _readCoordinate(lngValue),
      );
    }
    return (lat: 0.0, lng: 0.0);
  }

  static double _readCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = FirestoreParse.documentData(doc) ?? <String, dynamic>{};

    final parsedPrice = FirestoreParse.doubleOr(data['price']);
    final parsedStock = FirestoreParse.doubleOr(data['stock'], fallback: 999.0);

    final location = _readLocation(data['location']);
    final parsedLat = location.lat;
    final parsedLng = location.lng;

    final isService = FirestoreParse.boolOr(data['isService']);

    return Product(
      id: doc.id,
      name: FirestoreParse.stringOrEmpty(data['name']),
      description: FirestoreParse.stringOrEmpty(data['description']),
      skuCode: FirestoreParse.optionalString(data['skuCode']),
      productDescription:
          FirestoreParse.optionalString(data['productDescription']),
      price: parsedPrice,
      originalCurrency: CurrencyService.normalizeCode(
        FirestoreParse.optionalString(data['originalCurrency']),
      ),
      unit: ProductUnits.normalize(
        FirestoreParse.stringOrEmpty(data['unit'], fallback: 'kom'),
      ),
      servicePriceUnit: ProductUnits.normalize(
        FirestoreParse.stringOrEmpty(data['servicePriceUnit']),
      ),
      unitDescription: FirestoreParse.stringOrEmpty(data['unitDescription']),
      imageUrl: FirestoreParse.stringOrEmpty(data['imageUrl']),
      category: _resolveStoredCategory(data['category']),
      subCategory: FirestoreParse.optionalString(data['subCategory']),
      searchTags: FirestoreParse.stringListOrEmpty(data['searchTags']),
      productionType: ProductionTypes.normalize(data['productionType']),
      sellerId: FirestoreParse.stringOrEmpty(data['sellerId']),
      sellerName:
          FirestoreParse.stringOrEmpty(data['sellerName'], fallback: 'Farmer'),
      lat: parsedLat,
      lng: parsedLng,
      isService: isService,
      stock: parsedStock,
      isSoldOut: FirestoreParse.boolOr(data['isSoldOut']),
      isUpcoming: FirestoreParse.boolOr(data['isUpcoming']),
      harvestDateTime: _parseDateTime(data['harvestDateTime']),
      upcomingMode: UpcomingProductHelper.normalizeMode(
        FirestoreParse.optionalString(data['upcomingMode']),
      ),
      requiresFinalPhoto: FirestoreParse.boolOr(data['requiresFinalPhoto']),
      createdAt: FirestoreParse.timestampOrNow(data['createdAt']),
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

