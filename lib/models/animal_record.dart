import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import 'medical_history_entry.dart';

class AnimalRecord {

  final String id;

  final String userId;

  final String name;

  final String species;

  final String age;

  final String imageUrl;

  final String medicalNotes;

  final List<MedicalHistoryEntry> medicalHistory;

  final List<MedicalAttachment> medicalDocuments;

  final Timestamp? createdAt;

  final Timestamp? updatedAt;



  const AnimalRecord({

    required this.id,

    required this.userId,

    required this.name,

    required this.species,

    required this.age,

    this.imageUrl = '',

    this.medicalNotes = '',

    this.medicalHistory = const [],

    this.medicalDocuments = const [],

    this.createdAt,

    this.updatedAt,

  });



  static const speciesCodes = [
    'dog',
    'cat',
    'cow',
    'sheep',
    'goat',
    'horse',
    'pig',
    'chicken',
    'other',
  ];

  @Deprecated('Use speciesCodes')
  static List<String> get speciesOptions => speciesCodes;

  static String normalizeSpecies(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dog':
      case 'pas':
      case 'hund':
        return 'dog';
      case 'cat':
      case 'mačka':
      case 'macka':
      case 'katze':
        return 'cat';
      case 'cow':
      case 'krava':
      case 'kuh':
        return 'cow';
      case 'sheep':
      case 'ovca':
      case 'schaf':
        return 'sheep';
      case 'goat':
      case 'koza':
      case 'ziege':
        return 'goat';
      case 'horse':
      case 'konj':
      case 'pferd':
        return 'horse';
      case 'pig':
      case 'svinja':
      case 'schwein':
        return 'pig';
      case 'chicken':
      case 'piletina':
      case 'perad':
      case 'živina':
      case 'zivina':
      case 'pilići':
      case 'pilića':
      case 'pilić':
      case 'huhn':
      case 'geflügel':
      case 'geflugel':
      case 'poultry':
        return 'chicken';
      case 'other':
      case 'ostalo':
      case 'sonstiges':
        return 'other';
      default:
        return raw.isEmpty ? 'other' : 'other';
    }
  }

  static String speciesLabel(String code) =>
      'species_${normalizeSpecies(code)}'.tr();



  List<MedicalHistoryEntry> get sortedMedicalHistory {

    final copy = List<MedicalHistoryEntry>.from(medicalHistory);

    copy.sort((a, b) {

      final at = a.createdAt;

      final bt = b.createdAt;

      if (at == null && bt == null) return 0;

      if (at == null) return 1;

      if (bt == null) return -1;

      return bt.compareTo(at);

    });

    return copy;

  }



  factory AnimalRecord.fromFirestore(DocumentSnapshot doc) {

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



    return AnimalRecord(

      id: doc.id,

      userId: data['userId'] as String? ?? '',

      name: data['name'] as String? ?? '',

      species: normalizeSpecies(data['species'] as String? ?? 'other'),

      age: data['age'] as String? ?? '',

      imageUrl: data['imageUrl'] as String? ?? '',

      medicalNotes: data['medicalNotes'] as String? ?? '',

      medicalHistory: history,

      medicalDocuments: documents,

      createdAt: data['createdAt'] as Timestamp?,

      updatedAt: data['updatedAt'] as Timestamp?,

    );

  }



  Map<String, dynamic> toMap({bool includeTimestamps = true}) {

    return {

      'userId': userId,

      'name': name.trim(),

      'species': species,

      'age': age.trim(),

      'imageUrl': imageUrl,

      'medicalNotes': medicalNotes.trim(),

      'medicalHistory': medicalHistory.map((e) => e.toMap()).toList(),

      'medicalDocuments': medicalDocuments.map((d) => d.toMap()).toList(),

      if (includeTimestamps) 'updatedAt': FieldValue.serverTimestamp(),

    };

  }



  String formatMedicalCard({

    String? cardTitle,

    List<MedicalHistoryEntry>? selectedEntries,

  }) {

    final title = cardTitle ?? 'animals_medical_card'.tr();

    final buffer = StringBuffer()

      ..writeln(title)

      ..writeln('────────────────')

      ..writeln('${'animals_name'.tr()}: $name')

      ..writeln('${'animals_species'.tr()}: ${speciesLabel(species)}')

      ..writeln('${'animals_age'.tr()}: $age');



    if (medicalNotes.trim().isNotEmpty) {

      buffer

        ..writeln('')

        ..writeln('${'animals_general_notes'.tr()}:')

        ..writeln(medicalNotes.trim());

    }



    final entries = selectedEntries ?? sortedMedicalHistory;

    if (entries.isNotEmpty) {

      buffer.writeln('');

      buffer.writeln('${'animals_medical_history'.tr()}:');

      for (final entry in entries) {

        final dateLabel = entry.createdAt != null

            ? DateFormatHelper.formatTimestamp(entry.createdAt!)

            : 'animals_no_date'.tr();

        buffer

          ..writeln('')

          ..writeln('📅 $dateLabel')

          ..writeln(entry.note);

        for (final attachment in entry.attachments) {

          buffer.writeln(

            '📎 ${attachment.name.isEmpty ? attachment.type : attachment.name}: ${attachment.url}',

          );

        }

      }

    }



    return buffer.toString().trim();

  }



  AnimalRecord copyWith({

    String? id,

    String? userId,

    String? name,

    String? species,

    String? age,

    String? imageUrl,

    String? medicalNotes,

    List<MedicalHistoryEntry>? medicalHistory,

    List<MedicalAttachment>? medicalDocuments,

    Timestamp? createdAt,

    Timestamp? updatedAt,

  }) {

    return AnimalRecord(

      id: id ?? this.id,

      userId: userId ?? this.userId,

      name: name ?? this.name,

      species: species ?? this.species,

      age: age ?? this.age,

      imageUrl: imageUrl ?? this.imageUrl,

      medicalNotes: medicalNotes ?? this.medicalNotes,

      medicalHistory: medicalHistory ?? this.medicalHistory,

      medicalDocuments: medicalDocuments ?? this.medicalDocuments,

      createdAt: createdAt ?? this.createdAt,

      updatedAt: updatedAt ?? this.updatedAt,

    );

  }

}



class DateFormatHelper {

  static String formatTimestamp(Timestamp timestamp) {

    final date = timestamp.toDate();

    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}.';

  }

}


