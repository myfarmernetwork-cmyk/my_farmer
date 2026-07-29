/// Plant.id (Kindwise) — ključ na serveru (preporučeno) ili lokalno za dev.

///

/// Produkcija (Cloud Function `identifyPlant`, ključ NE ide u APK):

/// ```bash

/// --dart-define=PLANT_SCANNER_USE_CLOUD=true

/// ```

/// Postavite `PLANT_ID_API_KEY` u Firebase Functions secrets.

///

/// Lokalni dev bez Firebase deploya:

/// ```bash

/// --dart-define=PLANT_SCANNER_USE_CLOUD=false

/// --dart-define=PLANT_ID_API_KEY=your_key

/// ```

import 'package:flutter/foundation.dart';



class PlantScannerConfig {

  PlantScannerConfig._();



  static const bool useCloudFunction = bool.fromEnvironment(

    'PLANT_SCANNER_USE_CLOUD',

    defaultValue: false,

  );



  static const String apiKey = String.fromEnvironment(

    'PLANT_ID_API_KEY',

    defaultValue: '',

  );



  static bool get isConfigured => useCloudFunction || apiKey.isNotEmpty;



  static const String apiBaseUrl = 'https://api.plant.id/v3';



  /// Release build mora koristiti Cloud Function proxy (ključ na serveru).

  static void assertProductionReady() {

    if (!kReleaseMode) return;



    if (!useCloudFunction) {

      throw StateError(

        'PLANT_SCANNER_USE_CLOUD mora biti true u release buildu.',

      );

    }

    if (apiKey.isNotEmpty) {

      throw StateError(

        'PLANT_ID_API_KEY ne smije biti u release APK-u. '

        'Koristite Firebase secret PLANT_ID_API_KEY.',

      );

    }

  }

}


