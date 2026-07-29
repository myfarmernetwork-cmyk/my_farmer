import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolygonGeoUtils {
  PolygonGeoUtils._();

  static const double _earthRadiusMeters = 6378137.0;

  static double computeAreaSquareMeters(List<LatLng> points) {
    if (points.length < 3) return 0;

    double area = 0;
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      area += _toRadians(p2.longitude - p1.longitude) *
          (2 +
              math.sin(_toRadians(p1.latitude)) +
              math.sin(_toRadians(p2.latitude)));
    }

    area = area * _earthRadiusMeters * _earthRadiusMeters / 2.0;
    return area.abs();
  }

  static double computePerimeterMeters(List<LatLng> points) {
    if (points.length < 2) return 0;

    var perimeter = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      perimeter += _haversineMeters(p1, p2);
    }
    return perimeter;
  }

  static double computeOpenPathMeters(List<LatLng> points) {
    if (points.length < 2) return 0;

    var length = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      length += _haversineMeters(points[i], points[i + 1]);
    }
    return length;
  }

  static double squareMetersToHectares(double squareMeters) {
    return squareMeters / 10000.0;
  }

  static LatLng computeCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    final lat =
        points.map((point) => point.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((point) => point.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  static LatLngBounds computeBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0, 0),
      );
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  /// Poreda točke u smjeru kazaljke na satu oko centroida — sprječava "pješčani sat".
  static List<LatLng> orderPointsCounterClockwise(List<LatLng> points) {
    if (points.length < 3) return List<LatLng>.from(points);

    final centerLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    final sorted = List<LatLng>.from(points);
    sorted.sort((a, b) {
      final angleA = math.atan2(
        a.latitude - centerLat,
        a.longitude - centerLng,
      );
      final angleB = math.atan2(
        b.latitude - centerLat,
        b.longitude - centerLng,
      );
      return angleA.compareTo(angleB);
    });
    return sorted;
  }

  static bool hasSelfIntersection(List<LatLng> points) {
    if (points.length < 4) return false;

    final n = points.length;
    for (var i = 0; i < n; i++) {
      final a1 = points[i];
      final a2 = points[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        if (j == i) continue;
        if ((i + 1) % n == j) continue;
        if (i == 0 && j == n - 1) continue;

        final b1 = points[j];
        final b2 = points[(j + 1) % n];
        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  static bool _segmentsIntersect(LatLng p1, LatLng p2, LatLng p3, LatLng p4) {
    final d1 = _direction(p3, p4, p1);
    final d2 = _direction(p3, p4, p2);
    final d3 = _direction(p1, p2, p3);
    final d4 = _direction(p1, p2, p4);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static double _direction(LatLng from, LatLng to, LatLng point) {
    return (point.longitude - from.longitude) * (to.latitude - from.latitude) -
        (point.latitude - from.latitude) * (to.longitude - from.longitude);
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  static double _haversineMeters(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLat = lat2 - lat1;
    final dLng = _toRadians(to.longitude - from.longitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }
}
