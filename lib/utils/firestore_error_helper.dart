import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown when Firestore rules require [FirebaseAuth.currentUser] but none exists.
class FirestoreNotSignedInException implements Exception {
  const FirestoreNotSignedInException();
}

User? _currentFirebaseUserOrNull() {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
}

/// User-facing message for Firestore / Firebase Auth load failures.
String firestoreErrorMessage(Object error) {
  if (error is FirestoreNotSignedInException) {
    return 'firestore_error_auth_required'.tr();
  }

  if (error is FirebaseAuthException &&
      error.code == 'user-token-expired') {
    return 'firestore_error_auth_required'.tr();
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        if (_currentFirebaseUserOrNull() == null) {
          return 'firestore_error_auth_required'.tr();
        }
        return 'firestore_error_permission_denied'.tr();
      case 'unauthenticated':
        return 'firestore_error_auth_required'.tr();
      case 'unavailable':
      case 'deadline-exceeded':
        return 'firestore_error_offline'.tr();
      default:
        final detail = (error.message ?? '').trim();
        if (detail.isEmpty) {
          return 'firestore_error_detail'.tr(
            namedArgs: {'code': error.code, 'message': error.code},
          );
        }
        return 'firestore_error_detail'.tr(
          namedArgs: {'code': error.code, 'message': detail},
        );
    }
  }

  final raw = error.toString().toLowerCase();
  if (raw.contains('permission-denied') || raw.contains('permission denied')) {
    return _currentFirebaseUserOrNull() == null
        ? 'firestore_error_auth_required'.tr()
        : 'firestore_error_permission_denied'.tr();
  }

  return 'firestore_error_load_failed'.tr();
}

String firestoreErrorTitle(Object error) {
  if (firestoreErrorIsAuthRelated(error)) {
    return 'firestore_error_auth_title'.tr();
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return 'firestore_error_offline_title'.tr();
  }
  return 'firestore_error_title'.tr();
}

bool firestoreErrorIsAuthRelated(Object error) {
  if (error is FirestoreNotSignedInException) return true;
  if (_currentFirebaseUserOrNull() == null) {
    return error is FirebaseException &&
        (error.code == 'permission-denied' ||
            error.code == 'unauthenticated');
  }
  if (error is FirebaseAuthException &&
      error.code == 'user-token-expired') {
    return true;
  }
  if (error is FirebaseException && error.code == 'unauthenticated') {
    return true;
  }
  return false;
}

String? firestoreErrorCode(Object error) {
  if (error is FirebaseException) return error.code;
  if (error is FirebaseAuthException) return error.code;
  return null;
}

void rethrowIfSignedOut() {
  if (_currentFirebaseUserOrNull() == null) {
    throw const FirestoreNotSignedInException();
  }
}
