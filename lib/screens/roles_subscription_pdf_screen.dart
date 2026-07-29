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

/// Pločica u profilu za otvaranje PDF vodiča ulogama.
class RolesSubscriptionPdfProfileTile extends StatelessWidget {
  const RolesSubscriptionPdfProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.menu_book_outlined, color: Colors.green.shade800),
        ),
        title: Text(
          'roles_pdf_profile_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('roles_pdf_profile_subtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => RolesSubscriptionPdfScreen.open(context),
      ),
    );
  }
}
