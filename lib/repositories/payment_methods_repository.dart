import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saved_payment_method.dart';
import '../providers/auth_provider.dart';

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>(
  (ref) => PaymentMethodsRepository(),
);

final userPaymentMethodsProvider =
    StreamProvider.autoDispose<List<SavedPaymentMethod>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(paymentMethodsRepositoryProvider);
  return repo.watchMethods(uid);
});

class PaymentMethodsRepository {
  PaymentMethodsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _firestore.collection('users').doc(userId).collection('payment_methods');

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection('users').doc(userId);

  Stream<List<SavedPaymentMethod>> watchMethods(String userId) {
    var migrationAttempted = false;
    return _col(userId).snapshots().map((snap) {
      final methods = snap.docs.map(SavedPaymentMethod.fromDoc).toList()
        ..sort((a, b) {
          if (a.isDefault != b.isDefault) {
            return a.isDefault ? -1 : 1;
          }
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      if (!migrationAttempted && methods.isEmpty) {
        migrationAttempted = true;
        _migrateLegacyPaypal(userId);
      }
      return methods;
    });
  }

  Future<void> _migrateLegacyPaypal(String userId) async {
    final userSnap = await _userDoc(userId).get();
    final legacy = userSnap.data()?['paypalEmail']?.toString().trim() ?? '';
    if (legacy.isEmpty || !legacy.contains('@')) return;

    final existing = await _col(userId)
        .where('type', isEqualTo: 'paypal')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return;

    await _col(userId).add({
      'type': 'paypal',
      'paypalEmail': legacy,
      'isDefault': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _syncLegacyPaypalField(String userId) async {
    final snap = await _col(userId).get();
    final methods = snap.docs.map(SavedPaymentMethod.fromDoc).toList();
    String? defaultPaypal;
    for (final m in methods) {
      if (m.type == SavedPaymentMethodType.paypal && m.isDefault) {
        defaultPaypal = m.paypalEmail;
        break;
      }
    }
    defaultPaypal ??= () {
      for (final m in methods) {
        if (m.type == SavedPaymentMethodType.paypal &&
            (m.paypalEmail?.isNotEmpty ?? false)) {
          return m.paypalEmail;
        }
      }
      return null;
    }();

    await _userDoc(userId).set(
      {'paypalEmail': defaultPaypal ?? ''},
      SetOptions(merge: true),
    );
  }

  Future<SavedPaymentMethod> addMethod({
    required String userId,
    required SavedPaymentMethodType type,
    String? paypalEmail,
    String? cardBrand,
    String? cardLast4,
    int? cardExpiryMonth,
    int? cardExpiryYear,
    String? cardHolderName,
    String? bankName,
    String? bankIban,
    String? accountHolder,
    bool setAsDefault = false,
  }) async {
    final snap = await _col(userId).get();
    final hasAny = snap.docs.isNotEmpty;
    final makeDefault = setAsDefault || !hasAny;

    if (makeDefault) {
      await _clearDefaultFlags(userId);
    }

    final doc = await _col(userId).add({
      'type': type.firestoreValue,
      if (paypalEmail != null) 'paypalEmail': paypalEmail.trim(),
      if (cardBrand != null) 'cardBrand': cardBrand,
      if (cardLast4 != null) 'cardLast4': cardLast4,
      if (cardExpiryMonth != null) 'cardExpiryMonth': cardExpiryMonth,
      if (cardExpiryYear != null) 'cardExpiryYear': cardExpiryYear,
      if (cardHolderName != null) 'cardHolderName': cardHolderName.trim(),
      if (bankName != null) 'bankName': bankName.trim(),
      if (bankIban != null) 'bankIban': bankIban.replaceAll(' ', '').toUpperCase(),
      if (accountHolder != null) 'accountHolder': accountHolder.trim(),
      'isDefault': makeDefault,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _syncLegacyPaypalField(userId);
    final created = await doc.get();
    return SavedPaymentMethod.fromDoc(created);
  }

  Future<void> updateMethod({
    required String userId,
    required SavedPaymentMethod method,
    String? paypalEmail,
    String? cardBrand,
    String? cardLast4,
    int? cardExpiryMonth,
    int? cardExpiryYear,
    String? cardHolderName,
    String? bankName,
    String? bankIban,
    String? accountHolder,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (paypalEmail != null) updates['paypalEmail'] = paypalEmail.trim();
    if (cardBrand != null) updates['cardBrand'] = cardBrand;
    if (cardLast4 != null) updates['cardLast4'] = cardLast4;
    if (cardExpiryMonth != null) updates['cardExpiryMonth'] = cardExpiryMonth;
    if (cardExpiryYear != null) updates['cardExpiryYear'] = cardExpiryYear;
    if (cardHolderName != null) {
      updates['cardHolderName'] = cardHolderName.trim();
    }
    if (bankName != null) updates['bankName'] = bankName.trim();
    if (bankIban != null) {
      updates['bankIban'] = bankIban.replaceAll(' ', '').toUpperCase();
    }
    if (accountHolder != null) {
      updates['accountHolder'] = accountHolder.trim();
    }

    await _col(userId).doc(method.id).update(updates);
    await _syncLegacyPaypalField(userId);
  }

  Future<void> setDefault({
    required String userId,
    required String methodId,
  }) async {
    await _clearDefaultFlags(userId);
    await _col(userId).doc(methodId).update({
      'isDefault': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _syncLegacyPaypalField(userId);
  }

  Future<void> deleteMethod({
    required String userId,
    required String methodId,
  }) async {
    final snap = await _col(userId).doc(methodId).get();
    final wasDefault = snap.data()?['isDefault'] as bool? ?? false;

    await _col(userId).doc(methodId).delete();

    if (wasDefault) {
      final remaining = await _col(userId).limit(1).get();
      if (remaining.docs.isNotEmpty) {
        await remaining.docs.first.reference.update({
          'isDefault': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await _syncLegacyPaypalField(userId);
  }

  Future<void> _clearDefaultFlags(String userId) async {
    final snap = await _col(userId).where('isDefault', isEqualTo: true).get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }
    if (snap.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<String?> defaultPaypalEmail(String userId) async {
    final snap = await _col(userId)
        .where('type', isEqualTo: 'paypal')
        .where('isDefault', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.data()['paypalEmail']?.toString();
    }
    final user = await _userDoc(userId).get();
    return user.data()?['paypalEmail']?.toString();
  }
}
