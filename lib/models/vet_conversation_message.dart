import 'package:cloud_firestore/cloud_firestore.dart';

class VetConversationMessage {
  const VetConversationMessage({
    required this.id,
    required this.text,
    required this.vetName,
    this.sentAt,
  });

  final String id;
  final String text;
  final String vetName;
  final DateTime? sentAt;

  factory VetConversationMessage.fromMap(Map<String, dynamic> map) {
    final sentAtRaw = map['sentAt'];
    DateTime? sentAt;
    if (sentAtRaw is Timestamp) {
      sentAt = sentAtRaw.toDate();
    } else if (sentAtRaw is DateTime) {
      sentAt = sentAtRaw;
    }

    final text = map['text'] as String? ?? '';
    final rawId = map['id'] as String? ?? '';
    final id = rawId.isNotEmpty ? rawId : legacyMessageId(map);

    return VetConversationMessage(
      id: id,
      text: text,
      vetName: map['vetName'] as String? ?? '',
      sentAt: sentAt,
    );
  }

  static String legacyMessageId(Map<String, dynamic> map) {
    final text = map['text'] as String? ?? '';
    final sentAtRaw = map['sentAt'];
    final sentKey = sentAtRaw is Timestamp
        ? sentAtRaw.millisecondsSinceEpoch.toString()
        : '0';
    return 'legacy_${sentKey}_${text.hashCode}';
  }

  static String createId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'msg_$now';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text.trim(),
      'vetName': vetName.trim(),
      'sentAt': sentAt != null
          ? Timestamp.fromDate(sentAt!)
          : Timestamp.now(),
    };
  }
}
