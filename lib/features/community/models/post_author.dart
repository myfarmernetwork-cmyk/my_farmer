class PostAuthor {
  final String uid;
  final String displayName;
  final String role;
  final String? location;
  final String? profileImageUrl;
  final double? farmLat;
  final double? farmLng;

  const PostAuthor({
    required this.uid,
    required this.displayName,
    required this.role,
    this.location,
    this.profileImageUrl,
    this.farmLat,
    this.farmLng,
  });

  bool get hasMapLocation =>
      farmLat != null && farmLng != null ||
      (location != null && location!.trim().isNotEmpty);

  static String? _resolveLocation(Map<String, dynamic> data) {
    final address = data['address']?.toString().trim();
    final city = data['city']?.toString().trim();
    final country = data['country']?.toString().trim();

    final parts = <String>[];
    void addPart(String? value) {
      if (value == null || value.isEmpty) return;
      final lower = value.toLowerCase();
      if (parts.any((part) => part.toLowerCase() == lower)) return;
      if (parts.any((part) => part.toLowerCase().contains(lower))) return;
      parts.add(value);
    }

    addPart(address);
    addPart(city);
    addPart(country);

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static double? _readCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  factory PostAuthor.fromMap(String uid, Map<String, dynamic> data) {
    final name = data['name']?.toString().trim();
    final email = data['email']?.toString().trim();
    final imageUrl = data['profileImageUrl']?.toString().trim();

    return PostAuthor(
      uid: uid,
      displayName: (name != null && name.isNotEmpty)
          ? name
          : (email?.isNotEmpty == true ? email! : '—'),
      role: data['role']?.toString() ?? 'buyer',
      location: _resolveLocation(data),
      profileImageUrl:
          imageUrl != null && imageUrl.isNotEmpty ? imageUrl : null,
      farmLat: _readCoordinate(data['farmLat']),
      farmLng: _readCoordinate(data['farmLng']),
    );
  }
}
