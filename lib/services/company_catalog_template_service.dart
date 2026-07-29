import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'company_catalog_csv_parser.dart';

/// Spremanje i dijeljenje CSV predloška za katalog firme.
class CompanyCatalogTemplateService {
  CompanyCatalogTemplateService._();

  static const fileName = 'my_farmer_katalog_predlozak.csv';

  /// UTF-8 s BOM — Excel na Windowsu ispravno prikazuje š, ć, č, đ, ž.
  static List<int> get templateBytes {
    const bom = [0xEF, 0xBB, 0xBF];
    return [...bom, ...utf8.encode(CompanyCatalogCsvParser.templateCsvSemicolon)];
  }

  /// Zapisuje predložak u privremeni direktorij i otvara dijalog za spremanje/dijeljenje.
  static Future<void> downloadTemplate() async {
    if (kIsWeb) {
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(templateBytes),
            name: fileName,
            mimeType: 'text/csv',
          ),
        ],
        subject: fileName,
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(templateBytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv', name: fileName)],
      subject: fileName,
    );
  }
}
