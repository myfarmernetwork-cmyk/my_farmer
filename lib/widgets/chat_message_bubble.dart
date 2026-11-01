import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/translation_service.dart';
import '../theme/agro_accent_colors.dart';
import '../utils/chat_time_formatter.dart';

class ChatMessageBubble extends ConsumerStatefulWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.originalMessage,
    this.messageType = 'text',
    required this.sourceLanguage,
    required this.viewerLanguage,
    required this.isMe,
    this.messageTime,
    this.isSeenByPeer = false,
  });

  final String message;
  final String? originalMessage;
  final String messageType;
  final String sourceLanguage;
  final String viewerLanguage;
  final bool isMe;
  final DateTime? messageTime;
  final bool isSeenByPeer;

  @override
  ConsumerState<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
  String? _displayText;
  bool _showOriginal = false;
  bool _isTranslating = false;
  bool _wasTranslated = false;

  bool get _isMedicalCard => widget.messageType == 'medical_card';

  @override
  void initState() {
    super.initState();
    _resolveText();
  }

  @override
  void didUpdateWidget(covariant ChatMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.originalMessage != widget.originalMessage ||
        oldWidget.messageType != widget.messageType ||
        oldWidget.sourceLanguage != widget.sourceLanguage ||
        oldWidget.viewerLanguage != widget.viewerLanguage ||
        oldWidget.isSeenByPeer != widget.isSeenByPeer) {
      _showOriginal = false;
      _resolveText();
    }
  }

  Future<void> _resolveText() async {
    if (widget.isMe) {
      final senderText = widget.originalMessage ?? widget.message;
      setState(() {
        _displayText = senderText;
        _wasTranslated = _isMedicalCard &&
            widget.originalMessage != null &&
            widget.originalMessage != widget.message;
        _isTranslating = false;
      });
      return;
    }

    if (_isMedicalCard) {
      setState(() {
        _displayText = widget.message;
        _wasTranslated = false;
        _isTranslating = false;
      });
      return;
    }

    final from = widget.sourceLanguage.trim();
    final to = widget.viewerLanguage.trim();
    if (from.isNotEmpty && from.split('_').first == to.split('_').first) {
      setState(() {
        _displayText = widget.message;
        _wasTranslated = false;
        _isTranslating = false;
      });
      return;
    }

    setState(() => _isTranslating = true);

    final translated =
        await ref.read(translationServiceProvider).translateForViewer(
              text: widget.message,
              sourceLanguage: from.isEmpty ? 'auto' : from,
              viewerLanguage: to,
            );

    if (!mounted) return;

    setState(() {
      _displayText = translated;
      _wasTranslated = translated != widget.message;
      _isTranslating = false;
    });
  }

  String _toggleLabel() {
    if (_isMedicalCard && widget.isMe) {
      return _showOriginal ? 'chat_show_translated'.tr() : 'chat_show_original'.tr();
    }
    return _showOriginal ? 'chat_show_translated'.tr() : 'chat_tap_for_original'.tr();
  }

  BoxDecoration _bubbleDecoration() {
    const radius = AgroAccentColors.marketplaceCornerRadius;

    if (_isMedicalCard) {
      return BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.orange.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );
    }

    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AgroAccentColors.marketplaceChipGreen.withValues(alpha: 0.22),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Color get _primaryTextColor => AgroAccentColors.marketplaceChipGreen;

  Color get _metaTextColor => Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    final baseText = widget.isMe && _isMedicalCard
        ? (widget.originalMessage ?? widget.message)
        : widget.message;

    final text = _showOriginal
        ? (widget.isMe && _isMedicalCard ? widget.message : baseText)
        : (_displayText ??
            (_isMedicalCard && !widget.isMe ? widget.message : baseText));

    final canToggle = widget.isMe
        ? _isMedicalCard && widget.originalMessage != null
        : _wasTranslated;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: canToggle ? () => setState(() => _showOriginal = !_showOriginal) : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: _bubbleDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isMedicalCard)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medical_services,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'animals_medical_card'.tr(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isTranslating)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AgroAccentColors.marketplaceChipGreen,
                  ),
                )
              else
                Text(
                  text,
                  style: TextStyle(
                    height: 1.35,
                    color: _primaryTextColor,
                  ),
                ),
              if (canToggle && !_isTranslating) ...[
                const SizedBox(height: 4),
                Text(
                  _toggleLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _metaTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else if (_wasTranslated && !_isTranslating) ...[
                const SizedBox(height: 4),
                Text(
                  _toggleLabel(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _metaTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ] else if (_isMedicalCard &&
                  widget.isMe &&
                  widget.originalMessage != null &&
                  widget.originalMessage != widget.message &&
                  !_isTranslating) ...[
                const SizedBox(height: 4),
                Text(
                  _showOriginal
                      ? 'chat_show_translated'.tr()
                      : 'chat_medical_sent_translated'.tr(),
                  style: TextStyle(
                    fontSize: 10,
                    color: _metaTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (!_isTranslating) ...[
                const SizedBox(height: 4),
                Align(
                  alignment:
                      widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.messageTime != null) ...[
                        Text(
                          ChatTimeFormatter.bubbleTime(
                            context,
                            widget.messageTime!,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: _metaTextColor,
                          ),
                        ),
                        if (widget.isMe) const SizedBox(width: 6),
                      ],
                      if (widget.isMe) ...[
                        Icon(
                          widget.isSeenByPeer ? Icons.done_all : Icons.done,
                          size: 14,
                          color: widget.isSeenByPeer
                              ? AgroAccentColors.marketplaceChipGreen
                              : _metaTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isSeenByPeer
                              ? 'chat_status_seen'.tr()
                              : 'chat_status_sent'.tr(),
                          style: TextStyle(
                            fontSize: 10,
                            color: widget.isSeenByPeer
                                ? AgroAccentColors.marketplaceChipGreen
                                : _metaTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
