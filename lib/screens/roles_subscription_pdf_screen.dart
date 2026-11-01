import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

/// Pregled i dijeljenje PDF-a s ulogama i pretplatama.
class RolesSubscriptionPdfScreen extends StatelessWidget {
  const RolesSubscriptionPdfScreen({super.key});

  static const _assetPath = 'assets/docs/My_Farmer_Uloge_i_Pretplate.pdf';

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const RolesSubscriptionPdfScreen(),
      ),
    );
  }

  static Future<Uint8List> _loadBundledPdf() async {
    final data = await rootBundle.load(_assetPath);
    return data.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('roles_pdf_screen_title'.tr()),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        maxPageWidth: 720,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'my_farmer_uloge_i_pretplate.pdf',
        build: (_) => _loadBundledPdf(),
      ),
    );
  }
}
