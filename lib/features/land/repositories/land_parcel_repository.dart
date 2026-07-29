import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/nirs_scan_result.dart';
import '../models/land_parcel.dart';

class LandParcelRepository {
  LandParcelRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'land_parcels';
  static const String nirsScansSubcollection = 'nirs_scans';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(collection);

  CollectionReference<Map<String, dynamic>> _nirsScansRef(String parcelId) =>
      _ref.doc(parcelId).collection(nirsScansSubcollection);

  Stream<List<LandParcel>> watchUserParcels(String ownerId) {
    return _ref.where('ownerId', isEqualTo: ownerId).snapshots().map(
      (snapshot) {
        final parcels =
            snapshot.docs.map(LandParcel.fromFirestore).toList(growable: true);
        parcels.sort((a, b) {
          final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });
        return parcels;
      },
    );
  }

  Future<List<LandParcel>> fetchUserParcels(String ownerId) async {
    final snapshot = await _ref.where('ownerId', isEqualTo: ownerId).get();
    final parcels =
        snapshot.docs.map(LandParcel.fromFirestore).toList(growable: true);
    parcels.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return parcels;
  }

  Stream<List<NirsScanResult>> watchNirsHistory(String parcelId) {
    return _nirsScansRef(parcelId)
        .orderBy('scannedAt', descending: true)
        .limit(12)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(NirsScanResult.fromHistoryDoc)
              .toList(growable: false),
        );
  }

  Future<String> saveParcel({
    required String ownerId,
    required String name,
    required List<LatLng> points,
    required double areaSquareMeters,
    required double perimeterMeters,
  }) async {
    final doc = await _ref.add({
      'ownerId': ownerId,
      'name': name.trim(),
      'points': points
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'areaSquareMeters': areaSquareMeters,
      'perimeterMeters': perimeterMeters,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<NirsScanResult> recordNirsScan({
    required String parcelId,
    required NirsScanResult result,
  }) async {
    final scanRef = _nirsScansRef(parcelId).doc();
    final stored = result.copyWith(id: scanRef.id);
    final batch = _firestore.batch();

    batch.set(scanRef, stored.toHistoryFirestore());
    batch.update(_ref.doc(parcelId), stored.toParcelSummaryFields());

    await batch.commit();
    return stored;
  }

  Future<void> deleteParcel(String parcelId) {
    return _ref.doc(parcelId).delete();
  }
}
