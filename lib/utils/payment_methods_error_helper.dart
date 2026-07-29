import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Korisnički prijevod Firebase/Firestore grešaka za načine plaćanja.
String paymentMethodsErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'profile_payment_methods_error_permission'.tr();
      case 'unavailable':
      case 'deadline-exceeded':
        return 'profile_payment_methods_error_offline'.tr();
      case 'unauthenticated':
        return 'profile_payment_methods_error_auth'.tr();
      default:
        break;
    }
  }
  if (error is FirebaseAuthException &&
      error.code == 'user-token-expired') {
    return 'profile_payment_methods_error_auth'.tr();
  }
  final raw = error.toString().toLowerCase();
  if (raw.contains('permission-denied') || raw.contains('permission denied')) {
    return 'profile_payment_methods_error_permission'.tr();
  }
  return 'profile_payment_methods_error_load'.tr();
}

bool isPaymentMethodsPermissionError(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return true;
  }
  return error.toString().toLowerCase().contains('permission-denied');
}
