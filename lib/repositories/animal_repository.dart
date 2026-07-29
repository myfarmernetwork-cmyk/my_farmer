import 'dart:io';



import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as path;



import '../models/animal_record.dart';

import '../models/medical_history_entry.dart';



class AnimalRepository {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;



  CollectionReference<Map<String, dynamic>> get _collection =>

      _firestore.collection('animals');



  Stream<List<AnimalRecord>> watchUserAnimals(String userId) {

    return _collection.where('userId', isEqualTo: userId).snapshots().map(

      (snapshot) {

        final animals = snapshot.docs

            .map((doc) => AnimalRecord.fromFirestore(doc))

            .toList();

        animals.sort((a, b) {

          final aTime = a.updatedAt ?? a.createdAt;

          final bTime = b.updatedAt ?? b.createdAt;

          if (aTime == null && bTime == null) return 0;

          if (aTime == null) return 1;

          if (bTime == null) return -1;

          return bTime.compareTo(aTime);

        });

        return animals;

      },

    );

  }



  Future<String?> uploadAnimalImage(File imageFile, String userId) async {

    try {

      final fileName = path.basename(imageFile.path);

      final destination =

          'animals/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final ref = _storage.ref().child(destination);

      final snapshot = await ref.putFile(imageFile);

      return snapshot.ref.getDownloadURL();

    } catch (_) {

      return null;

    }

  }



  Future<MedicalAttachment?> uploadMedicalAttachment({

    required File file,

    required String userId,

    required String animalId,

  }) async {

    try {

      final fileName = path.basename(file.path);

      final ext = path.extension(fileName).toLowerCase();

      final type = ext == '.pdf' ? 'pdf' : 'image';

      final destination =

          'animals/$userId/records/$animalId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final ref = _storage.ref().child(destination);

      final snapshot = await ref.putFile(file);

      final url = await snapshot.ref.getDownloadURL();

      return MedicalAttachment(url: url, type: type, name: fileName);

    } catch (_) {

      return null;

    }

  }



  Future<AnimalRecord> createAnimal({

    required String name,

    required String species,

    required String age,

    required String medicalNotes,

    String imageUrl = '',

    List<MedicalAttachment> medicalDocuments = const [],

  }) async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) throw Exception('Korisnik nije prijavljen');



    final doc = await _collection.add({

      'userId': user.uid,

      'name': name.trim(),

      'species': species,

      'age': age.trim(),

      'imageUrl': imageUrl,

      'medicalNotes': medicalNotes.trim(),

      'medicalHistory': [],

      'medicalDocuments': medicalDocuments.map((d) => d.toMap()).toList(),

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),

    });



    final saved = await doc.get();

    return AnimalRecord.fromFirestore(saved);

  }



  Future<void> updateAnimal(AnimalRecord animal) async {

    await _collection.doc(animal.id).set(

      {

        ...animal.toMap(),

        'userId': animal.userId,

      },

      SetOptions(merge: true),

    );

  }



  Future<void> addMedicalHistoryEntry({

    required String animalId,

    required String note,

    required List<MedicalAttachment> attachments,

  }) async {

    final entry = MedicalHistoryEntry(

      id: DateTime.now().millisecondsSinceEpoch.toString(),

      note: note.trim(),

      attachments: attachments,

      createdAt: Timestamp.now(),

    );



    await _collection.doc(animalId).update({

      'medicalHistory': FieldValue.arrayUnion([entry.toMap()]),

      'updatedAt': FieldValue.serverTimestamp(),

    });

  }



  Future<void> deleteAnimal(String animalId) async {

    await _collection.doc(animalId).delete();

  }

}



final animalRepositoryProvider = Provider<AnimalRepository>(

  (ref) => AnimalRepository(),

);



final userAnimalsProvider = StreamProvider.autoDispose<List<AnimalRecord>>((ref) {

  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) return Stream.value([]);

  return ref.watch(animalRepositoryProvider).watchUserAnimals(uid);

});


