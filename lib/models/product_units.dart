import 'package:easy_localization/easy_localization.dart';

/// Canonical unit codes stored in Firestore; legacy labels are normalized on read.
class ProductUnits {
  static const productUnits = ['kom', 'pak', 'l', 'kg', 'g', 'ml', 't'];
  static const servicePriceUnits = ['dunum', 'hektar', 'sat'];

  static const _kom = 'kom';
  static const _pak = 'pak';
  static const _l = 'l';
  static const _kg = 'kg';
  static const _g = 'g';
  static const _ml = 'ml';
  static const _t = 't';
  static const _dunum = 'dunum';
  static const _hektar = 'hektar';
  static const _sat = 'sat';

  static String normalize(String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'kom':
      case 'komad':
      case 'pcs':
      case 'pc':
      case 'piece':
      case 'pieces':
      case 'stk':
      case 'stück':
      case 'stuck':
      case 'stueck':
        return _kom;
      case 'pak':
      case 'package':
      case 'pack':
      case 'paket':
      case 'pakiranje':
        return _pak;
      case 'l':
      case 'litra':
      case 'liter':
      case 'litre':
        return _l;
      case 'kg':
      case 'kilogram':
        return _kg;
      case 'g':
      case 'gram':
        return _g;
      case 'ml':
      case 'mililitar':
      case 'milliliter':
        return _ml;
      case 't':
      case 'tona':
      case 'ton':
        return _t;
      case 'dunum':
        return _dunum;
      case 'hektar':
      case 'hectare':
      case 'ha':
        return _hektar;
      case 'sat':
      case 'hour':
      case 'hr':
      case 'h':
      case 'std':
      case 'std.':
        return _sat;
      default:
        if (unit.trim().isEmpty) return '';
        return _kom;
    }
  }

  static bool isPak(String unit) => normalize(unit) == _pak;

  static String shortLabelKey(String unit) {
    switch (normalize(unit)) {
      case _kom:
        return 'unit_kom';
      case _pak:
        return 'unit_pak';
      case _l:
        return 'unit_l';
      case _kg:
        return 'unit_kg';
      case _g:
        return 'unit_g';
      case _ml:
        return 'unit_ml';
      case _t:
        return 'unit_t';
      case _dunum:
        return 'unit_dunum';
      case _hektar:
        return 'unit_hektar';
      case _sat:
        return 'unit_sat';
      default:
        return 'unit_kom';
    }
  }

  /// Localized short unit label; falls back to canonical code (kg, kom, pak…).
  static String shortLabel(String unit) {
    final normalized = normalize(unit);
    final key = shortLabelKey(unit);
    final translated = key.tr();
    if (translated == key || translated.contains('unit_')) {
      return normalized;
    }
    return translated;
  }

  /// Longer label for dropdowns (e.g. "komad (kom)").
  static String dropdownLabel(String unit) {
    final key = '${shortLabelKey(unit)}_full';
    final translated = key.tr();
    if (translated == key) return shortLabel(unit);
    return translated;
  }

  @Deprecated('Use shortLabel or dropdownLabel')
  static String label(String unit) => dropdownLabel(unit);
}
