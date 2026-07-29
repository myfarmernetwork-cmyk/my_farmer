import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/translation_service.dart';

/// Auto-translates user-generated text to the viewer's active app language.
class TranslatedText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? sourceLanguage;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.sourceLanguage,
  });

  @override
  ConsumerState<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends ConsumerState<TranslatedText> {
  String _display = '';
  Locale? _lastLocale;

  @override
  void initState() {
    super.initState();
    _display = widget.text;
    _translate();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.sourceLanguage != widget.sourceLanguage) {
      _display = widget.text;
      _translate();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = context.locale;
    if (_lastLocale != locale) {
      _lastLocale = locale;
      _display = widget.text;
      _translate();
    }
  }

  Future<void> _translate() async {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _display = widget.text);
      return;
    }

    final viewerLanguage = TranslationService.googleTranslateLanguageCode(
      context.locale.languageCode,
    );
    final translated = await ref.read(translationServiceProvider).translateForViewer(
          text: trimmed,
          sourceLanguage: widget.sourceLanguage ?? 'auto',
          viewerLanguage: viewerLanguage,
        );

    if (mounted && widget.text.trim() == trimmed) {
      setState(() => _display = translated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _display,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
