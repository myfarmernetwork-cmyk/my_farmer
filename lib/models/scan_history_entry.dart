import 'package:cloud_firestore/cloud_firestore.dart';

class ScanHistoryEntry {
  final String id;
  final String userId;
  final String imageUrl;
  final String plantName;
  final String scientificName;
  final String diagnosis;
  final String recommendedTreatment;
  final double confidence;
  final Timestamp? createdAt;

  const ScanHistoryEntry({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.plantName,
    this.scientificName = '',
    this.diagnosis = '',
    this.recommendedTreatment = '',
    this.confidence = 0,
    this.createdAt,
  });

  factory ScanHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ScanHistoryEntry(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      plantName: data['plantName'] as String? ?? '',
      scientificName: data['scientificName'] as String? ?? '',
      diagnosis: data['diagnosis'] as String? ?? '',
      recommendedTreatment: data['recommendedTreatment'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'plantName': plantName,
      'scientificName': scientificName,
      'diagnosis': diagnosis,
      'recommendedTreatment': recommendedTreatment,
      'confidence': confidence,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
