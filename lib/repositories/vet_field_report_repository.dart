import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../models/vet_field_report.dart';

class VetFieldReportRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('vet_field_reports');

  Stream<List<VetFieldReport>> watchVetReports(String vetId) {
    return _collection.where('vetId', isEqualTo: vetId).snapshots().map(
      (snapshot) {
        final reports = snapshot.docs
            .map((doc) => VetFieldReport.fromFirestore(doc))
            .toList();
        reports.sort((a, b) {
          final aTime = a.createdAt;
          final bTime = b.createdAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        return reports;
      },
    );
  }

  Future<String?> uploadPhoto({
    required File imageFile,
    required String vetId,
  }) async {
    try {
      final fileName = path.basename(imageFile.path);
      final destination =
          'vet_field_reports/$vetId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = _storage.ref().child(destination);
      final snapshot = await ref.putFile(imageFile);
      return snapshot.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> createReport({
    required String title,
    required String farmerId,
    required String farmerName,
    required String notes,
    String? photoUrl,
    String? vetName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Korisnik nije prijavljen');

    final report = VetFieldReport(
      id: '',
      vetId: user.uid,
      vetName: vetName?.trim().isNotEmpty == true
          ? vetName!.trim()
          : (user.displayName ?? 'Veterinar'),
      title: title.trim(),
      farmerId: farmerId.trim(),
      farmerName: farmerName.trim(),
      notes: notes.trim(),
      photoUrl: photoUrl,
    );

    await _collection.add(report.toCreateMap());
  }
}

final vetFieldReportRepositoryProvider = Provider<VetFieldReportRepository>(
  (ref) => VetFieldReportRepository(),
);

final vetFieldReportsProvider =
    StreamProvider.autoDispose<List<VetFieldReport>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(vetFieldReportRepositoryProvider).watchVetReports(uid);
});
