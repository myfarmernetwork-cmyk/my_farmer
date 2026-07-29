import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'company_catalog_csv_parser.dart';
import 'company_catalog_pdf_fonts.dart';

typedef GuideTranslator = String Function(String key);

const _csvSample = CompanyCatalogCsvParser.templateCsvSemicolon;

/// Generira PDF uputu za firme na jeziku sučelja.
class CompanyCatalogPdfGuide {
  CompanyCatalogPdfGuide._();

  static Future<Uint8List> build({
    required PdfPageFormat format,
    required GuideTranslator tr,
    required String languageCode,
  }) async {
    final fonts = await CompanyCatalogPdfFonts.load(languageCode);

    pw.TextStyle heading({double size = 18}) => fonts.style(
          font: fonts.bold,
          fontSize: size,
          color: PdfColors.green900,
        );

    pw.TextStyle body({double size = 11}) => fonts.style(
          font: fonts.regular,
          fontSize: size,
        );

    pw.Widget notNeededBullet(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '- ',
                style: body().copyWith(color: PdfColors.red800),
              ),
              pw.Expanded(child: pw.Text(text, style: body())),
            ],
          ),
        );

    pw.Widget flowDiagram(List<String> steps) => pw.Wrap(
          spacing: 4,
          runSpacing: 6,
          crossAxisAlignment: pw.WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.purple50,
                  border: pw.Border.all(color: PdfColors.purple200),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Text(
                  steps[i],
                  style: body(size: 10).copyWith(font: fonts.bold),
                ),
              ),
              if (i < steps.length - 1)
                pw.Text(' -> ', style: body().copyWith(font: fonts.bold)),
            ],
          ],
        );

    pw.Widget step(String title, String hint) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title, style: body().copyWith(font: fonts.bold)),
              pw.SizedBox(height: 2),
              pw.Text(hint, style: body(size: 10)),
            ],
          ),
        );

    final doc = pw.Document(
      title: tr('company_catalog_pdf_doc_title'),
      author: 'My Farmer',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text(tr('company_catalog_pdf_doc_title'), style: heading(size: 22)),
          pw.SizedBox(height: 6),
          pw.Text(tr('company_catalog_pdf_doc_subtitle'), style: body(size: 12)),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              tr('company_catalog_welcome_no_code'),
              style: body().copyWith(font: fonts.bold, color: PdfColors.green900),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(tr('company_catalog_how_title'), style: heading(size: 14)),
          pw.SizedBox(height: 8),
          pw.Text(tr('company_catalog_how_body'), style: body()),
          pw.SizedBox(height: 10),
          notNeededBullet(tr('company_catalog_how_not_code')),
          notNeededBullet(tr('company_catalog_how_not_api')),
          notNeededBullet(tr('company_catalog_how_not_erp_login')),
          pw.SizedBox(height: 10),
          pw.Text(tr('company_catalog_how_need_title'), style: heading(size: 13)),
          pw.SizedBox(height: 6),
          pw.Text(tr('company_catalog_how_need_body'), style: body()),
          pw.SizedBox(height: 16),
          pw.Text(tr('company_catalog_setup_title'), style: heading(size: 14)),
          pw.SizedBox(height: 8),
          step(
            tr('company_catalog_setup_step1'),
            tr('company_catalog_setup_step1_hint'),
          ),
          step(
            tr('company_catalog_setup_step2'),
            tr('company_catalog_setup_step2_hint'),
          ),
          step(
            tr('company_catalog_setup_step3'),
            tr('company_catalog_setup_step3_hint'),
          ),
          step(
            tr('company_catalog_setup_step4'),
            tr('company_catalog_setup_step4_hint'),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            tr('company_catalog_sample_csv_title'),
            style: heading(size: 14),
          ),
          pw.SizedBox(height: 6),
          pw.Text(tr('company_catalog_sample_csv_body'), style: body()),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              _csvSample,
              style: fonts.style(font: fonts.regular, fontSize: 9),
            ),
          ),
          pw.SizedBox(height: 16),
          flowDiagram([
            tr('company_catalog_how_flow_erp'),
            tr('company_catalog_how_flow_csv'),
            tr('company_catalog_how_flow_app'),
            tr('company_catalog_how_flow_shop'),
          ]),
          pw.SizedBox(height: 16),
          pw.Text(
            tr('guide_company_catalog_orders_title'),
            style: heading(size: 14),
          ),
          pw.SizedBox(height: 6),
          pw.Text(tr('guide_company_catalog_orders_body'), style: body()),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 6),
          pw.Text(tr('company_catalog_pdf_footer'), style: body(size: 9)),
        ],
      ),
    );

    return doc.save();
  }
}
