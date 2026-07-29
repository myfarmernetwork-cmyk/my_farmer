import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceLockResult {
  final String? deviceId;
  final bool isDeviceAlreadyRegistered;

  const DeviceLockResult({
    required this.deviceId,
    required this.isDeviceAlreadyRegistered,
  });

  bool get shouldLockFreeScans => isDeviceAlreadyRegistered;
}

class DeviceLockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String?> getDeviceId() async {
    try {
      if (kIsWeb) return null;

      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return info.id;
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.identifierForVendor;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> isDeviceAlreadyRegistered(String deviceId) async {
    try {
      final doc =
          await _firestore.collection('registered_devices').doc(deviceId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceLockResult> evaluateDevice() async {
    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return const DeviceLockResult(
        deviceId: null,
        isDeviceAlreadyRegistered: false,
      );
    }

    final exists = await isDeviceAlreadyRegistered(deviceId);
    return DeviceLockResult(
      deviceId: deviceId,
      isDeviceAlreadyRegistered: exists,
    );
  }

  Future<void> registerDevice({
    required String deviceId,
    required String userId,
    required String email,
  }) async {
    await _firestore.collection('registered_devices').doc(deviceId).set({
      'userId': userId,
      'email': email.trim(),
      'registeredAt': FieldValue.serverTimestamp(),
    });
  }
}
