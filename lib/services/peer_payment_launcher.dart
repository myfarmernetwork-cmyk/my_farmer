import 'package:url_launcher/url_launcher.dart';

/// Opens PayPal (app or browser) with seller email and amount pre-filled where supported.
class PeerPaymentLauncher {
  PeerPaymentLauncher._();

  static Future<bool> openPayPalToSeller({
    required String sellerEmail,
    required double amount,
    String currency = 'EUR',
    String? itemLabel,
  }) async {
    final email = sellerEmail.trim();
    if (!email.contains('@')) return false;

    final amt = amount.toStringAsFixed(2);
    final code = currency.toUpperCase();
    final name = itemLabel?.trim().isNotEmpty == true
        ? itemLabel!.trim()
        : 'My Farmer';

    final uri = Uri.parse(
      'https://www.paypal.com/cgi-bin/webscr?cmd=_xclick'
      '&business=${Uri.encodeComponent(email)}'
      '&amount=$amt'
      '&currency_code=$code'
      '&item_name=${Uri.encodeComponent(name)}',
    );

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
