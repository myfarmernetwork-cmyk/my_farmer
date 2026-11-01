import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_upload_service.dart';

/// Canonical category codes stored in Firestore (legacy Croatian labels are normalized on read).
class ProductCategories {
  static const all = 'all';
  static const vegetables = 'vegetables';
  static const fruit = 'fruit';
  static const cereals = 'cereals';
  static const animals = 'animals';
  static const mechanization = 'mechanization';
  static const fertilizersStimulants = 'fertilizers_stimulants';
  static const plantProtection = 'plant_protection';
  static const other = 'other';

  static const filterCodes = [
    all,
    vegetables,
    fruit,
    cereals,
    animals,
    mechanization,
    fertilizersStimulants,
    plantProtection,
  ];

  /// Redoslijed u 3×3 gridu tržišta (srednji slot donjeg reda prazan).
  static const gridFilterCodes = <String?>[
    all,
    vegetables,
    fruit,
    animals,
    cereals,
    mechanization,
    fertilizersStimulants,
    null,
    plantProtection,
  ];

  static const sellerCodes = [
    vegetables,
    fruit,
    cereals,
    animals,
    mechanization,
  ];

  static String normalize(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'all':
      case 'sve':
        return all;
      case 'vegetables':
      case 'povrće':
      case 'povrce':
      case 'gemüse':
      case 'gemuse':
        return vegetables;
      case 'fruit':
      case 'voće':
      case 'voce':
      case 'obst':
        return fruit;
      case 'cereals':
      case 'žitarice':
      case 'zitarice':
      case 'getreide':
        return cereals;
      case 'animals':
      case 'životinje':
      case 'zivotinje':
      case 'tiere':
        return animals;
      case 'mechanization':
      case 'mehanizacija':
      case 'mechanisierung':
        return mechanization;
      case 'fertilizers_stimulants':
      case 'đubriva i stimulansi':
      case 'dubriva i stimulansi':
      case 'düngemittel und stimulanzien':
        return fertilizersStimulants;
      case 'plant_protection':
      case 'zaštita bilja':
      case 'zastita bilja':
      case 'pflanzenschutz':
        return plantProtection;
      case 'ostalo':
      case 'other':
        return other;
      default:
        if (value.isEmpty) return other;
        return other;
    }
  }

  static String labelKey(String code) {
    if (code == fertilizersStimulants || code == plantProtection) {
      return 'company_cat_$code';
    }
    return 'cat_${normalize(code)}';
  }

  static String label(String code) {
    final key = labelKey(code);
    final translated = key.tr();
    if (translated != key) return translated;

    if (code == fertilizersStimulants || code == plantProtection) {
      final cat = ProductUploadService.categoryById(code);
      if (cat != null) return cat.hr;
    }

    return 'cat_${normalize(code)}'.tr();
  }

  /// Ikona za pločicu kategorije na tržištu.
  static IconData iconFor(String code) {
    switch (normalize(code)) {
      case all:
        return Icons.grid_view_rounded;
      case vegetables:
        return Icons.eco_rounded;
      case fruit:
        return Icons.local_florist_rounded;
      case cereals:
        return Icons.grain_rounded;
      case animals:
        return Icons.pets_rounded;
      case mechanization:
        return Icons.agriculture_rounded;
      case fertilizersStimulants:
        return Icons.science_rounded;
      case plantProtection:
        return Icons.shield_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// Popunjene (solid) ikone za premium scroll traku kategorija.
  static IconData solidIconFor(String code) {
    switch (normalize(code)) {
      case all:
        return Icons.grid_view;
      case vegetables:
        return Icons.eco;
      case fruit:
        return Icons.fastfood;
      case cereals:
        return Icons.grain;
      case animals:
        return Icons.pets;
      case mechanization:
        return Icons.agriculture;
      case fertilizersStimulants:
        return Icons.grass;
      case plantProtection:
        return Icons.biotech;
      default:
        return Icons.category;
    }
  }

  /// Prepoznatljiv simbol na pločici tržišta (mockup: mrkva, jabuka…).
  /// Vraća emoji u punoj boji; null = koristi [iconFor] (npr. „Sve“).
  static String? marketplaceSymbol(String code) {
    switch (normalize(code)) {
      case all:
        return null;
      case vegetables:
        return '🥕';
      case fruit:
        return '🍎';
      case cereals:
        return '🌾';
      case animals:
        return '🐄';
      case mechanization:
        return '🚜';
      case fertilizersStimulants:
        return '🧴';
      case plantProtection:
        return '🌿';
      default:
        return null;
    }
  }

  /// Firestore category codes that belong to a marketplace tab filter.
  static Set<String> productCodesForFilter(String filterCode) {
    switch (filterCode) {
      case all:
        return const {};
      case mechanization:
        return {
          mechanization,
          'farm_machinery',
          'farm_equipment',
          'garden_tools',
        };
      case fertilizersStimulants:
        return {fertilizersStimulants};
      case plantProtection:
        return {plantProtection};
      default:
        return {filterCode};
    }
  }

  static bool matchesMarketplaceFilter({
    required String filterCode,
    required String productCategoryCode,
  }) {
    if (filterCode == all) return true;
    return productCodesForFilter(filterCode).contains(productCategoryCode);
  }

  static bool matchesSearch(Product product, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    if (product.name.toLowerCase().contains(q)) return true;
    if (product.description.toLowerCase().contains(q)) return true;

    final productDescription = product.productDescription?.toLowerCase() ?? '';
    if (productDescription.contains(q)) return true;

    for (final tag in product.searchTags) {
      if (tag.toLowerCase().contains(q)) return true;
    }

    final companyCategory = ProductUploadService.categoryById(product.category);
    if (companyCategory != null) {
      if (companyCategory.id.contains(q)) return true;
      if (companyCategory.hr.toLowerCase().contains(q)) return true;
      if (companyCategory.de.toLowerCase().contains(q)) return true;
      for (final keyword in companyCategory.searchKeywords) {
        if (keyword.contains(q) || q.contains(keyword)) return true;
      }
      for (final subTag in companyCategory.subTags) {
        if (subTag.hr.toLowerCase().contains(q)) return true;
        if (subTag.de.toLowerCase().contains(q)) return true;
        for (final keyword in subTag.searchKeywords) {
          if (keyword.contains(q) || q.contains(keyword)) return true;
        }
      }
      return false;
    }

    final farmerCode = product.categoryCode;
    if (label(farmerCode).toLowerCase().contains(q)) return true;
    return farmerCode.contains(q);
  }
}
