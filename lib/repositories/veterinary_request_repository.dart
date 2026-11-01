import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/animal_record.dart';
import '../models/medical_history_entry.dart';
import '../models/vet_conversation_message.dart';
import '../models/vet_appointment_status.dart';
import '../models/veterinary_request.dart';

class VeterinaryRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('veterinary_requests');

  Stream<List<VeterinaryRequest>> watchVetRequests(String vetId) {
    return _collection
        .where('vetId', isEqualTo: vetId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => VeterinaryRequest.fromFirestore(doc))
          .toList();
      requests.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return requests;
    });
  }

  Stream<VeterinaryRequest?> watchRequest(String requestId) {
    return _collection.doc(requestId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return VeterinaryRequest.fromFirestore(doc);
    });
  }

  Stream<VeterinaryRequest?> watchLatestForAnimal({
    required String clientId,
    required String animalId,
  }) {
    return _collection
        .where('clientId', isEqualTo: clientId)
        .where('animalId', isEqualTo: animalId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final requests = snapshot.docs
          .map((doc) => VeterinaryRequest.fromFirestore(doc))
          .toList();
      requests.sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return requests.first;
    });
  }

  Stream<VeterinaryRequest?> watchAnsweredForAnimal({
    required String clientId,
    required String animalId,
  }) {
    return _collection
        .where('clientId', isEqualTo: clientId)
        .where('animalId', isEqualTo: animalId)
        .snapshots()
        .map((snapshot) {
      final answered = snapshot.docs
          .map((doc) => VeterinaryRequest.fromFirestore(doc))
          .where(
            (r) => r.status == 'Answered' && r.vetResponse.trim().isNotEmpty,
          )
          .toList();
      if (answered.isEmpty) return null;
      answered.sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt;
        final bTime = b.updatedAt ?? b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return answered.first;
    });
  }

  Future<void> submitReferral({
    required AnimalRecord animal,
    required String vetId,
    required String vetName,
    required String clientMemo,
    String? clientName,
    DateTime? ownerPreferredAt,
    String? ownerPreferredNote,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Korisnik nije prijavljen');

    final allDocuments = <MedicalAttachment>[
      ...animal.medicalDocuments,
      for (final entry in animal.medicalHistory) ...entry.attachments,
    ];

    final request = VeterinaryRequest(
      id: '',
      clientId: user.uid,
      clientName: clientName?.trim().isNotEmpty == true
          ? clientName!.trim()
          : (user.displayName ?? 'Korisnik'),
      vetId: vetId,
      vetName: vetName,
      animalId: animal.id,
      animalName: animal.name,
      animalSpecies: animal.species,
      animalAge: animal.age,
      animalImageUrl: animal.imageUrl,
      medicalNotes: animal.medicalNotes,
      medicalHistory: animal.sortedMedicalHistory,
      medicalDocuments: allDocuments,
      clientMemo: clientMemo.trim(),
      ownerPreferredAt:
          ownerPreferredAt != null ? Timestamp.fromDate(ownerPreferredAt) : null,
      ownerPreferredNote: ownerPreferredNote?.trim() ?? '',
    );

    await _collection.add(request.toCreateMap());
  }

  Future<void> submitVetResponse({
    required String requestId,
    required String vetResponse,
    String? vetName,
    DateTime? proposedAppointmentAt,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Korisnik nije prijavljen');

    final trimmed = vetResponse.trim();
    final resolvedVetName =
        vetName?.trim().isNotEmpty == true ? vetName!.trim() : (user.displayName ?? 'Veterinar');
    final messageId = VetConversationMessage.createId();

    final update = <String, dynamic>{
      'vetResponse': trimmed,
      'status': 'Answered',
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'conversationMessages': FieldValue.arrayUnion([
        {
          'id': messageId,
          'text': trimmed,
          'vetName': resolvedVetName,
          'sentAt': Timestamp.now(),
        },
      ]),
    };

    if (proposedAppointmentAt != null) {
      update['appointmentStatus'] = VetAppointmentStatus.proposed;
      update['proposedAt'] = Timestamp.fromDate(proposedAppointmentAt);
      update['ownerCounterAt'] = FieldValue.delete();
      update['ownerCounterNote'] = FieldValue.delete();
      update['declinedAt'] = FieldValue.delete();
      update['declineReason'] = FieldValue.delete();
      update['confirmedAt'] = FieldValue.delete();
    } else {
      update['appointmentStatus'] = VetAppointmentStatus.none;
    }

    await _collection.doc(requestId).update(update);
  }

  Future<void> confirmAppointment({required String requestId}) async {
    final doc = await _collection.doc(requestId).get();
    if (!doc.exists) throw Exception('Request not found');
    final request = VeterinaryRequest.fromFirestore(doc);
    final target = request.proposedAt;
    if (target == null) {
      throw Exception('No proposed appointment');
    }

    await _collection.doc(requestId).update({
      'appointmentStatus': VetAppointmentStatus.confirmed,
      'confirmedAt': target,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> counterProposeAppointment({
    required String requestId,
    required DateTime appointmentAt,
    String? note,
  }) async {
    await _collection.doc(requestId).update({
      'appointmentStatus': VetAppointmentStatus.counter,
      'ownerCounterAt': Timestamp.fromDate(appointmentAt),
      'ownerCounterNote': note?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineAppointment({
    required String requestId,
    String? reason,
  }) async {
    await _collection.doc(requestId).update({
      'appointmentStatus': VetAppointmentStatus.declined,
      'declinedAt': FieldValue.serverTimestamp(),
      'declineReason': reason?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptOwnerCounterAppointment({
    required String requestId,
  }) async {
    final doc = await _collection.doc(requestId).get();
    if (!doc.exists) throw Exception('Request not found');
    final request = VeterinaryRequest.fromFirestore(doc);
    final target = request.ownerCounterAt;
    if (target == null) {
      throw Exception('No counter appointment');
    }

    await _collection.doc(requestId).update({
      'appointmentStatus': VetAppointmentStatus.confirmed,
      'confirmedAt': target,
      'proposedAt': target,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> vetProposeNewAppointment({
    required String requestId,
    required DateTime appointmentAt,
  }) async {
    await _collection.doc(requestId).update({
      'appointmentStatus': VetAppointmentStatus.proposed,
      'proposedAt': Timestamp.fromDate(appointmentAt),
      'ownerCounterAt': FieldValue.delete(),
      'ownerCounterNote': FieldValue.delete(),
      'declinedAt': FieldValue.delete(),
      'declineReason': FieldValue.delete(),
      'confirmedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markConversationAsRead({
    required String requestId,
    required int readCount,
  }) async {
    await _collection.doc(requestId).update({
      'vetConversationReadCount': readCount,
    });
  }

  Future<void> toggleMessageImportant({
    required String requestId,
    required String messageId,
    required bool important,
  }) async {
    await _collection.doc(requestId).update({
      'importantMessageIds': important
          ? FieldValue.arrayUnion([messageId])
          : FieldValue.arrayRemove([messageId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final veterinaryRequestRepositoryProvider =
    Provider<VeterinaryRequestRepository>(
  (ref) => VeterinaryRequestRepository(),
);

final vetIncomingRequestsProvider =
    StreamProvider.autoDispose<List<VeterinaryRequest>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(veterinaryRequestRepositoryProvider).watchVetRequests(uid);
});

final veterinaryRequestProvider =
    StreamProvider.autoDispose.family<VeterinaryRequest?, String>((ref, id) {
  return ref.watch(veterinaryRequestRepositoryProvider).watchRequest(id);
});

final animalVetRequestProvider = StreamProvider.autoDispose
    .family<VeterinaryRequest?, String>((ref, animalId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(veterinaryRequestRepositoryProvider)
      .watchLatestForAnimal(clientId: uid, animalId: animalId);
});

final animalVetResponseProvider = animalVetRequestProvider;
