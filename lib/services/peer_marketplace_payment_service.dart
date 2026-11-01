import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../features/legal/marketplace_terms_screen.dart';
import '../models/payment_method.dart';
import '../models/payment_result.dart';
import '../models/saved_payment_method.dart';
import '../repositories/product_repository.dart';
import 'peer_payment_launcher.dart';
import 'sepa_epc_qr.dart';

class SellerPeerPaymentDetails {
  const SellerPeerPaymentDetails({
    this.paypalEmail,
    this.bankIban,
    this.bankName,
    this.accountHolder,
  });

  final String? paypalEmail;
  final String? bankIban;
  final String? bankName;
  final String? accountHolder;

  bool get hasPaypal =>
      paypalEmail != null && paypalEmail!.contains('@');

  bool get hasBank =>
      bankIban != null && bankIban!.replaceAll(' ', '').length >= 8;
}

class PeerMarketplacePaymentService {
  PeerMarketplacePaymentService({
    FirebaseFirestore? firestore,
    ProductRepository? productRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _productRepository = productRepository ?? ProductRepository();

  final FirebaseFirestore _firestore;
  final ProductRepository _productRepository;

  static String newPaymentReference() =>
      'MF-${DateTime.now().millisecondsSinceEpoch}';

  Future<SellerPeerPaymentDetails> loadSellerDetails(String sellerId) async {
    final snap = await _firestore
        .collection('users')
        .doc(sellerId)
        .collection('payment_methods')
        .get();

    String? paypal;
    String? iban;
    String? bankName;
    String? holder;

    for (final doc in snap.docs) {
      final method = SavedPaymentMethod.fromDoc(doc);
      if (method.type == SavedPaymentMethodType.paypal &&
          (paypal == null || method.isDefault)) {
        paypal = method.paypalEmail;
      }
      if (method.type == SavedPaymentMethodType.bank &&
          (iban == null || method.isDefault)) {
        iban = method.bankIban;
        bankName = method.bankName;
        holder = method.accountHolder;
      }
    }

    if (paypal == null || paypal.isEmpty) {
      paypal = await _productRepository.getSellerPaypalEmail(sellerId);
    }

    return SellerPeerPaymentDetails(
      paypalEmail: paypal?.trim(),
      bankIban: iban?.trim(),
      bankName: bankName?.trim(),
      accountHolder: holder?.trim(),
    );
  }

  Future<PaymentResult?> confirmPeerPayment({
    required BuildContext context,
    required CartPaymentMethod method,
    required SellerPeerPaymentDetails seller,
    required String amountLabel,
    required double amountEur,
    required String paymentReference,
    String currencyCode = 'EUR',
  }) async {
    if (method == CartPaymentMethod.directPaypal && !seller.hasPaypal) {
      await _showMissingSellerSetup(context, 'paypal');
      return null;
    }
    if (method == CartPaymentMethod.bankTransfer && !seller.hasBank) {
      await _showMissingSellerSetup(context, 'bank');
      return null;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PeerPaymentDialog(
        method: method,
        seller: seller,
        amountLabel: amountLabel,
        amountEur: amountEur,
        paymentReference: paymentReference,
        currencyCode: currencyCode,
      ),
    );

    if (accepted != true) return null;

    return PaymentResult(
      paymentMethod: method.firestoreValue,
      paymentStatus: PaymentStatus.pending,
      transactionId: paymentReference,
    );
  }

  Future<void> showAfterOrderInstructions({
    required BuildContext context,
    required CartPaymentMethod method,
    required SellerPeerPaymentDetails seller,
    required String amountLabel,
    required double amountEur,
    String? paymentReference,
    String currencyCode = 'EUR',
  }) async {
    if (method != CartPaymentMethod.directPaypal &&
        method != CartPaymentMethod.bankTransfer) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_dialogTitle(method)),
        content: SingleChildScrollView(
          child: _PeerPaymentInstructionsBody(
            method: method,
            seller: seller,
            amountLabel: amountLabel,
            amountEur: amountEur,
            paymentReference: paymentReference ?? '',
            currencyCode: currencyCode,
            compact: false,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  static String _dialogTitle(CartPaymentMethod method) {
    switch (method) {
      case CartPaymentMethod.directPaypal:
        return 'peer_payment_paypal_title'.tr();
      case CartPaymentMethod.bankTransfer:
        return 'peer_payment_bank_title'.tr();
      default:
        return 'product_select_payment'.tr();
    }
  }

  Future<void> _showMissingSellerSetup(
    BuildContext context,
    String type,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('peer_payment_seller_missing_title'.tr()),
        content: Text(
          type == 'paypal'
              ? 'peer_payment_seller_missing_paypal'.tr()
              : 'peer_payment_seller_missing_bank'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }
}

class _PeerPaymentDialog extends StatefulWidget {
  const _PeerPaymentDialog({
    required this.method,
    required this.seller,
    required this.amountLabel,
    required this.amountEur,
    required this.paymentReference,
    required this.currencyCode,
  });

  final CartPaymentMethod method;
  final SellerPeerPaymentDetails seller;
  final String amountLabel;
  final double amountEur;
  final String paymentReference;
  final String currencyCode;

  @override
  State<_PeerPaymentDialog> createState() => _PeerPaymentDialogState();
}

class _PeerPaymentDialogState extends State<_PeerPaymentDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(PeerMarketplacePaymentService._dialogTitle(widget.method)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                'peer_payment_disclaimer'.tr(),
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PeerPaymentInstructionsBody(
              method: widget.method,
              seller: widget.seller,
              amountLabel: widget.amountLabel,
              amountEur: widget.amountEur,
              paymentReference: widget.paymentReference,
              currencyCode: widget.currencyCode,
              compact: true,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              title: Text(
                'peer_payment_accept_checkbox'.tr(),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openMarketplaceTerms(context),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text('legal_terms_read_link'.tr()),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cart_cancel'.tr()),
        ),
        FilledButton(
          onPressed: _accepted ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
          child: Text('peer_payment_confirm_order'.tr()),
        ),
      ],
    );
  }
}

class _PeerPaymentInstructionsBody extends StatelessWidget {
  const _PeerPaymentInstructionsBody({
    required this.method,
    required this.seller,
    required this.amountLabel,
    required this.amountEur,
    required this.paymentReference,
    required this.currencyCode,
    this.compact = false,
  });

  final CartPaymentMethod method;
  final SellerPeerPaymentDetails seller;
  final String amountLabel;
  final double amountEur;
  final String paymentReference;
  final String currencyCode;
  final bool compact;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'peer_payment_copied'.tr(namedArgs: {'label': label}),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'peer_payment_amount'.tr(namedArgs: {'amount': amountLabel}),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (paymentReference.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'peer_payment_reference_label'.tr(
              namedArgs: {'ref': paymentReference},
            ),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
        ],
        const SizedBox(height: 12),
        ...switch (method) {
          CartPaymentMethod.directPaypal => _paypalWidgets(context),
          CartPaymentMethod.bankTransfer => _bankWidgets(context),
          CartPaymentMethod.cash => [
              Text('peer_payment_cash_instruction'.tr()),
            ],
          _ => <Widget>[],
        },
      ],
    );
  }

  List<Widget> _paypalWidgets(BuildContext context) {
    final email = seller.paypalEmail ?? '';
    return [
      Text('peer_payment_paypal_instruction'.tr()),
      const SizedBox(height: 8),
      SelectableText(
        email,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: email.isEmpty
                ? null
                : () => _copy(context, 'PayPal', email),
            icon: const Icon(Icons.copy, size: 18),
            label: Text('peer_payment_copy_paypal'.tr()),
          ),
          FilledButton.icon(
            onPressed: email.isEmpty
                ? null
                : () async {
                    final ok = await PeerPaymentLauncher.openPayPalToSeller(
                      sellerEmail: email,
                      amount: amountEur,
                      currency: currencyCode,
                    );
                    if (!context.mounted) return;
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('peer_payment_open_failed'.tr())),
                      );
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
            ),
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
            label: Text(
              'peer_payment_open_paypal'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      if (!compact) ...[
        const SizedBox(height: 8),
        Text(
          'peer_payment_paypal_after_order_hint'.tr(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    ];
  }

  List<Widget> _bankWidgets(BuildContext context) {
    final iban = seller.bankIban ?? '';
    final holder = seller.accountHolder?.trim() ?? '';
    final name = holder.isNotEmpty ? holder : (seller.bankName ?? 'My Farmer');
    final qrPayload = iban.isNotEmpty && amountEur > 0
        ? SepaEpcQr.build(
            beneficiaryName: name,
            iban: iban,
            amountEur: amountEur,
            remittance: paymentReference.isNotEmpty
                ? paymentReference
                : 'My Farmer',
          )
        : '';

    return [
      if (seller.bankName?.isNotEmpty ?? false)
        Text('${'profile_payment_methods_bank_name'.tr()}: ${seller.bankName}'),
      if (holder.isNotEmpty)
        Text('${'profile_payment_methods_account_holder'.tr()}: $holder'),
      const SizedBox(height: 8),
      Text('peer_payment_bank_instruction'.tr()),
      const SizedBox(height: 8),
      SelectableText(
        iban,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed:
                iban.isEmpty ? null : () => _copy(context, 'IBAN', iban),
            icon: const Icon(Icons.copy, size: 18),
            label: Text('peer_payment_copy_iban'.tr()),
          ),
          OutlinedButton.icon(
            onPressed: amountEur <= 0
                ? null
                : () => _copy(
                      context,
                      'peer_payment_copy_amount'.tr(),
                      amountEur.toStringAsFixed(2),
                    ),
            icon: const Icon(Icons.copy, size: 18),
            label: Text('peer_payment_copy_amount'.tr()),
          ),
          if (paymentReference.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _copy(
                context,
                'peer_payment_reference_label'.tr(namedArgs: {'ref': ''}),
                paymentReference,
              ),
              icon: const Icon(Icons.copy, size: 18),
              label: Text('peer_payment_copy_reference'.tr()),
            ),
        ],
      ),
      if (qrPayload.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'peer_payment_qr_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'peer_payment_qr_hint_one_phone'.tr(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ),
      ],
    ];
  }
}
