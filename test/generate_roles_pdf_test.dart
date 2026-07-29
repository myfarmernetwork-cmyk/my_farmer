import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/services/roles_subscription_pdf_guide.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate roles subscription PDF to docs/', () async {
    final bytes = await RolesSubscriptionPdfGuide.build(
      format: PdfPageFormat.a4,
      languageCode: 'hr',
    );

    final docsDir = Directory('docs');
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }

    final out = File('docs/My_Farmer_Uloge_i_Pretplate.pdf');
    await out.writeAsBytes(bytes);
    expect(out.lengthSync(), greaterThan(1000));
  });
}
