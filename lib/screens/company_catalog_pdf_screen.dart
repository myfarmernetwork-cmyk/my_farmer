import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/company_catalog_pdf_guide.dart';

/// Pregled i dijeljenje PDF upute za firme.
class CompanyCatalogPdfScreen extends StatelessWidget {
  const CompanyCatalogPdfScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CompanyCatalogPdfScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('company_catalog_pdf_screen_title'.tr(context: context)),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        maxPageWidth: 700,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'my_farmer_company_catalog_guide.pdf',
        build: (format) => CompanyCatalogPdfGuide.build(
          format: format,
          tr: (key) => key.tr(context: context),
          languageCode: context.locale.languageCode,
        ),
      ),
    );
  }
}
