import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/payment_config.dart';
import '../models/payment_method.dart';import '../models/payment_result.dart';
import '../widgets/simulated_card_entry_sheet.dart';

class PaymentCancelledException implements Exception {
  @override
  String toString() => 'Payment cancelled';
}

class StripeCheckoutService {
  Future<PaymentResult> processCardOrWalletPayment({
    required BuildContext context,
    required CartPaymentMethod method,
    required double amount,
    required String currency,
    String? sellerId,
  }) async {
    final amountCents = (amount * 100).round();
    if (amountCents <= 0) {
      throw Exception('Invalid payment amount');
    }

    if (PaymentConfig.isStripeSimulated) {
      return _processSimulatedStripePayment(context, method, amountCents);
    }

    final clientSecret = await _createPaymentIntent(
      amountCents: amountCents,
      currency: currency.toLowerCase(),
      sellerId: sellerId,
    );

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: PaymentConfig.merchantDisplayName,
        style: ThemeMode.system,
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: PaymentConfig.merchantCountryCode,
          currencyCode: currency.toUpperCase(),
          testEnv: kDebugMode,
        ),
        applePay: const PaymentSheetApplePay(
          merchantCountryCode: PaymentConfig.merchantCountryCode,
        ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    final paymentIntentId = _extractPaymentIntentId(clientSecret);

    return PaymentResult(
      paymentMethod: method.firestoreValue,
      paymentStatus: PaymentStatus.paid,
      transactionId: paymentIntentId,
    );
  }

  Future<PaymentResult> _processSimulatedStripePayment(
    BuildContext context,
    CartPaymentMethod method,
    int amountCents,
  ) async {
    if (method == CartPaymentMethod.googlePay) {
      return _processSimulatedGooglePayPayment(context, amountCents);
    }

    final amount = amountCents / 100;
    final cardResult = await showSimulatedCardEntrySheet(
      context: context,
      amount: amount,
      currencySymbol: PaymentConfig.defaultCurrency == 'EUR' ? '€' : PaymentConfig.defaultCurrency,
    );

    if (cardResult == null) {
      throw PaymentCancelledException();
    }

    return PaymentResult(
      paymentMethod: method.firestoreValue,
      paymentStatus: PaymentStatus.paid,
      transactionId:
          'stripe_sim_${DateTime.now().millisecondsSinceEpoch}_${cardResult.last4}',
    );
  }

  Future<PaymentResult> _processSimulatedGooglePayPayment(
    BuildContext context,
    int amountCents,
  ) async {
    final reason = PaymentConfig.simulationMode
        ? 'payment_simulation_reason_flag'.tr()
        : 'payment_simulation_reason_no_stripe_key'.tr();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('payment_stripe_simulation_title'.tr()),
        content: Text(
          'payment_google_pay_simulation_body'.tr(namedArgs: {'reason': reason}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: Text('payment_simulation_confirm_button'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      throw PaymentCancelledException();
    }

    return PaymentResult(
      paymentMethod: CartPaymentMethod.googlePay.firestoreValue,
      paymentStatus: PaymentStatus.paid,
      transactionId:
          'gpay_sim_${DateTime.now().millisecondsSinceEpoch}_$amountCents',
    );
  }

  Future<String> _createPaymentIntent({
    required int amountCents,
    required String currency,
    String? sellerId,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final response = await callable.call<Map<String, dynamic>>({
        'amount': amountCents,
        'currency': currency,
        if (sellerId != null) 'sellerId': sellerId,
      });
      final clientSecret = response.data['clientSecret']?.toString();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Missing Stripe client secret');
      }
      return clientSecret;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unavailable') {
        return _createSimulatedClientSecret(amountCents, currency);
      }
      rethrow;
    } catch (_) {
      return _createSimulatedClientSecret(amountCents, currency);
    }
  }

  String _createSimulatedClientSecret(int amountCents, String currency) {
    final intentId = 'pi_sim_${DateTime.now().millisecondsSinceEpoch}';
    final payload = {
      'id': intentId,
      'amount': amountCents,
      'currency': currency,
      'status': 'requires_payment_method',
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(payload)));
    return '${intentId}_secret_$encoded';
  }

  String _extractPaymentIntentId(String clientSecret) {
    final separatorIndex = clientSecret.indexOf('_secret_');
    if (separatorIndex <= 0) return clientSecret;
    return clientSecret.substring(0, separatorIndex);
  }
}
