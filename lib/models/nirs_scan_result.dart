import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';



import 'nirs_ndvi_level.dart';



class NirsScanResult {

  const NirsScanResult({

    this.id,

    required this.ndviMean,

    required this.moistureIndex,

    required this.healthKey,

    required this.adviceKey,

    required this.scannedAt,

    required this.source,

    this.isSimulated = false,

    this.imageryCaptureDate,

    this.cloudCoverPercent,

  });



  final String? id;

  final double ndviMean;

  final double moistureIndex;

  final String healthKey;

  final String adviceKey;



  /// When the analysis was run in the app (always set).

  final DateTime scannedAt;



  final String source;

  final bool isSimulated;



  /// Actual Sentinel-2 scene datetime (live API only).

  final DateTime? imageryCaptureDate;

  final double? cloudCoverPercent;



  /// Date shown as “satellite capture” — live imagery date or scan time in simulation.

  DateTime get displayImageryDate => imageryCaptureDate ?? scannedAt;



  bool get isImageryStale {

    if (isSimulated || imageryCaptureDate == null) return false;

    return DateTime.now().difference(imageryCaptureDate!).inDays > 7;

  }



  int? get imageryAgeDays {

    if (imageryCaptureDate == null) return null;

    return DateTime.now().difference(imageryCaptureDate!).inDays;

  }



  NirsScanResult copyWith({String? id}) {

    return NirsScanResult(

      id: id ?? this.id,

      ndviMean: ndviMean,

      moistureIndex: moistureIndex,

      healthKey: healthKey,

      adviceKey: adviceKey,

      scannedAt: scannedAt,

      source: source,

      isSimulated: isSimulated,

      imageryCaptureDate: imageryCaptureDate,

      cloudCoverPercent: cloudCoverPercent,

    );

  }



  static DateTime? _parseTimestamp(dynamic raw) {

    if (raw is Timestamp) return raw.toDate();

    if (raw is DateTime) return raw;

    if (raw is String) return DateTime.tryParse(raw);

    return null;

  }



  factory NirsScanResult.fromParcelSummary(Map<String, dynamic> data) {

    final scannedAt = _parseTimestamp(data['lastNirsAt']) ?? DateTime.now();

    final imageryCaptureDate = _parseTimestamp(data['lastNirsImageryAt']);



    final ndvi = (data['lastNirsNdvi'] as num?)?.toDouble() ?? 0;

    final moisture = (data['lastNirsMoisture'] as num?)?.toDouble() ?? 0;



    return NirsScanResult(

      ndviMean: ndvi,

      moistureIndex: moisture,

      healthKey:

          data['lastNirsHealthKey']?.toString() ?? NirsNdviLevel.healthKeyFor(ndvi),

      adviceKey: data['lastNirsAdviceKey']?.toString() ??

          NirsNdviLevel.adviceKeyFor(ndvi: ndvi, moistureIndex: moisture),

      scannedAt: scannedAt,

      source: data['lastNirsSource']?.toString() ?? 'Sentinel-2',

      isSimulated: data['lastNirsSimulated'] == true,

      imageryCaptureDate: imageryCaptureDate,

      cloudCoverPercent: (data['lastNirsCloudCover'] as num?)?.toDouble(),

    );

  }



  factory NirsScanResult.fromHistoryDoc(

    DocumentSnapshot<Map<String, dynamic>> doc,

  ) {

    final data = doc.data() ?? {};

    final scannedAt = _parseTimestamp(data['scannedAt']) ?? DateTime.now();

    final imageryCaptureDate = _parseTimestamp(data['imageryCaptureDate']);



    final ndvi = (data['ndviMean'] as num?)?.toDouble() ?? 0;

    final moisture = (data['moistureIndex'] as num?)?.toDouble() ?? 0;



    return NirsScanResult(

      id: doc.id,

      ndviMean: ndvi,

      moistureIndex: moisture,

      healthKey:

          data['healthKey']?.toString() ?? NirsNdviLevel.healthKeyFor(ndvi),

      adviceKey: data['adviceKey']?.toString() ??

          NirsNdviLevel.adviceKeyFor(ndvi: ndvi, moistureIndex: moisture),

      scannedAt: scannedAt,

      source: data['source']?.toString() ?? 'Sentinel-2',

      isSimulated: data['isSimulated'] == true,

      imageryCaptureDate: imageryCaptureDate,

      cloudCoverPercent: (data['cloudCoverPercent'] as num?)?.toDouble(),

    );

  }



  Map<String, dynamic> toParcelSummaryFields() {

    return {

      'lastNirsNdvi': ndviMean,

      'lastNirsMoisture': moistureIndex,

      'lastNirsHealthKey': healthKey,

      'lastNirsAdviceKey': adviceKey,

      'lastNirsSource': source,

      'lastNirsSimulated': isSimulated,

      'lastNirsAt': Timestamp.fromDate(scannedAt),

      if (imageryCaptureDate != null)

        'lastNirsImageryAt': Timestamp.fromDate(imageryCaptureDate!),

      if (cloudCoverPercent != null) 'lastNirsCloudCover': cloudCoverPercent,

    };

  }



  Map<String, dynamic> toHistoryFirestore() {

    return {

      'ndviMean': ndviMean,

      'moistureIndex': moistureIndex,

      'healthKey': healthKey,

      'adviceKey': adviceKey,

      'source': source,

      'isSimulated': isSimulated,

      'scannedAt': Timestamp.fromDate(scannedAt),

      if (imageryCaptureDate != null)

        'imageryCaptureDate': Timestamp.fromDate(imageryCaptureDate!),

      if (cloudCoverPercent != null) 'cloudCoverPercent': cloudCoverPercent,

    };

  }



  Color get ndviColor {

    if (ndviMean >= NirsNdviLevel.goodMin) return Colors.green.shade700;

    if (ndviMean >= NirsNdviLevel.moderateMin) return Colors.orange.shade700;

    return Colors.red.shade700;

  }



  Color get polygonFillColor {

    if (ndviMean >= NirsNdviLevel.goodMin) {

      return Colors.green.withValues(alpha: 0.42);

    }

    if (ndviMean >= NirsNdviLevel.moderateMin) {

      return Colors.orange.withValues(alpha: 0.38);

    }

    return Colors.red.withValues(alpha: 0.35);

  }



  double? ndviDeltaFrom(NirsScanResult? previous) {

    if (previous == null) return null;

    return ndviMean - previous.ndviMean;

  }

}


