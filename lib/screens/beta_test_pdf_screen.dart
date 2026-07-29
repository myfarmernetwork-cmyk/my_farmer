import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

/// PDF vodič za beta testere (Closed testing).
class BetaTestPdfScreen extends StatelessWidget {
  const BetaTestPdfScreen({super.key});

  static const _assetPath = 'assets/docs/My_Farmer_Beta_Test_Upute.pdf';

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BetaTestPdfScreen()),
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
        title: Text('beta_guide_screen_title'.tr()),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        maxPageWidth: 720,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: 'my_farmer_beta_test_upute.pdf',
        build: (_) => _loadBundledPdf(),
      ),
    );
  }
}

class BetaTestGuideProfileTile extends StatelessWidget {
  const BetaTestGuideProfileTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade50,
          child: Icon(Icons.science_outlined, color: Colors.orange.shade800),
        ),
        title: Text(
          'beta_guide_profile_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('beta_guide_profile_subtitle'.tr()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => BetaTestPdfScreen.open(context),
      ),
    );
  }
}
