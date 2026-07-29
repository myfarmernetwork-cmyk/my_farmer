import 'package:cloud_firestore/cloud_firestore.dart';

class Follower {
  final String buyerId;
  final String farmerId;
  final String farmerName;
  final Timestamp? createdAt;

  const Follower({
    required this.buyerId,
    required this.farmerId,
    required this.farmerName,
    this.createdAt,
  });

  static String documentId(String buyerId, String farmerId) =>
      '${buyerId}_$farmerId';

  factory Follower.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Follower(
      buyerId: data['buyerId'] as String? ?? '',
      farmerId: data['farmerId'] as String? ?? '',
      farmerName: data['farmerName'] as String? ?? 'Farmer',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
