import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import '../config/plant_scanner_config.dart';
import '../models/plant_scan_result.dart';

class PlantScannerException implements Exception {
  final String messageKey;
  final Map<String, String> namedArgs;

  PlantScannerException(
    this.messageKey, {
    this.namedArgs = const {},
  });

  @override
  String toString() => messageKey;
}

class PlantIdService {
  /// Maps app locale codes to Plant.id API language parameter.
  static String apiLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'hr':
      case 'sr':
        return 'hr';
      case 'de':
        return 'de';
      case 'cs':
        return 'cs';
      case 'zh':
        return 'zh';
      case 'pl':
        return 'pl';
      case 'fr':
        return 'fr';
      case 'es':
        return 'es';
      case 'ru':
        return 'ru';
      case 'uk':
        return 'uk';
      default:
        return 'en';
    }
  }

  Future<PlantScanResult> identifyPlant(
    File imageFile, {
    String language = 'en',
  }) async {
    if (!PlantScannerConfig.isConfigured) {
      throw PlantScannerException('scanner_no_api_key');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final apiLanguage = apiLanguageCode(language);

    final Map<String, dynamic> decoded;
    if (PlantScannerConfig.useCloudFunction) {
      decoded = await _identifyViaCloud(
        base64Image: base64Image,
        language: apiLanguage,
      );
    } else {
      decoded = await _identifyDirect(
        base64Image: base64Image,
        language: apiLanguage,
      );
    }

    return PlantScanResult.fromJson(decoded);
  }

  Future<Map<String, dynamic>> _identifyViaCloud({
    required String base64Image,
    required String language,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('identifyPlant');
      final response = await callable.call({
        'images': [base64Image],
        'language': language,
      });
      return _normalizeJsonMap(response.data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw PlantScannerException('scanner_api_key_invalid');
      }
      if (e.code == 'resource-exhausted') {
        throw PlantScannerException('scanner_api_credits_exhausted');
      }
      throw PlantScannerException(
        'scanner_api_error',
        namedArgs: {'code': e.code},
      );
    }
  }

  Future<Map<String, dynamic>> _identifyDirect({
    required String base64Image,
    required String language,
  }) async {
    final uri = Uri.parse('${PlantScannerConfig.apiBaseUrl}/identification')
        .replace(
      queryParameters: {
        'details': 'common_names,description,treatment,local_name',
        'language': language,
      },
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Api-Key': PlantScannerConfig.apiKey,
          },
          body: jsonEncode({
            'images': [base64Image],
            'similar_images': true,
            'health': 'all',
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw PlantScannerException(
        'scanner_api_error',
        namedArgs: {'code': '${response.statusCode}'},
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cloud Functions return nested maps as Map<Object?, Object?> — deep cast.
  static Map<String, dynamic> _normalizeJsonMap(dynamic value) {
    final normalized = jsonDecode(jsonEncode(value));
    if (normalized is Map<String, dynamic>) return normalized;
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    throw PlantScannerException('scanner_api_error', namedArgs: {'code': 'parse'});
  }
}
