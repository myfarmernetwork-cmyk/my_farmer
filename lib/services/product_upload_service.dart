import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import '../config/subscription_limits.dart';
import '../models/subscription_tier.dart';
import '../models/user_roles.dart';
import '../models/plant_scan_result.dart';
import '../utils/product_categories.dart';
import '../utils/upcoming_product_helper.dart';

/// Pod-kategorija (sub-tag) unutar glavne industrijske kategorije tvrtke.
class CompanySubTag {
  const CompanySubTag({
    required this.id,
    required this.hr,
    required this.de,
    required this.searchKeywords,
  });

  final String id;
  final String hr;
  final String de;
  final List<String> searchKeywords;
}

/// Glavna industrijska kategorija za ulogu tvrtke (company / pharmacy).
class CompanyProductCategory {
  const CompanyProductCategory({
    required this.id,
    required this.hr,
    required this.de,
    this.subTags = const [],
    this.searchKeywords = const [],
  });

  final String id;
  final String hr;
  final String de;
  final List<CompanySubTag> subTags;
  final List<String> searchKeywords;

  bool get hasSubTags => subTags.isNotEmpty;
}

/// Rezultat AI prepoznavanja kategorije s fotografije.
class ProductCategoryMatch {
  const ProductCategoryMatch({
    required this.categoryId,
    this.subTagId,
    this.searchTags = const [],
    this.confidence = 0,
  });

  final String categoryId;
  final String? subTagId;
  final List<String> searchTags;
  final double confidence;
}

/// Kompletan AI rezultat s fotografije proizvoda (kategorija + tekstualni prijedlozi).
class ProductImageAnalysis {
  const ProductImageAnalysis({
    required this.categoryMatch,
    this.suggestedName,
    this.suggestedDescription,
  });

  final ProductCategoryMatch categoryMatch;
  final String? suggestedName;
  final String? suggestedDescription;
}

/// Provjera limita aktivnih artikala na tržnici po ulozi:
/// - Kupac: prodaja zabranjena (0 artikala).
/// - Hobi Farmer: max 5 aktivnih artikala (besplatno i s Premiumom).
/// - Pro Farmer: neograničeno besplatno (9999).
/// - Veterinar: 5 besplatno, neograničeno uz Premium 9,99 €/mj.
/// - Tvrtka: 5 besplatno, neograničeno uz Business 19,99 €/mj.
class ProductUploadService {
  ProductUploadService._();

  static const double companySubscriptionMonthlyEur = 19.99;

  /// Konačnih 8 glavnih industrijskih kategorija za tvrtku.
  static const List<CompanyProductCategory> companyCategories = [
    CompanyProductCategory(
      id: 'seeds_planting',
      hr: 'Sjeme i sadni materijal',
      de: 'Saatgut und Pflanzmaterial',
      searchKeywords: [
        'sjeme',
        'seed',
        'saatgut',
        'sadnica',
        'sadni',
        'pflanz',
        'setzling',
        'kukuruz',
        'corn',
        'mais',
        'pšenica',
        'wheat',
        'weizen',
      ],
    ),
    CompanyProductCategory(
      id: 'fertilizers_stimulants',
      hr: 'Đubriva i stimulansi',
      de: 'Düngemittel und Stimulanzien',
      searchKeywords: [
        'đubriv',
        'gnojiv',
        'dünger',
        'fertil',
        'stimul',
        'npk',
        'humus',
        'kompost',
        'compost',
      ],
    ),
    CompanyProductCategory(
      id: 'plant_protection',
      hr: 'Zaštita bilja',
      de: 'Pflanzenschutz',
      subTags: const [
        CompanySubTag(
          id: 'herbicides',
          hr: 'Herbicidi',
          de: 'Herbizide',
          searchKeywords: [
            'herbicid',
            'korov',
            'weed',
            'glyphos',
            'glifos',
            'roundup',
          ],
        ),
        CompanySubTag(
          id: 'fungicides',
          hr: 'Fungicidi',
          de: 'Fungizide',
          searchKeywords: [
            'fungicid',
            'gljiv',
            'fungus',
            'mildew',
            'plijesan',
            'pilz',
          ],
        ),
        CompanySubTag(
          id: 'insecticides',
          hr: 'Insekticidi',
          de: 'Insektizide',
          searchKeywords: [
            'insekticid',
            'insekt',
            'buba',
            'pest',
            'šteć',
          ],
        ),
        CompanySubTag(
          id: 'acaricides',
          hr: 'Akaricidi',
          de: 'Akarizide',
          searchKeywords: [
            'akaricid',
            'miticid',
            'grinja',
            'mite',
            'milbe',
          ],
        ),
        CompanySubTag(
          id: 'other_protection',
          hr: 'Ostala sredstva zaštite',
          de: 'Sonstige Schutzmittel',
          searchKeywords: [
            'puž',
            'snail',
            'schnecke',
            'mollusk',
            'zaštit',
            'schutz',
            'pesticid',
          ],
        ),
      ],
      searchKeywords: [
        'zaštita bilja',
        'pflanzenschutz',
        'pesticid',
        'fitofarm',
        'agro kem',
      ],
    ),
    CompanyProductCategory(
      id: 'animal_care',
      hr: 'Zaštita i njega životinja',
      de: 'Tierschutz und Tierpflege',
      searchKeywords: [
        'ovratnic',
        'collar',
        'halsband',
        'krpelj',
        'tick',
        'zecken',
        'buba',
        'flea',
        'floh',
        'šampon',
        'shampoo',
        'sprej',
        'spray',
        'ljubim',
        'pet',
        'stoka',
        'tierpflege',
        'tierschutz',
        'veterinar',
      ],
    ),
    CompanyProductCategory(
      id: 'farm_machinery',
      hr: 'Poljoprivredna mehanizacija i rezervni dijelovi',
      de: 'Landmaschinen und Ersatzteile',
      searchKeywords: [
        'traktor',
        'tractor',
        'kombajn',
        'harvester',
        'plug',
        'plug',
        'račalo',
        'dijel',
        'ersatzteil',
        'landmasch',
        'mehaniz',
        'motor',
        'gume',
        'filter',
      ],
    ),
    CompanyProductCategory(
      id: 'farm_equipment',
      hr: 'Oprema za farme i zaštićene prostore',
      de: 'Ausrüstung für Farmen und Schutzräume',
      searchKeywords: [
        'plastenik',
        'greenhouse',
        'gewächshaus',
        'navlaka',
        'folija',
        'folie',
        'suzavač',
        'ventilator',
        'grijanje',
        'heizung',
        'farm oprema',
        'schutzraum',
      ],
    ),
    CompanyProductCategory(
      id: 'garden_tools',
      hr: 'Alati za vrt i prateća oprema',
      de: 'Gartenwerkzeuge und Zubehör',
      searchKeywords: [
        'vrt',
        'garden',
        'garten',
        'motika',
        'lopata',
        'shovel',
        'grablje',
        'rake',
        'makaza',
        'shear',
        'cijev',
        'hose',
        'prskalic',
        'sprayer',
      ],
    ),
    CompanyProductCategory(
      id: 'animal_feed',
      hr: 'Stočna hrana i dodatci stočnoj ishrani',
      de: 'Futtermittel und Futterzusatzstoffe',
      searchKeywords: [
        'hrana',
        'feed',
        'futter',
        'stočn',
        'pellet',
        'krmivo',
        'mineral',
        'lick',
        'sijeno',
        'hay',
        'heu',
        'konzentrat',
      ],
    ),
  ];

  static List<String> get companyCategoryIds =>
      companyCategories.map((c) => c.id).toList();

  static CompanyProductCategory? categoryById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final cat in companyCategories) {
      if (cat.id == id) return cat;
    }
    return null;
  }

  static CompanySubTag? subTagById(String categoryId, String? subTagId) {
    final cat = categoryById(categoryId);
    if (cat == null || subTagId == null) return null;
    for (final tag in cat.subTags) {
      if (tag.id == subTagId) return tag;
    }
    return null;
  }

  static String companyCategoryLabel(String id, String languageCode) {
    final cat = categoryById(id);
    if (cat == null) return id;
    final key = 'company_cat_$id';
    final translated = key.tr();
    if (translated != key) return translated;
    return languageCode == 'de' ? cat.de : cat.hr;
  }

  static String companySubTagLabel(
    String categoryId,
    String subTagId,
    String languageCode,
  ) {
    final tag = subTagById(categoryId, subTagId);
    if (tag == null) return subTagId;
    final key = 'company_subtag_$subTagId';
    final translated = key.tr();
    if (translated != key) return translated;
    return languageCode == 'de' ? tag.de : tag.hr;
  }

  static String normalizeCompanyCategory(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    for (final cat in companyCategories) {
      if (cat.id == value) return cat.id;
      if (cat.hr.toLowerCase() == value) return cat.id;
      if (cat.de.toLowerCase() == value) return cat.id;
    }
    return companyCategories.first.id;
  }

  static List<String> categoryCodesForRole(String? role) {
    if (UpcomingProductHelper.isCompanyRole(role)) {
      return companyCategoryIds;
    }
    return ProductCategories.sellerCodes;
  }

  static String categoryLabelForRole({
    required String? role,
    required String code,
    required String languageCode,
  }) {
    if (UpcomingProductHelper.isCompanyRole(role)) {
      return companyCategoryLabel(code, languageCode);
    }
    return ProductCategories.label(code);
  }

  static bool requiresSubTag(String? role, String categoryId) {
    if (!UpcomingProductHelper.isCompanyRole(role)) return false;
    return categoryId == 'plant_protection';
  }

  static int maxActiveProducts(AppUser user) => user.maxProductSlots;

  static bool canAddProduct({
    required AppUser user,
    required int currentActiveCount,
    required bool isService,
  }) {
    if (isService) {
      return user.role == UserRole.professionalFarmer;
    }
    if (!SubscriptionLimits.canSellOnMarketplace(user.role)) {
      return false;
    }
    return currentActiveCount < maxActiveProducts(user);
  }

  static bool isAtProductLimit({
    required AppUser user,
    required int currentActiveCount,
    required bool isService,
  }) {
    return !canAddProduct(
      user: user,
      currentActiveCount: currentActiveCount,
      isService: isService,
    );
  }

  static bool vetCanAddPharmacyProduct({
    required AppUser user,
    required int currentActiveCount,
  }) {
    if (user.role != UserRole.veterinarian) return false;
    return UserRoleRules.canUseVetMarketplace(user) &&
        currentActiveCount < UserRoleRules.vetMarketplaceLimit(user);
  }

  static Future<int> countActiveProducts(String sellerId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: sellerId)
        .where('isService', isEqualTo: false)
        .get();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      if (data['requiresFinalPhoto'] == true) return false;
      if (data['isSoldOut'] == true) return false;
      return true;
    }).length;
  }

  static bool sellerHasMarketplaceBoost(AppUser user) =>
      SubscriptionLimits.sellerHasMarketplaceBoost(
        role: user.role,
        tier: SubscriptionTierX.fromFirestore(user.subscriptionTier),
      );

  /// Brza pozadinska analiza fotografije — samo lokalna logika, bez Plant.id API-ja
  /// (ne troši AI skener kredite ni Kindwise API pozive).
  static Future<ProductImageAnalysis?> analyzeProductFromImage({
    required File imageFile,
    required String? role,
    String languageCode = 'hr',
  }) async {
    // Namjerno bez Plant.id: prepoznavanje pri dodavanju proizvoda ne smije trošiti
    // Kindwise kredite. Farmer ručno unosi naziv; kategorija se bira u formi.
    return null;
  }

  /// Brza pozadinska AI klasifikacija kategorije preko Plant.id Vision API-ja.
  static Future<ProductCategoryMatch?> classifyProductFromImage({
    required File imageFile,
    required String? role,
    String languageCode = 'hr',
  }) async {
    final analysis = await analyzeProductFromImage(
      imageFile: imageFile,
      role: role,
      languageCode: languageCode,
    );
    return analysis?.categoryMatch;
  }

  static String? _suggestProductName({
    required PlantScanResult scan,
    required ProductCategoryMatch match,
    required String? role,
    required String languageCode,
  }) {
    final common = scan.commonName?.trim();
    if (common != null &&
        common.isNotEmpty &&
        common.toLowerCase() != 'unknown') {
      return common;
    }

    if (UpcomingProductHelper.isCompanyRole(role)) {
      final categoryLabel = companyCategoryLabel(match.categoryId, languageCode);
      if (match.subTagId != null) {
        final subLabel = companySubTagLabel(
          match.categoryId,
          match.subTagId!,
          languageCode,
        );
        return '$subLabel — $categoryLabel';
      }
      return categoryLabel;
    }

    if (scan.scientificName != null && scan.scientificName!.trim().isNotEmpty) {
      return scan.scientificName!.trim();
    }

    return ProductCategories.label(match.categoryId);
  }

  static String? _suggestProductDescription({
    required PlantScanResult scan,
    required ProductCategoryMatch match,
    required String? role,
    required String languageCode,
  }) {
    final parts = <String>[];

    if (UpcomingProductHelper.isCompanyRole(role)) {
      parts.add(
        companyCategoryLabel(match.categoryId, languageCode),
      );
      if (match.subTagId != null) {
        parts.add(
          companySubTagLabel(
            match.categoryId,
            match.subTagId!,
            languageCode,
          ),
        );
      }
    } else {
      parts.add(ProductCategories.label(match.categoryId));
    }

    final scientific = scan.scientificName?.trim();
    if (scientific != null && scientific.isNotEmpty) {
      parts.add(
        languageCode == 'de'
            ? 'Wissenschaftlicher Name: $scientific'
            : 'Znanstveni naziv: $scientific',
      );
    }

    if (scan.diseases.isNotEmpty) {
      final disease = scan.diseases.first;
      final label = disease.localName?.trim().isNotEmpty == true
          ? disease.localName!.trim()
          : disease.name.trim();
      if (label.isNotEmpty) {
        parts.add(label);
      }
      final details = disease.description?.trim();
      if (details != null && details.isNotEmpty) {
        parts.add(details);
      }
    }

    final text = parts
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('\n');

    return text.isEmpty ? null : text;
  }

  static String _buildVisionCorpus(PlantScanResult scan) {
    final parts = <String>[
      scan.commonName ?? '',
      scan.scientificName ?? '',
    ];
    for (final disease in scan.diseases) {
      parts.add(disease.name);
      parts.add(disease.localName ?? '');
      parts.add(disease.description ?? '');
    }
    return parts.join(' ').toLowerCase();
  }

  static ProductCategoryMatch _matchCompanyCategory(String corpus) {
    var bestCategory = companyCategories.first.id;
    String? bestSubTag;
    var bestScore = 0.0;
    final tags = <String>{};

    for (final cat in companyCategories) {
      var score = _keywordScore(corpus, cat.searchKeywords);
      String? matchedSub;

      for (final sub in cat.subTags) {
        final subScore = _keywordScore(corpus, sub.searchKeywords);
        if (subScore > score) {
          score = subScore;
          matchedSub = sub.id;
          tags.addAll(sub.searchKeywords);
          tags.add(sub.hr.toLowerCase());
          tags.add(sub.de.toLowerCase());
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestCategory = cat.id;
        bestSubTag = matchedSub ??
            (cat.id == 'plant_protection' ? 'other_protection' : null);
        tags.addAll(cat.searchKeywords);
        tags.add(cat.hr.toLowerCase());
        tags.add(cat.de.toLowerCase());
      }
    }

    if (bestScore <= 0) {
      return ProductCategoryMatch(
        categoryId: 'plant_protection',
        subTagId: 'other_protection',
        searchTags: ['zaštita bilja', 'pflanzenschutz'],
        confidence: 0.1,
      );
    }

    return ProductCategoryMatch(
      categoryId: bestCategory,
      subTagId: bestCategory == 'plant_protection' ? bestSubTag : null,
      searchTags: tags.where((t) => t.trim().isNotEmpty).toList(),
      confidence: bestScore,
    );
  }

  static ProductCategoryMatch _matchFarmerCategory(
    String corpus,
    PlantScanResult scan,
  ) {
    const fruitHints = [
      'jabuk',
      'apple',
      'šljiv',
      'plum',
      'trešnj',
      'cherry',
      'malin',
      'berry',
      'grožđ',
      'grape',
      'obst',
      'fruit',
      'voće',
    ];
    const cerealHints = [
      'pšenic',
      'wheat',
      'kukuruz',
      'corn',
      'mais',
      'ječam',
      'barley',
      'žitar',
      'getreide',
      'cereal',
    ];
    const animalHints = [
      'krava',
      'cow',
      'ovca',
      'sheep',
      'koza',
      'goat',
      'svinja',
      'pig',
      'perad',
      'poultry',
      'stoka',
      'livestock',
    ];
    const mechanizationHints = [
      'traktor',
      'tractor',
      'stroj',
      'machine',
      'alat',
      'tool',
    ];

    if (_keywordScore(corpus, mechanizationHints) >= 2) {
      return ProductCategoryMatch(
        categoryId: ProductCategories.mechanization,
        searchTags: mechanizationHints,
        confidence: 0.7,
      );
    }
    if (_keywordScore(corpus, animalHints) >= 2) {
      return ProductCategoryMatch(
        categoryId: ProductCategories.animals,
        searchTags: animalHints,
        confidence: 0.7,
      );
    }
    if (_keywordScore(corpus, cerealHints) >= 1) {
      return ProductCategoryMatch(
        categoryId: ProductCategories.cereals,
        searchTags: cerealHints,
        confidence: 0.6,
      );
    }
    if (_keywordScore(corpus, fruitHints) >= 1) {
      return ProductCategoryMatch(
        categoryId: ProductCategories.fruit,
        searchTags: fruitHints,
        confidence: 0.6,
      );
    }

    if (scan.isPlant) {
      return ProductCategoryMatch(
        categoryId: ProductCategories.vegetables,
        searchTags: [
          scan.commonName ?? '',
          scan.scientificName ?? '',
        ].where((s) => s.isNotEmpty).toList(),
        confidence: scan.identificationConfidence,
      );
    }

    return ProductCategoryMatch(
      categoryId: ProductCategories.other,
      confidence: 0.2,
    );
  }

  static double _keywordScore(String corpus, List<String> keywords) {
    var score = 0.0;
    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;
      if (corpus.contains(keyword.toLowerCase())) {
        score += keyword.length >= 5 ? 2 : 1;
      }
    }
    return score;
  }

  static List<String> buildSearchTags({
    required String? role,
    required String categoryId,
    String? subTagId,
    List<String> aiTags = const [],
  }) {
    final tags = <String>{...aiTags.map((t) => t.toLowerCase())};

    if (UpcomingProductHelper.isCompanyRole(role)) {
      final cat = categoryById(categoryId);
      if (cat != null) {
        tags.add(cat.hr.toLowerCase());
        tags.add(cat.de.toLowerCase());
        tags.add(cat.id);
      }
      final sub = subTagById(categoryId, subTagId);
      if (sub != null) {
        tags.addAll(sub.searchKeywords.map((k) => k.toLowerCase()));
        tags.add(sub.hr.toLowerCase());
        tags.add(sub.de.toLowerCase());
        tags.add(sub.id);
      }
    } else {
      tags.add(ProductCategories.normalize(categoryId));
    }

    return tags.where((t) => t.trim().isNotEmpty).toList();
  }
}
