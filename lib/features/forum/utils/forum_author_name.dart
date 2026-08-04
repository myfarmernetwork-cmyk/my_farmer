import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Resolves a display name for forum posts from Firestore profile data.
class ForumAuthorName {
  ForumAuthorName._();

  static final Map<String, String> _cache = {};

  static const _genericNames = {
    'korisnik',
    'benutzer',
    'user',
    'forum_anonymous',
  };

  static Future<String> forCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return forUserId(user.uid, storedName: user.displayName);
  }

  static Future<String> forUserId(
    String userId, {
    String? storedName,
  }) async {
    final trimmedStored = storedName?.trim() ?? '';
    if (trimmedStored.isNotEmpty &&
        !_genericNames.contains(trimmedStored.toLowerCase())) {
      return trimmedStored;
    }

    if (userId.isEmpty) {
      return trimmedStored;
    }

    final cached = _cache[userId];
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data();
      final profileName = data?['name']?.toString().trim() ?? '';
      if (profileName.isNotEmpty &&
          !_genericNames.contains(profileName.toLowerCase())) {
        _cache[userId] = profileName;
        return profileName;
      }
    } catch (_) {
      // Fall through to stored name.
    }

    if (trimmedStored.isNotEmpty) return trimmedStored;
    return '';
  }

  static Future<Map<String, String>> forUserIds(Set<String> userIds) async {
    final result = <String, String>{};
    await Future.wait(
      userIds.map((id) async {
        result[id] = await forUserId(id);
      }),
    );
    return result;
  }

  static String label(String resolvedName, String anonymousLabel) {
    return resolvedName.trim().isNotEmpty ? resolvedName.trim() : anonymousLabel;
  }
}
