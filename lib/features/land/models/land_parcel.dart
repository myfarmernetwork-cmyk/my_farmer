import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/nirs_scan_result.dart';
class LandParcel {
  const LandParcel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.points,
    required this.areaSquareMeters,
    required this.perimeterMeters,
    this.createdAt,
    this.lastNirsNdvi,
    this.lastNirsMoisture,
    this.lastNirsHealthKey,
    this.lastNirsAdviceKey,
    this.lastNirsAt,
    this.lastNirsSource,
    this.lastNirsSimulated,
  });

  final String id;
  final String ownerId;
  final String name;
  final List<LatLng> points;
  final double areaSquareMeters;
  final double perimeterMeters;
  final Timestamp? createdAt;
  final double? lastNirsNdvi;
  final double? lastNirsMoisture;
  final String? lastNirsHealthKey;
  final String? lastNirsAdviceKey;
  final Timestamp? lastNirsAt;
  final String? lastNirsSource;
  final bool? lastNirsSimulated;

  double get areaHectares => areaSquareMeters / 10000.0;

  bool get hasNirsScan => lastNirsNdvi != null && lastNirsAt != null;

  NirsScanResult? get lastNirsScan {
    if (!hasNirsScan) return null;
    return NirsScanResult.fromParcelSummary({
      'lastNirsNdvi': lastNirsNdvi,
      'lastNirsMoisture': lastNirsMoisture,
      'lastNirsHealthKey': lastNirsHealthKey,
      'lastNirsAdviceKey': lastNirsAdviceKey,
      'lastNirsSource': lastNirsSource,
      'lastNirsSimulated': lastNirsSimulated,
      'lastNirsAt': lastNirsAt,
    });
  }

  factory LandParcel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawPoints = data['points'];
    final points = <LatLng>[];

    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is Map) {
          final lat = (item['lat'] as num?)?.toDouble();
          final lng = (item['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
    }

    return LandParcel(
      id: doc.id,
      ownerId: data['ownerId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      points: points,
      areaSquareMeters: (data['areaSquareMeters'] as num?)?.toDouble() ?? 0,
      perimeterMeters: (data['perimeterMeters'] as num?)?.toDouble() ?? 0,
      createdAt: data['createdAt'] as Timestamp?,
      lastNirsNdvi: (data['lastNirsNdvi'] as num?)?.toDouble(),
      lastNirsMoisture: (data['lastNirsMoisture'] as num?)?.toDouble(),
      lastNirsHealthKey: data['lastNirsHealthKey']?.toString(),
      lastNirsAdviceKey: data['lastNirsAdviceKey']?.toString(),
      lastNirsAt: data['lastNirsAt'] as Timestamp?,
      lastNirsSource: data['lastNirsSource']?.toString(),
      lastNirsSimulated: data['lastNirsSimulated'] as bool?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'points': points
          .map((point) => {'lat': point.latitude, 'lng': point.longitude})
          .toList(),
      'areaSquareMeters': areaSquareMeters,
      'perimeterMeters': perimeterMeters,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
