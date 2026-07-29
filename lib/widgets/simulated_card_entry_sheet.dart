import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Rezultat simulacijskog unosa kartice (nema stvarne naplate).
class SimulatedCardEntryResult {
  const SimulatedCardEntryResult({
    required this.last4,
    required this.cardBrand,
    this.expiryMonth,
    this.expiryYear,
    this.holderName,
  });

  final String last4;
  final String cardBrand;
  final int? expiryMonth;
  final int? expiryYear;
  final String? holderName;
}

/// Bottom sheet za unos test kartice (checkout ili spremanje u profil).
Future<SimulatedCardEntryResult?> showSimulatedCardEntrySheet({
  required BuildContext context,
  required double amount,
  required String currencySymbol,
  bool saveMode = false,
}) {
  return showModalBottomSheet<SimulatedCardEntryResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SimulatedCardEntrySheet(
      amount: amount,
      currencySymbol: currencySymbol,
      saveMode: saveMode,
    ),
  );
}

class _SimulatedCardEntrySheet extends StatefulWidget {
  const _SimulatedCardEntrySheet({
    required this.amount,
    required this.currencySymbol,
    required this.saveMode,
  });

  final double amount;
  final String currencySymbol;
  final bool saveMode;

  @override
  State<_SimulatedCardEntrySheet> createState() =>
      _SimulatedCardEntrySheetState();
}

class _SimulatedCardEntrySheetState extends State<_SimulatedCardEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  String? _validateCardNumber(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length < 13 || digits.length > 19) {
      return 'payment_sim_card_number_invalid'.tr();
    }
    return null;
  }

  (int?, int?)? _parseExpiry() {
    final raw = _digitsOnly(_expiryController.text);
    if (raw.length != 4) return null;
    final month = int.tryParse(raw.substring(0, 2));
    final year = int.tryParse(raw.substring(2, 4));
    if (month == null || year == null) return null;
    return (month, year);
  }

  String? _validateExpiry(String? value) {
    final raw = _digitsOnly(value ?? '');
    if (raw.length != 4) {
      return 'payment_sim_card_expiry_invalid'.tr();
    }
    final month = int.tryParse(raw.substring(0, 2));
    final year = int.tryParse(raw.substring(2, 4));
    if (month == null || year == null || month < 1 || month > 12) {
      return 'payment_sim_card_expiry_invalid'.tr();
    }
    final now = DateTime.now();
    final expiry = DateTime(2000 + year, month + 1);
    if (expiry.isBefore(DateTime(now.year, now.month))) {
      return 'payment_sim_card_expiry_past'.tr();
    }
    return null;
  }

  String? _validateCvc(String? value) {
    final digits = _digitsOnly(value ?? '');
    if (digits.length < 3 || digits.length > 4) {
      return 'payment_sim_card_cvc_invalid'.tr();
    }
    return null;
  }

  String _detectBrand(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (RegExp(r'^5[1-5]').hasMatch(digits) ||
        RegExp(r'^2[2-7]').hasMatch(digits)) {
      return 'Mastercard';
    }
    if (digits.startsWith('3')) return 'Amex';
    return 'Card';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final digits = _digitsOnly(_numberController.text);
    final expiry = _parseExpiry();
    Navigator.pop(
      context,
      SimulatedCardEntryResult(
        last4: digits.substring(digits.length - 4),
        cardBrand: _detectBrand(digits),
        expiryMonth: expiry?.$1,
        expiryYear: expiry?.$2,
        holderName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
      ),
    );
  }

  void _fillTestCard() {
    _numberController.text = '4242 4242 4242 4242';
    _expiryController.text = '12/34';
    _cvcController.text = '123';
    _nameController.text = 'Test Kupac';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.saveMode
                  ? 'profile_payment_methods_save_card_title'.tr()
                  : 'payment_sim_card_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (!widget.saveMode) ...[
              const SizedBox(height: 4),
              Text(
                'payment_sim_card_amount'.tr(namedArgs: {
                  'amount':
                      '${widget.amount.toStringAsFixed(2)} ${widget.currencySymbol}',
                }),
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'profile_payment_methods_save_card_hint'.tr(),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science_outlined,
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.saveMode
                          ? 'profile_payment_methods_card_security_hint'.tr()
                          : 'payment_sim_card_hint'.tr(),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'payment_sim_card_number'.tr(),
                hintText: '4242 4242 4242 4242',
                prefixIcon: const Icon(Icons.credit_card),
                border: const OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
                _CardNumberFormatter(),
              ],
              validator: _validateCardNumber,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'payment_sim_card_expiry'.tr(),
                      hintText: 'MM/YY',
                      border: const OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryFormatter(),
                    ],
                    validator: _validateExpiry,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvcController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'payment_sim_card_cvc'.tr(),
                      hintText: '123',
                      border: const OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: _validateCvc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'payment_sim_card_name'.tr(),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _fillTestCard,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text('payment_sim_card_fill_test'.tr()),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                widget.saveMode
                    ? 'profile_save'.tr()
                    : 'payment_sim_card_pay'.tr(),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cart_cancel'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 2) {
      return TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    final text = '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
