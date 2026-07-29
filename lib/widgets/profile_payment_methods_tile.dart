import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/payment_methods_screen.dart';
import '../models/saved_payment_method.dart';
import '../repositories/payment_methods_repository.dart';
import '../utils/payment_methods_error_helper.dart';

/// Kartica na profilu — ulaz u upravljanje načinima plaćanja.
class ProfilePaymentMethodsTile extends ConsumerWidget {
  const ProfilePaymentMethodsTile({super.key, this.guideKey});

  final Key? guideKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(userPaymentMethodsProvider);

    return KeyedSubtree(
      key: guideKey,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.green.shade200),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.green.shade50,
            child: Icon(Icons.payments_outlined, color: Colors.green.shade800),
          ),
          title: Text(
            'profile_payment_methods_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: methodsAsync.when(
            loading: () => Text('profile_payment_methods_loading'.tr()),
            error: (e, _) => Text(
              paymentMethodsErrorMessage(e),
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
            data: (methods) => Text(_summary(methods)),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentMethodsScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  String _summary(List<SavedPaymentMethod> methods) {
    if (methods.isEmpty) {
      return 'profile_payment_methods_summary_empty'.tr();
    }
    final parts = <String>[];
    final paypal = methods.where((m) => m.type == SavedPaymentMethodType.paypal).length;
    final cards = methods.where((m) => m.type == SavedPaymentMethodType.card).length;
    final banks = methods.where((m) => m.type == SavedPaymentMethodType.bank).length;
    if (paypal > 0) {
      parts.add('profile_payment_methods_count_paypal'.tr(namedArgs: {'count': '$paypal'}));
    }
    if (cards > 0) {
      parts.add('profile_payment_methods_count_card'.tr(namedArgs: {'count': '$cards'}));
    }
    if (banks > 0) {
      parts.add('profile_payment_methods_count_bank'.tr(namedArgs: {'count': '$banks'}));
    }
    return parts.join(' · ');
  }
}
