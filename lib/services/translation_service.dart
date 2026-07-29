import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator/translator.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();
  final Map<String, String> _cache = {};

  /// Maps app locale codes to Google Translate API language codes.
  static String googleTranslateLanguageCode(String code) {
    final normalized = code.toLowerCase().split(RegExp(r'[-_]')).first;
    if (normalized.isEmpty) return 'auto';
    if (normalized == 'zh') return 'zh-CN';
    if (normalized == 'sr') return 'sr-Latn';
    return normalized;
  }

  Future<String> translateForViewer({
    required String text,
    required String sourceLanguage,
    required String viewerLanguage,
  }) async {
    if (text.trim().isEmpty) return text;

    final from = _normalizeLanguage(sourceLanguage);
    final to = _normalizeLanguage(viewerLanguage);
    if (from != 'auto' && from == to) return text;

    final cacheKey = '$from|$to|$text';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final result = await _translator.translate(
        text,
        from: from == 'auto' ? 'auto' : from,
        to: to,
      );
      _cache[cacheKey] = result.text;
      return result.text;
    } catch (_) {
      return text;
    }
  }

  String _normalizeLanguage(String code) {
    if (code.toLowerCase() == 'auto') return 'auto';
    return googleTranslateLanguageCode(code);
  }

  static String languageCodeFromPreference(String? preference) {
    if (preference == null || preference.trim().isEmpty) return 'en';
    return preference.split('_').first.toLowerCase();
  }
}

final translationServiceProvider = Provider<TranslationService>(
  (ref) => TranslationService(),
);
