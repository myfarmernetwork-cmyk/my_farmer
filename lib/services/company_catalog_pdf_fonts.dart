import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF fontovi po jeziku sučelja — Noto Sans pokriva latinicu, ćirilicu, CJK, arapski, devanagari…
class CompanyCatalogPdfFonts {
  CompanyCatalogPdfFonts._({
    required this.regular,
    required this.bold,
    required this.fallbacks,
  });

  final pw.Font regular;
  final pw.Font bold;
  final List<pw.Font> fallbacks;

  static Future<CompanyCatalogPdfFonts> load(String languageCode) async {
    final latinRegular = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();

    switch (languageCode.toLowerCase().split('-').first) {
      case 'zh':
        return CompanyCatalogPdfFonts._(
          regular: await PdfGoogleFonts.notoSansSCRegular(),
          bold: await PdfGoogleFonts.notoSansSCBold(),
          fallbacks: [latinRegular],
        );
      case 'ja':
        return CompanyCatalogPdfFonts._(
          regular: await PdfGoogleFonts.notoSansJPRegular(),
          bold: await PdfGoogleFonts.notoSansJPBold(),
          fallbacks: [latinRegular],
        );
      case 'ko':
        return CompanyCatalogPdfFonts._(
          regular: await PdfGoogleFonts.notoSansKRRegular(),
          bold: await PdfGoogleFonts.notoSansKRBold(),
          fallbacks: [latinRegular],
        );
      case 'ar':
        return CompanyCatalogPdfFonts._(
          regular: await PdfGoogleFonts.notoSansArabicRegular(),
          bold: await PdfGoogleFonts.notoSansArabicBold(),
          fallbacks: [latinRegular],
        );
      case 'hi':
        return CompanyCatalogPdfFonts._(
          regular: await PdfGoogleFonts.notoSansDevanagariRegular(),
          bold: await PdfGoogleFonts.notoSansDevanagariBold(),
          fallbacks: [latinRegular],
        );
      case 'th':
        return CompanyCatalogPdfFonts._(
          regular: await PdfGoogleFonts.notoSansThaiRegular(),
          bold: await PdfGoogleFonts.notoSansThaiBold(),
          fallbacks: [latinRegular],
        );
      default:
        return CompanyCatalogPdfFonts._(
          regular: latinRegular,
          bold: latinBold,
          fallbacks: const [],
        );
    }
  }

  pw.TextStyle style({
    required pw.Font font,
    double fontSize = 11,
    double height = 1.45,
    PdfColor? color,
  }) =>
      pw.TextStyle(
        font: font,
        fontFallback: fallbacks,
        fontSize: fontSize,
        height: height,
        color: color ?? PdfColors.grey800,
      );
}
