import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalAttachment {
  final String url;
  final String type;
  final String name;

  const MedicalAttachment({
    required this.url,
    this.type = 'image',
    this.name = '',
  });

  factory MedicalAttachment.fromMap(Map<String, dynamic> data) {
    return MedicalAttachment(
      url: data['url'] as String? ?? '',
      type: data['type'] as String? ?? 'image',
      name: data['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      'name': name,
    };
  }
}

class MedicalHistoryEntry {
  final String id;
  final String note;
  final List<MedicalAttachment> attachments;
  final Timestamp? createdAt;

  const MedicalHistoryEntry({
    required this.id,
    required this.note,
    this.attachments = const [],
    this.createdAt,
  });

  factory MedicalHistoryEntry.fromMap(Map<String, dynamic> data) {
    final rawAttachments = data['attachments'];
    final attachments = rawAttachments is List
        ? rawAttachments
            .map(
              (item) => MedicalAttachment.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
        : <MedicalAttachment>[];

    return MedicalHistoryEntry(
      id: data['id'] as String? ?? '',
      note: data['note'] as String? ?? '',
      attachments: attachments,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'note': note,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}
