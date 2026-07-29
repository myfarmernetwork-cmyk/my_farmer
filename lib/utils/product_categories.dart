import 'package:easy_localization/easy_localization.dart';

/// Canonical category codes stored in Firestore (legacy Croatian labels are normalized on read).
class ProductCategories {
  static const all = 'all';
  static const vegetables = 'vegetables';
  static const fruit = 'fruit';
  static const cereals = 'cereals';
  static const animals = 'animals';
  static const mechanization = 'mechanization';
  static const other = 'other';

  static const filterCodes = [
    all,
    vegetables,
    fruit,
    cereals,
    animals,
    mechanization,
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
      case 'ostalo':
      case 'other':
        return other;
      default:
        if (value.isEmpty) return other;
        return other;
    }
  }

  static String labelKey(String code) => 'cat_${normalize(code)}';

  static String label(String code) => labelKey(code).tr();
}
