import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe coercion helpers for Firestore document fields.
class FirestoreParse {
  FirestoreParse._();

  static String stringOrEmpty(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  static String? optionalString(dynamic value) {
    final text = stringOrEmpty(value);
    return text.isEmpty ? null : text;
  }

  static bool boolOr(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }

  static int intOr(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static double doubleOr(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static List<String> stringListOrEmpty(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static Timestamp? timestampOrNull(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static Timestamp timestampOrNow(dynamic value) {
    return timestampOrNull(value) ?? Timestamp.now();
  }

  static Map<String, dynamic> mapOrEmpty(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(key.toString(), entry),
      );
    }
    return {};
  }

  static Map<String, dynamic>? documentData(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) return null;
    return mapOrEmpty(raw);
  }
}
