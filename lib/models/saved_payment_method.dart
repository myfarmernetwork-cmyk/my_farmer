import 'package:cloud_firestore/cloud_firestore.dart';

enum SavedPaymentMethodType {
  paypal,
  card,
  bank,
}

extension SavedPaymentMethodTypeX on SavedPaymentMethodType {
  String get firestoreValue {
    switch (this) {
      case SavedPaymentMethodType.paypal:
        return 'paypal';
      case SavedPaymentMethodType.card:
        return 'card';
      case SavedPaymentMethodType.bank:
        return 'bank';
    }
  }

  static SavedPaymentMethodType fromFirestore(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'card':
        return SavedPaymentMethodType.card;
      case 'bank':
        return SavedPaymentMethodType.bank;
      case 'paypal':
      default:
        return SavedPaymentMethodType.paypal;
    }
  }
}

/// Spremljeni način plaćanja — nikad puni broj kartice ni CVC.
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.type,
    this.paypalEmail,
    this.cardBrand,
    this.cardLast4,
    this.cardExpiryMonth,
    this.cardExpiryYear,
    this.cardHolderName,
    this.bankName,
    this.bankIban,
    this.accountHolder,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final SavedPaymentMethodType type;
  final String? paypalEmail;
  final String? cardBrand;
  final String? cardLast4;
  final int? cardExpiryMonth;
  final int? cardExpiryYear;
  final String? cardHolderName;
  final String? bankName;
  final String? bankIban;
  final String? accountHolder;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displaySubtitle {
    switch (type) {
      case SavedPaymentMethodType.paypal:
        return paypalEmail ?? '';
      case SavedPaymentMethodType.card:
        final brand = cardBrand ?? 'Card';
        final last4 = cardLast4 ?? '????';
        final exp = cardExpiryMonth != null && cardExpiryYear != null
            ? '${cardExpiryMonth!.toString().padLeft(2, '0')}/${cardExpiryYear!.toString().padLeft(2, '0')}'
            : '';
        return exp.isEmpty ? '$brand •••• $last4' : '$brand •••• $last4 · $exp';
      case SavedPaymentMethodType.bank:
        final iban = bankIban ?? '';
        if (iban.length > 8) {
          return '${iban.substring(0, 4)} •••• ${iban.substring(iban.length - 4)}';
        }
        return iban;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.firestoreValue,
      if (paypalEmail != null) 'paypalEmail': paypalEmail,
      if (cardBrand != null) 'cardBrand': cardBrand,
      if (cardLast4 != null) 'cardLast4': cardLast4,
      if (cardExpiryMonth != null) 'cardExpiryMonth': cardExpiryMonth,
      if (cardExpiryYear != null) 'cardExpiryYear': cardExpiryYear,
      if (cardHolderName != null) 'cardHolderName': cardHolderName,
      if (bankName != null) 'bankName': bankName,
      if (bankIban != null) 'bankIban': bankIban,
      if (accountHolder != null) 'accountHolder': accountHolder,
      'isDefault': isDefault,
      'updatedAt': FieldValue.serverTimestamp(),
      if (createdAt == null) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory SavedPaymentMethod.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SavedPaymentMethod(
      id: doc.id,
      type: SavedPaymentMethodTypeX.fromFirestore(data['type']?.toString()),
      paypalEmail: data['paypalEmail']?.toString(),
      cardBrand: data['cardBrand']?.toString(),
      cardLast4: data['cardLast4']?.toString(),
      cardExpiryMonth: _asIntOrNull(data['cardExpiryMonth']),
      cardExpiryYear: _asIntOrNull(data['cardExpiryYear']),
      cardHolderName: data['cardHolderName']?.toString(),
      bankName: data['bankName']?.toString(),
      bankIban: data['bankIban']?.toString(),
      accountHolder: data['accountHolder']?.toString(),
      isDefault: data['isDefault'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static int? _asIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
