import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Dodaj ocjenu
  Future<void> addReview({
    required String sellerId,
    required double rating,
    required String comment,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Korisnik nije prijavljen");

    final reviewRef = _firestore
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .doc(user.uid); // jedan review po korisniku

    await reviewRef.set({
      'buyerId': user.uid,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Ažuriraj prosječnu ocjenu na farmer profilu
    await _updateAverageRating(sellerId);
  }

  // Dohvati sve reviews za farmera
  Stream<QuerySnapshot> getReviews(String sellerId) {
    return _firestore
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Provjeri da li je kupac već ostavio ocjenu
  Future<bool> hasReviewed(String sellerId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .doc(user.uid)
        .get();

    return doc.exists;
  }

  // Izračunaj i sačuvaj prosječnu ocjenu
  Future<void> _updateAverageRating(String sellerId) async {
    final reviews = await _firestore
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .get();

    if (reviews.docs.isEmpty) return;

    final total = reviews.docs
        .map((d) => (d.data()['rating'] as num).toDouble())
        .reduce((a, b) => a + b);

    final average = total / reviews.docs.length;

    await _firestore.collection('users').doc(sellerId).update({
      'avgRating': average,
      'reviewCount': reviews.docs.length,
    });
  }
}

final reviewRepositoryProvider = Provider((ref) => ReviewRepository());