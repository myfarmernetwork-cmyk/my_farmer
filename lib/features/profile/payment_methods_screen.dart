import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/saved_payment_method.dart';
import '../../repositories/payment_methods_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/simulated_card_entry_sheet.dart';
import '../../utils/payment_methods_error_helper.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(userPaymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('profile_payment_methods_title'.tr()),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context, ref),
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add),
        label: Text('profile_payment_methods_add'.tr()),
      ),
      body: methodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _LoadErrorState(
          message: paymentMethodsErrorMessage(e),
          showAdminHint: isPaymentMethodsPermissionError(e),
          onRetry: () => ref.invalidate(userPaymentMethodsProvider),
        ),
        data: (methods) {
          if (methods.isEmpty) {
            return _EmptyState(onAdd: () => _showAddOptions(context, ref));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: methods.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    'profile_payment_methods_peer_hint'.tr(),
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                );
              }
              final method = methods[index - 1];
              return _PaymentMethodCard(
                method: method,
                onSetDefault: () => _setDefault(ref, method),
                onEdit: () => _editMethod(context, ref, method),
                onDelete: () => _confirmDelete(context, ref, method),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _setDefault(WidgetRef ref, SavedPaymentMethod method) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null || method.isDefault) return;
    await ref.read(paymentMethodsRepositoryProvider).setDefault(
          userId: uid,
          methodId: method.id,
        );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SavedPaymentMethod method,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_payment_methods_delete_title'.tr()),
        content: Text('profile_payment_methods_delete_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cart_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('profile_payment_methods_delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(paymentMethodsRepositoryProvider).deleteMethod(
          userId: uid,
          methodId: method.id,
        );
  }

  Future<void> _showAddOptions(BuildContext context, WidgetRef ref) async {
    final type = await showModalBottomSheet<SavedPaymentMethodType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'profile_payment_methods_add'.tr(),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _AddTypeTile(
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF003087),
                title: 'order_payment_paypal'.tr(),
                subtitle: 'profile_payment_methods_add_paypal_hint'.tr(),
                onTap: () => Navigator.pop(ctx, SavedPaymentMethodType.paypal),
              ),
              const SizedBox(height: 8),
              _AddTypeTile(
                icon: Icons.credit_card,
                color: Colors.deepPurple.shade700,
                title: 'cart_payment_stripe'.tr(),
                subtitle: 'profile_payment_methods_add_card_hint'.tr(),
                onTap: () => Navigator.pop(ctx, SavedPaymentMethodType.card),
              ),
              const SizedBox(height: 8),
              _AddTypeTile(
                icon: Icons.account_balance,
                color: Colors.teal.shade700,
                title: 'profile_payment_methods_bank'.tr(),
                subtitle: 'profile_payment_methods_add_bank_hint'.tr(),
                onTap: () => Navigator.pop(ctx, SavedPaymentMethodType.bank),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    await _addMethod(context, ref, type);
  }

  Future<void> _addMethod(
    BuildContext context,
    WidgetRef ref,
    SavedPaymentMethodType type,
  ) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final repo = ref.read(paymentMethodsRepositoryProvider);

    switch (type) {
      case SavedPaymentMethodType.paypal:
        final email = await _promptPaypalEmail(context);
        if (email == null || email.isEmpty) return;
        await repo.addMethod(
          userId: uid,
          type: type,
          paypalEmail: email,
        );
        break;
      case SavedPaymentMethodType.card:
        final card = await showSimulatedCardEntrySheet(
          context: context,
          amount: 0,
          currencySymbol: '€',
          saveMode: true,
        );
        if (card == null) return;
        await repo.addMethod(
          userId: uid,
          type: type,
          cardBrand: card.cardBrand,
          cardLast4: card.last4,
          cardExpiryMonth: card.expiryMonth,
          cardExpiryYear: card.expiryYear,
          cardHolderName: card.holderName,
        );
        break;
      case SavedPaymentMethodType.bank:
        final bank = await _promptBankAccount(context);
        if (bank == null) return;
        await repo.addMethod(
          userId: uid,
          type: type,
          bankName: bank.bankName,
          bankIban: bank.iban,
          accountHolder: bank.holder,
        );
        break;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_payment_methods_saved'.tr())),
      );
    }
  }

  Future<void> _editMethod(
    BuildContext context,
    WidgetRef ref,
    SavedPaymentMethod method,
  ) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final repo = ref.read(paymentMethodsRepositoryProvider);

    switch (method.type) {
      case SavedPaymentMethodType.paypal:
        final email = await _promptPaypalEmail(
          context,
          initial: method.paypalEmail,
        );
        if (email == null || email.isEmpty) return;
        await repo.updateMethod(
          userId: uid,
          method: method,
          paypalEmail: email,
        );
        break;
      case SavedPaymentMethodType.card:
        final card = await showSimulatedCardEntrySheet(
          context: context,
          amount: 0,
          currencySymbol: '€',
          saveMode: true,
        );
        if (card == null) return;
        await repo.updateMethod(
          userId: uid,
          method: method,
          cardBrand: card.cardBrand,
          cardLast4: card.last4,
          cardExpiryMonth: card.expiryMonth,
          cardExpiryYear: card.expiryYear,
          cardHolderName: card.holderName,
        );
        break;
      case SavedPaymentMethodType.bank:
        final bank = await _promptBankAccount(
          context,
          initialBank: method.bankName,
          initialIban: method.bankIban,
          initialHolder: method.accountHolder,
        );
        if (bank == null) return;
        await repo.updateMethod(
          userId: uid,
          method: method,
          bankName: bank.bankName,
          bankIban: bank.iban,
          accountHolder: bank.holder,
        );
        break;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile_payment_methods_saved'.tr())),
      );
    }
  }

  Future<String?> _promptPaypalEmail(
    BuildContext context, {
    String? initial,
  }) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('payment_sim_paypal_title'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'payment_sim_paypal_email'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final email = controller.text.trim();
              if (!email.contains('@')) return;
              Navigator.pop(ctx, email);
            },
            child: Text('profile_save'.tr()),
          ),
        ],
      ),
    );
  }

  Future<_BankFormResult?> _promptBankAccount(
    BuildContext context, {
    String? initialBank,
    String? initialIban,
    String? initialHolder,
  }) {
    final bankController = TextEditingController(text: initialBank ?? '');
    final ibanController = TextEditingController(text: initialIban ?? '');
    final holderController = TextEditingController(text: initialHolder ?? '');

    return showDialog<_BankFormResult>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile_payment_methods_bank'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bankController,
                decoration: InputDecoration(
                  labelText: 'profile_payment_methods_bank_name'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ibanController,
                decoration: InputDecoration(
                  labelText: 'profile_payment_methods_iban'.tr(),
                  border: const OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 ]')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: holderController,
                decoration: InputDecoration(
                  labelText: 'profile_payment_methods_account_holder'.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cart_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final iban = ibanController.text.replaceAll(' ', '').trim();
              if (iban.length < 8) return;
              Navigator.pop(
                ctx,
                _BankFormResult(
                  bankName: bankController.text.trim(),
                  iban: iban,
                  holder: holderController.text.trim(),
                ),
              );
            },
            child: Text('profile_save'.tr()),
          ),
        ],
      ),
    );
  }
}

class _BankFormResult {
  const _BankFormResult({
    required this.bankName,
    required this.iban,
    required this.holder,
  });

  final String bankName;
  final String iban;
  final String holder;
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({
    required this.message,
    required this.showAdminHint,
    required this.onRetry,
  });

  final String message;
  final bool showAdminHint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.orange.shade700),
            const SizedBox(height: 16),
            Text(
              'profile_payment_methods_error_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
            ),
            if (showAdminHint) ...[
              const SizedBox(height: 12),
              Text(
                'profile_payment_methods_error_permission_hint'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
              icon: const Icon(Icons.refresh),
              label: Text('profile_payment_methods_error_retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'profile_payment_methods_empty'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'profile_payment_methods_empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('profile_payment_methods_add'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTypeTile extends StatelessWidget {
  const _AddTypeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      tileColor: color.withValues(alpha: 0.06),
      leading: Icon(icon, color: color, size: 32),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: color),
      onTap: onTap,
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedPaymentMethod method;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData get _icon {
    switch (method.type) {
      case SavedPaymentMethodType.paypal:
        return Icons.account_balance_wallet;
      case SavedPaymentMethodType.card:
        return Icons.credit_card;
      case SavedPaymentMethodType.bank:
        return Icons.account_balance;
    }
  }

  Color get _color {
    switch (method.type) {
      case SavedPaymentMethodType.paypal:
        return const Color(0xFF003087);
      case SavedPaymentMethodType.card:
        return Colors.deepPurple.shade700;
      case SavedPaymentMethodType.bank:
        return Colors.teal.shade700;
    }
  }

  String get _title {
    switch (method.type) {
      case SavedPaymentMethodType.paypal:
        return 'order_payment_paypal'.tr();
      case SavedPaymentMethodType.card:
        return 'cart_payment_stripe'.tr();
      case SavedPaymentMethodType.bank:
        return 'profile_payment_methods_bank'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _color.withValues(alpha: 0.12),
                  child: Icon(_icon, color: _color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (method.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                'profile_payment_methods_default'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method.displaySubtitle,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'default':
                        onSetDefault();
                      case 'edit':
                        onEdit();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!method.isDefault)
                      PopupMenuItem(
                        value: 'default',
                        child: Text('profile_payment_methods_set_default'.tr()),
                      ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('profile_edit'.tr()),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'profile_payment_methods_delete_confirm'.tr(),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
