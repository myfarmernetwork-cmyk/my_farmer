import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../features/legal/marketplace_terms_screen.dart';
import '../models/payment_method.dart';
import '../models/payment_result.dart';
import '../models/saved_payment_method.dart';
import '../repositories/payment_methods_repository.dart';
import '../repositories/product_repository.dart';

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
    PaymentMethodsRepository? paymentMethodsRepository,
    ProductRepository? productRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _productRepository = productRepository ?? ProductRepository();

  final FirebaseFirestore _firestore;
  final ProductRepository _productRepository;

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
      ),
    );

    if (accepted != true) return null;

    return PaymentResult(
      paymentMethod: method.firestoreValue,
      paymentStatus: PaymentStatus.pending,
    );
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
  });

  final CartPaymentMethod method;
  final SellerPeerPaymentDetails seller;
  final String amountLabel;

  @override
  State<_PeerPaymentDialog> createState() => _PeerPaymentDialogState();
}

class _PeerPaymentDialogState extends State<_PeerPaymentDialog> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
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
            Text(
              'peer_payment_amount'.tr(namedArgs: {'amount': widget.amountLabel}),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._instructionWidgets(),
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

  String get _title {
    switch (widget.method) {
      case CartPaymentMethod.directPaypal:
        return 'peer_payment_paypal_title'.tr();
      case CartPaymentMethod.bankTransfer:
        return 'peer_payment_bank_title'.tr();
      case CartPaymentMethod.cash:
        return 'peer_payment_cash_title'.tr();
      default:
        return 'product_select_payment'.tr();
    }
  }

  List<Widget> _instructionWidgets() {
    switch (widget.method) {
      case CartPaymentMethod.directPaypal:
        return [
          Text('peer_payment_paypal_instruction'.tr()),
          const SizedBox(height: 8),
          SelectableText(
            widget.seller.paypalEmail ?? '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
              fontSize: 16,
            ),
          ),
        ];
      case CartPaymentMethod.bankTransfer:
        return [
          if (widget.seller.bankName?.isNotEmpty ?? false)
            Text('${'profile_payment_methods_bank_name'.tr()}: ${widget.seller.bankName}'),
          if (widget.seller.accountHolder?.isNotEmpty ?? false)
            Text('${'profile_payment_methods_account_holder'.tr()}: ${widget.seller.accountHolder}'),
          const SizedBox(height: 8),
          Text('peer_payment_bank_instruction'.tr()),
          const SizedBox(height: 8),
          SelectableText(
            widget.seller.bankIban ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 1.2,
            ),
          ),
        ];
      case CartPaymentMethod.cash:
        return [
          Text('peer_payment_cash_instruction'.tr()),
        ];
      default:
        return [];
    }
  }
}
