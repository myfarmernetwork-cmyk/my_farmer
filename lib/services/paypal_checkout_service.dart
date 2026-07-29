import 'package:cloud_functions/cloud_functions.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';



import '../config/payment_config.dart';

import '../models/payment_result.dart';

import 'stripe_checkout_service.dart';



class PayPalCheckoutService {

  Future<PaymentResult> processPayPalPayment({

    required BuildContext context,

    required double amount,

    required String currency,

    String? sellerId,

  }) async {

    if (PaymentConfig.isPayPalSimulated) {
      return _processSimulatedPayPalPayment(context, amount);
    }



    final approval = await _createPayPalOrder(

      amount: amount,

      currency: currency,

      sellerId: sellerId,

    );



    final approvalUrl = approval['approvalUrl']?.toString();

    final orderId = approval['orderId']?.toString();



    if (approvalUrl == null || approvalUrl.isEmpty) {

      throw Exception('PayPal approval URL missing');

    }



    final launched = await launchUrl(

      Uri.parse(approvalUrl),

      mode: LaunchMode.externalApplication,

    );

    if (!launched) {

      throw Exception('Could not open PayPal');

    }



    if (!context.mounted) {

      throw PaymentCancelledException();

    }



    final confirmed = await _confirmPayPalInApp(context);

    if (!confirmed) {

      throw PaymentCancelledException();

    }



    final capture = await _capturePayPalOrder(orderId);

    final transactionId =

        capture['transactionId']?.toString() ?? orderId ?? 'paypal_unknown';



    return PaymentResult(

      paymentMethod: 'paypal',

      paymentStatus: PaymentStatus.paid,

      transactionId: transactionId,

    );

  }



  Future<PaymentResult> _processSimulatedPayPalPayment(
    BuildContext context,
    double amount,
  ) async {
    final email = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SimulatedPayPalEmailDialog(amount: amount),
    );

    if (email == null || email.isEmpty) {
      throw PaymentCancelledException();
    }

    return PaymentResult(
      paymentMethod: 'paypal',
      paymentStatus: PaymentStatus.paid,
      transactionId:
          'paypal_sim_${DateTime.now().millisecondsSinceEpoch}_${amount.toStringAsFixed(2)}',
    );
  }



  Future<Map<String, dynamic>> _createPayPalOrder({

    required double amount,

    required String currency,

    String? sellerId,

  }) async {

    final callable =

        FirebaseFunctions.instance.httpsCallable('createPayPalOrder');

    final response = await callable.call<Map<String, dynamic>>({

      'amount': amount,

      'currency': currency.toUpperCase(),

      if (sellerId != null) 'sellerId': sellerId,

    });

    return Map<String, dynamic>.from(response.data);

  }



  Future<bool> _confirmPayPalInApp(BuildContext context) async {

    final sandboxHint = kDebugMode

        ? '\n\nSandbox: prijavite se test računom s developer.paypal.com (Sandbox → Accounts), ne stvarnim PayPal emailom.'

        : '';



    final result = await showDialog<bool>(

      context: context,

      barrierDismissible: false,

      builder: (ctx) => AlertDialog(

        title: Text('payment_paypal_confirm_title'.tr()),

        content: Text('${'payment_paypal_confirm_body'.tr()}$sandboxHint'),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: Text('cart_cancel'.tr()),

          ),

          ElevatedButton(

            onPressed: () => Navigator.pop(ctx, true),

            style: ElevatedButton.styleFrom(

              backgroundColor: const Color(0xFF003087),

              foregroundColor: Colors.white,

            ),

            child: Text('payment_paypal_confirm_done'.tr()),

          ),

        ],

      ),

    );

    return result == true;

  }



  Future<Map<String, dynamic>> _capturePayPalOrder(String? orderId) async {

    if (orderId == null || orderId.isEmpty) {

      throw Exception('Missing PayPal order id');

    }



    try {

      final callable =

          FirebaseFunctions.instance.httpsCallable('capturePayPalOrder');

      final response = await callable.call<Map<String, dynamic>>({

        'orderId': orderId,

      });

      return Map<String, dynamic>.from(response.data);

    } on FirebaseFunctionsException catch (e) {

      final detail = e.message?.trim();

      if (detail != null && detail.isNotEmpty) {

        throw Exception(detail);

      }

      rethrow;

    }

  }

}

class _SimulatedPayPalEmailDialog extends StatefulWidget {
  const _SimulatedPayPalEmailDialog({required this.amount});

  final double amount;

  @override
  State<_SimulatedPayPalEmailDialog> createState() =>
      _SimulatedPayPalEmailDialogState();
}

class _SimulatedPayPalEmailDialogState
    extends State<_SimulatedPayPalEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('payment_sim_paypal_title'.tr()),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'payment_sim_card_amount'.tr(namedArgs: {
                'amount': '${widget.amount.toStringAsFixed(2)} €',
              }),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'payment_sim_paypal_email'.tr(),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!email.contains('@') || !email.contains('.')) {
                  return 'payment_sim_paypal_email_invalid'.tr();
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cart_cancel'.tr()),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, _emailController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003087),
            foregroundColor: Colors.white,
          ),
          child: Text('payment_sim_paypal_pay'.tr()),
        ),
      ],
    );
  }
}


