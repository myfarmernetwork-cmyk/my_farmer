import 'package:cloud_firestore/cloud_firestore.dart';

import 'medical_history_entry.dart';
import 'vet_conversation_message.dart';

class VeterinaryRequest {
  const VeterinaryRequest({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.vetId,
    required this.vetName,
    required this.animalId,
    required this.animalName,
    required this.animalSpecies,
    required this.animalAge,
    this.animalImageUrl = '',
    this.medicalNotes = '',
    this.medicalHistory = const [],
    this.medicalDocuments = const [],
    this.clientMemo = '',
    this.vetResponse = '',
    this.conversationMessages,
    this.vetConversationReadCount,
    this.importantMessageIds,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.respondedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String vetId;
  final String vetName;
  final String animalId;
  final String animalName;
  final String animalSpecies;
  final String animalAge;
  final String animalImageUrl;
  final String medicalNotes;
  final List<MedicalHistoryEntry> medicalHistory;
  final List<MedicalAttachment> medicalDocuments;
  final String clientMemo;
  final String vetResponse;
  final List<VetConversationMessage>? conversationMessages;
  final int? vetConversationReadCount;
  final List<String>? importantMessageIds;
  final String status;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? respondedAt;

  int get resolvedVetConversationReadCount => vetConversationReadCount ?? 0;

  List<String> get resolvedImportantMessageIds =>
      importantMessageIds ?? const [];

  List<VetConversationMessage> get effectiveConversationMessages {
    final stored = conversationMessages;
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    if (vetResponse.trim().isEmpty) {
      return const [];
    }
    return [
      VetConversationMessage(
        id: VetConversationMessage.legacyMessageId({
          'text': vetResponse.trim(),
          'sentAt': respondedAt ?? updatedAt,
        }),
        text: vetResponse.trim(),
        vetName: vetName,
        sentAt: respondedAt?.toDate() ?? updatedAt?.toDate(),
      ),
    ];
  }

  int get unreadConversationCount {
    final total = effectiveConversationMessages.length;
    final read = resolvedVetConversationReadCount;
    if (total <= read) return 0;
    return total - read;
  }

  bool isMessageImportant(VetConversationMessage message) {
    return resolvedImportantMessageIds.contains(message.id);
  }

  List<VetConversationMessage> get sortedConversationMessages {
    final messages = List<VetConversationMessage>.from(
      effectiveConversationMessages,
    );
    messages.sort((a, b) {
      final aImportant = isMessageImportant(a);
      final bImportant = isMessageImportant(b);
      if (aImportant != bImportant) {
        return aImportant ? -1 : 1;
      }
      final aTime = a.sentAt;
      final bTime = b.sentAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return messages;
  }

  List<VetConversationMessage> get importantConversationMessages {
    return sortedConversationMessages
        .where(isMessageImportant)
        .toList(growable: false);
  }

  factory VeterinaryRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rawHistory = data['medicalHistory'];
    final history = rawHistory is List
        ? rawHistory
            .map(
              (item) => MedicalHistoryEntry.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
        : <MedicalHistoryEntry>[];

    final rawDocuments = data['medicalDocuments'];
    final documents = rawDocuments is List
        ? rawDocuments
            .map(
              (item) => MedicalAttachment.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList()
        : <MedicalAttachment>[];

    final rawMessages = data['conversationMessages'];
    final conversationMessages = rawMessages is List
        ? rawMessages
            .map(
              (item) => VetConversationMessage.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .where((message) => message.text.trim().isNotEmpty)
            .toList()
        : null;

    final vetResponse = data['vetResponse'] as String? ?? '';
    final rawImportant = data['importantMessageIds'];
    final importantMessageIds = rawImportant is List
        ? rawImportant.map((item) => item.toString()).toList()
        : const <String>[];

    return VeterinaryRequest(
      id: doc.id,
      clientId: data['clientId'] as String? ?? '',
      clientName: data['clientName'] as String? ?? '',
      vetId: data['vetId'] as String? ?? '',
      vetName: data['vetName'] as String? ?? '',
      animalId: data['animalId'] as String? ?? '',
      animalName: data['animalName'] as String? ?? '',
      animalSpecies: data['animalSpecies'] as String? ?? '',
      animalAge: data['animalAge'] as String? ?? '',
      animalImageUrl: data['animalImageUrl'] as String? ?? '',
      medicalNotes: data['medicalNotes'] as String? ?? '',
      medicalHistory: history,
      medicalDocuments: documents,
      clientMemo: data['clientMemo'] as String? ?? '',
      vetResponse: vetResponse,
      conversationMessages: conversationMessages,
      vetConversationReadCount:
          (data['vetConversationReadCount'] as num?)?.toInt() ?? 0,
      importantMessageIds: importantMessageIds,
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
      respondedAt: data['respondedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'vetId': vetId,
      'vetName': vetName,
      'animalId': animalId,
      'animalName': animalName,
      'animalSpecies': animalSpecies,
      'animalAge': animalAge,
      'animalImageUrl': animalImageUrl,
      'medicalNotes': medicalNotes,
      'medicalHistory': medicalHistory.map((e) => e.toMap()).toList(),
      'medicalDocuments': medicalDocuments.map((d) => d.toMap()).toList(),
      'clientMemo': clientMemo.trim(),
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
