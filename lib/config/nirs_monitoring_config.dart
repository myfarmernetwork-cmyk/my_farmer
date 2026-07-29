/// NIRS/NDVI konfiguracija — live Sentinel-2 preko Firebase proxyja.

///

/// U APK idu samo:

/// - [useLiveSentinelApi] = true

/// - [sentinelApiBaseUrl] = Firebase `fetchNirsNdvi` URL

/// - [sentinelApiKey] = Bearer token (Sentinel Hub OAuth Client ID)

///

/// Na Firebase Functions (NE u APK):

/// - NIRS_API_KEY (= isti Bearer token)

/// - SENTINEL_HUB_CLIENT_ID

/// - SENTINEL_HUB_CLIENT_SECRET

import 'package:flutter/foundation.dart';



import 'subscription_limits.dart';



class NirsMonitoringConfig {

  NirsMonitoringConfig._();



  /// Firebase Cloud Function za NIRS (my-farmer-552a3).

  static const String defaultFetchNirsNdviUrl =

      'https://us-central1-my-farmer-552a3.cloudfunctions.net/fetchNirsNdvi';



  static int get monthlyLimit => SubscriptionLimits.proPremiumNirsMonthlyLoads;



  static const bool useLiveSentinelApi = bool.fromEnvironment(

    'NIRS_USE_LIVE_API',

    defaultValue: false,

  );



  static const String sentinelApiBaseUrl = String.fromEnvironment(

    'SENTINEL2_API_BASE_URL',

    defaultValue: '',

  );



  static const String sentinelApiKey = String.fromEnvironment(

    'SENTINEL2_API_KEY',

    defaultValue: '',

  );



  static bool get hasLiveApi =>

      useLiveSentinelApi &&

      resolvedApiBaseUrl.trim().isNotEmpty &&

      sentinelApiKey.trim().isNotEmpty;



  static String get resolvedApiBaseUrl {

    final raw = sentinelApiBaseUrl.trim();

    if (raw.isEmpty) return '';

    if (_isDirectSentinelHubHost(raw)) return defaultFetchNirsNdviUrl;

    return raw;

  }



  static bool _isDirectSentinelHubHost(String url) {

    final lower = url.toLowerCase();

    return lower == 'https://sentinel-hub.com' ||

        lower == 'https://www.sentinel-hub.com' ||

        lower.startsWith('https://services.sentinel-hub.com');

  }



  static void assertProductionReady() {

    if (!kReleaseMode) return;



    if (!useLiveSentinelApi) {

      throw StateError(

        'NIRS_USE_LIVE_API mora biti true u release buildu.',

      );

    }

    if (sentinelApiKey.trim().isEmpty) {

      throw StateError(

        'SENTINEL2_API_KEY je obavezan u release buildu.',

      );

    }

    if (resolvedApiBaseUrl.trim().isEmpty) {

      throw StateError(

        'SENTINEL2_API_BASE_URL mora biti Firebase fetchNirsNdvi URL.',

      );

    }

  }



  static const String liveSourceLabel = 'Sentinel-2';

  static const String simulationSourceLabel = 'Sentinel-2 (simulacija)';

}


