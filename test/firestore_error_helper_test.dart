import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_farmer/utils/firestore_error_helper.dart';

void main() {
  test('firestoreErrorMessage maps permission-denied', () {
    expect(
      firestoreErrorMessage(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      ),
      isNotEmpty,
    );
  });

  test('firestoreErrorMessage handles not signed in exception', () {
    expect(
      firestoreErrorIsAuthRelated(const FirestoreNotSignedInException()),
      isTrue,
    );
  });

  test('firestoreErrorCode reads FirebaseException code', () {
    expect(
      firestoreErrorCode(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        ),
      ),
      'unavailable',
    );
  });
}
