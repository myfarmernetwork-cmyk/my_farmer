import 'package:easy_localization/easy_localization.dart';

/// Production type filter / product metadata codes.
class ProductionTypes {
  static const all = 'all';
  static const conventional = 'conventional';
  static const organic = 'organic';

  static const filterCodes = [all, conventional, organic];

  static String normalize(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    switch (value) {
      case 'all':
      case 'sve':
        return all;
      case 'conventional':
      case 'konvencionalna':
        return conventional;
      case 'organic':
      case 'organska':
      case 'bio':
        return organic;
      default:
        return conventional;
    }
  }

  static String labelKey(String code) => 'prod_type_${normalize(code)}';

  static String label(String code) => labelKey(code).tr();
}
