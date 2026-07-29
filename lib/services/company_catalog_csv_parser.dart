import 'package:csv/csv.dart';

/// Strogi CSV parser za katalog firme — paket [csv], obavezna zaglavlja, validacija redova.
class CompanyCatalogCsvParser {
  CompanyCatalogCsvParser._();

  /// Kanonska zaglavlja (prvi stupac: sku ili barkod).
  static const requiredHeaders = [
    'naziv',
    'cijena',
    'zaliha',
    'jedinica',
  ];

  static const skuHeaderAliases = {'sku', 'barkod'};

  static const templateCsv = 'barkod,naziv,cijena,zaliha,jedinica\n'
      '4012345678901,NPK 15-15-15,45.99,120,kg\n'
      '87654321,Herbicid XYZ,29.50,45,l\n';

  static const templateCsvSemicolon = 'barkod;naziv;cijena;zaliha;jedinica\n'
      '4012345678901;NPK 15-15-15;45.99;120;kg\n'
      '87654321;Herbicid XYZ;29.50;45;l\n';

  /// Uklanja UTF-8 BOM s početka datoteke prije parsiranja.
  static String stripBom(String raw) {
    var content = raw;
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
    // Ako je BOM pogrešno dekodiran (npr. ï»¿ na početku datoteke).
    if (content.startsWith('ï»¿')) {
      content = content.substring(3);
    }
    return content;
  }

  /// Čisti BOM i slične artefakte iz ćelije zaglavlja.
  static String cleanHeaderCell(String cell) {
    var value = cell.trim().replaceAll('\uFEFF', '');
    if (value.startsWith('ï»¿')) {
      value = value.substring(3);
    }
    return value.trim();
  }

  /// Parsira CSV sadržaj. Baca [CompanyCatalogCsvParseException] pri grešci.
  static List<ParsedCatalogRow> parse(String raw) {
    final trimmed = stripBom(raw.trim());
    if (trimmed.isEmpty) {
      throw const CompanyCatalogCsvParseException('company_catalog_csv_empty_file');
    }

    final delimiter = _detectDelimiter(trimmed.split(RegExp(r'\r?\n')).first);
    final converter = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
    );

    List<List<dynamic>> rows;
    try {
      rows = converter.convert(trimmed);
    } catch (_) {
      throw const CompanyCatalogCsvParseException('company_catalog_csv_parse_failed');
    }

    if (rows.isEmpty) {
      throw const CompanyCatalogCsvParseException('company_catalog_csv_empty_file');
    }

    final headerRow =
        rows.first.map((c) => cleanHeaderCell(c.toString())).toList();
    final columnIndex = _validateAndMapHeaders(headerRow);

    if (rows.length < 2) {
      throw const CompanyCatalogCsvParseException('company_catalog_csv_no_data_rows');
    }

    final parsed = <ParsedCatalogRow>[];
    for (var i = 1; i < rows.length; i++) {
      final rowNumber = i + 1; // 1-based, uključujući zaglavlje
      final cells = rows[i].map((c) => c.toString().trim()).toList();

      final sku = _cell(cells, columnIndex['sku']!);
      final name = _cell(cells, columnIndex['naziv']!);
      final priceRaw = _cell(cells, columnIndex['cijena']!);
      final stockRaw = _cell(cells, columnIndex['zaliha']!);
      final unit = _cell(cells, columnIndex['jedinica']!);

      if (sku.isEmpty && name.isEmpty) continue;

      if (sku.isEmpty) {
        throw CompanyCatalogCsvParseException(
          'company_catalog_csv_row_sku_empty',
          namedArgs: {'row': '$rowNumber'},
        );
      }
      if (name.isEmpty) {
        throw CompanyCatalogCsvParseException(
          'company_catalog_csv_row_name_empty',
          namedArgs: {'row': '$rowNumber'},
        );
      }

      final price = _parseRequiredNumber(
        priceRaw,
        rowNumber: rowNumber,
        errorKey: 'company_catalog_csv_row_price_error',
      );
      final stock = _parseOptionalNumber(
        stockRaw,
        rowNumber: rowNumber,
        errorKey: 'company_catalog_csv_row_stock_error',
      );

      parsed.add(
        ParsedCatalogRow(
          skuCode: sku,
          name: name,
          price: price,
          stock: stock,
          unit: unit.isNotEmpty ? unit : 'kom',
        ),
      );
    }

    if (parsed.isEmpty) {
      throw const CompanyCatalogCsvParseException('company_catalog_csv_no_data_rows');
    }

    return parsed;
  }

  static String _detectDelimiter(String firstLine) {
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    return semicolons >= commas ? ';' : ',';
  }

  static Map<String, int> _validateAndMapHeaders(List<String> headers) {
    final normalized =
        headers.map((h) => cleanHeaderCell(h).toLowerCase()).toList();

    final missing = <String>[];
    final hasSkuColumn =
        normalized.any((h) => skuHeaderAliases.contains(h));
    if (!hasSkuColumn) {
      missing.add('barkod');
    }
    for (final required in requiredHeaders) {
      if (!normalized.contains(required)) {
        missing.add(required);
      }
    }

    if (missing.isNotEmpty) {
      throw CompanyCatalogCsvParseException(
        'company_catalog_csv_bad_headers',
        namedArgs: {'columns': missing.join(', ')},
      );
    }

    final map = <String, int>{};
    for (var i = 0; i < normalized.length; i++) {
      final h = normalized[i];
      if (skuHeaderAliases.contains(h) && !map.containsKey('sku')) {
        map['sku'] = i;
      }
      if (requiredHeaders.contains(h) && !map.containsKey(h)) {
        map[h] = i;
      }
    }

    if (!map.containsKey('sku')) {
      throw CompanyCatalogCsvParseException(
        'company_catalog_csv_bad_headers',
        namedArgs: {'columns': 'barkod'},
      );
    }
    for (final required in requiredHeaders) {
      if (!map.containsKey(required)) {
        throw CompanyCatalogCsvParseException(
          'company_catalog_csv_bad_headers',
          namedArgs: {'columns': required},
        );
      }
    }

    return map;
  }

  static String _cell(List<String> cells, int index) {
    if (index < 0 || index >= cells.length) return '';
    return cells[index].trim();
  }

  static double _parseRequiredNumber(
    String raw, {
    required int rowNumber,
    required String errorKey,
  }) {
    if (raw.trim().isEmpty) {
      throw CompanyCatalogCsvParseException(
        errorKey,
        namedArgs: {'row': '$rowNumber'},
      );
    }
    final value = _tryParseNumber(raw);
    if (value == null) {
      throw CompanyCatalogCsvParseException(
        errorKey,
        namedArgs: {'row': '$rowNumber'},
      );
    }
    return value;
  }

  static double _parseOptionalNumber(
    String raw, {
    required int rowNumber,
    required String errorKey,
  }) {
    if (raw.trim().isEmpty) return 0;
    final value = _tryParseNumber(raw);
    if (value == null) {
      throw CompanyCatalogCsvParseException(
        errorKey,
        namedArgs: {'row': '$rowNumber'},
      );
    }
    return value < 0 ? 0 : value;
  }

  static double? _tryParseNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final normalized =
        trimmed.replaceAll(RegExp(r'[^\d,.\-]'), '').replaceAll(',', '.');
    if (normalized.isEmpty || normalized == '-' || normalized == '.') {
      return null;
    }
    return double.tryParse(normalized);
  }
}

class CompanyCatalogCsvParseException implements Exception {
  const CompanyCatalogCsvParseException(this.messageKey, {this.namedArgs});

  final String messageKey;
  final Map<String, String>? namedArgs;

  @override
  String toString() => messageKey;
}

class ParsedCatalogRow {
  final String skuCode;
  final String name;
  final double price;
  final double stock;
  final String unit;

  const ParsedCatalogRow({
    required this.skuCode,
    required this.name,
    required this.price,
    required this.stock,
    this.unit = 'kom',
  });
}
