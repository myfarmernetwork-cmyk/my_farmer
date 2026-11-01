/// EPC069-12 SEPA Credit Transfer QR payload for European banking apps.
class SepaEpcQr {
  SepaEpcQr._();

  static String build({
    required String beneficiaryName,
    required String iban,
    required double amountEur,
    String remittance = '',
    String bic = '',
  }) {
    final name = beneficiaryName.trim();
    final cleanIban = iban.replaceAll(' ', '').toUpperCase();
    final amount = amountEur.isFinite && amountEur > 0
        ? 'EUR${amountEur.toStringAsFixed(2)}'
        : '';
    final info = remittance.trim();
    final lines = <String>[
      'BCD',
      '002',
      '1',
      'SCT',
      bic.trim(),
      name.length > 70 ? name.substring(0, 70) : name,
      cleanIban,
      amount,
      '',
      info.length > 140 ? info.substring(0, 140) : info,
    ];
    return lines.join('\n');
  }
}
