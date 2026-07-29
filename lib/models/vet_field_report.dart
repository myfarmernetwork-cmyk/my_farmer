import 'package:cloud_firestore/cloud_firestore.dart';

class VetFieldReport {
  const VetFieldReport({
    required this.id,
    required this.vetId,
    required this.vetName,
    required this.title,
    required this.farmerId,
    required this.farmerName,
    required this.notes,
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String vetId;
  final String vetName;
  final String title;
  final String farmerId;
  final String farmerName;
  final String notes;
  final String? photoUrl;
  final DateTime? createdAt;

  factory VetFieldReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return VetFieldReport(
      id: doc.id,
      vetId: data['vetId'] as String? ?? '',
      vetName: data['vetName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      farmerId: data['farmerId'] as String? ?? '',
      farmerName: data['farmerName'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'vetId': vetId,
      'vetName': vetName,
      'title': title,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'notes': notes,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
