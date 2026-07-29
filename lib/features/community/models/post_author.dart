class PostAuthor {
  final String uid;
  final String displayName;
  final String role;
  final String? location;

  const PostAuthor({
    required this.uid,
    required this.displayName,
    required this.role,
    this.location,
  });

  factory PostAuthor.fromMap(String uid, Map<String, dynamic> data) {
    final name = data['name']?.toString().trim();
    final email = data['email']?.toString().trim();
    final address = data['address']?.toString().trim();
    final city = data['city']?.toString().trim();

    String? location;
    if (address != null && address.isNotEmpty) {
      location = address;
    } else if (city != null && city.isNotEmpty) {
      location = city;
    }

    return PostAuthor(
      uid: uid,
      displayName: (name != null && name.isNotEmpty)
          ? name
          : (email?.isNotEmpty == true ? email! : '—'),
      role: data['role']?.toString() ?? 'buyer',
      location: location,
    );
  }
}
