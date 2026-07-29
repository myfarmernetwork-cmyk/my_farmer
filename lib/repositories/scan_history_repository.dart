import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/plant_scan_result.dart';
import '../models/scan_history_entry.dart';

/// Retention policy: scan_history entries older than 365 days should be purged.
/// Call [purgeExpiredEntries] on app start / scanner open (client-side cleanup).
const scanHistoryRetentionDays = 365;

class ScanHistoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('scan_history');

  Stream<List<ScanHistoryEntry>> watchUserHistory(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final entries = snapshot.docs
          .map((doc) => ScanHistoryEntry.fromFirestore(doc))
          .toList();
      entries.sort((a, b) {
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      return entries;
    });
  }

  Future<void> saveScan({
    required File imageFile,
    required PlantScanResult result,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final imageUrl = await _uploadImage(imageFile, user.uid);
    if (imageUrl == null) return;

    final topDisease =
        result.diseases.isNotEmpty ? result.diseases.first : null;

    await _collection.add({
      'userId': user.uid,
      'imageUrl': imageUrl,
      'plantName': result.commonName ?? result.scientificName ?? 'Nepoznato',
      'scientificName': result.scientificName ?? '',
      'diagnosis': topDisease != null
          ? (topDisease.localName ?? topDisease.name)
          : (result.isHealthy == true ? 'Zdrava biljka' : ''),
      'recommendedTreatment': topDisease?.treatment ?? '',
      'confidence': result.identificationConfidence,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _uploadImage(File imageFile, String userId) async {
    try {
      final fileName = path.basename(imageFile.path);
      final destination =
          'scan_history/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child(destination);
      final snapshot = await ref.putFile(imageFile);
      return snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  /// Deletes entries older than [scanHistoryRetentionDays] for the current user.
  Future<void> purgeExpiredEntries() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cutoff = DateTime.now().subtract(
      const Duration(days: scanHistoryRetentionDays),
    );

    final snapshot = await _collection
        .where('userId', isEqualTo: user.uid)
        .get();

    final batch = _firestore.batch();
    var deletes = 0;

    for (final doc in snapshot.docs) {
      final createdAt = doc.data()['createdAt'] as Timestamp?;
      if (createdAt == null) continue;
      if (createdAt.toDate().isBefore(cutoff)) {
        batch.delete(doc.reference);
        deletes++;
      }
    }

    if (deletes > 0) {
      await batch.commit();
    }
  }
}

final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>(
  (ref) => ScanHistoryRepository(),
);

final userScanHistoryProvider = StreamProvider.autoDispose<List<ScanHistoryEntry>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(scanHistoryRepositoryProvider).watchUserHistory(uid);
});
