import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

enum FarmLocationRequestOutcome {
  success,
  servicesDisabled,
  permissionDenied,
  failed,
}

class FarmLocationService {
  FarmLocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<({
    FarmLocationRequestOutcome outcome,
    double? lat,
    double? lng,
  })> requestAndSave(String uid) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          outcome: FarmLocationRequestOutcome.servicesDisabled,
          lat: null,
          lng: null,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (
          outcome: FarmLocationRequestOutcome.permissionDenied,
          lat: null,
          lng: null,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      );

      await _firestore.collection('users').doc(uid).set(
        {
          'farmLat': position.latitude,
          'farmLng': position.longitude,
        },
        SetOptions(merge: true),
      );

      return (
        outcome: FarmLocationRequestOutcome.success,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      return (
        outcome: FarmLocationRequestOutcome.failed,
        lat: null,
        lng: null,
      );
    }
  }
}
