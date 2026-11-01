import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String roomIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  Future<void> touchRoom({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String preview,
  }) async {
    await _firestore.collection('chat_rooms').doc(roomId).set(
      {
        'participants': [senderId, receiverId],
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': preview,
        'unreadCounts.$receiverId': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markRoomRead({
    required String roomId,
    required String userId,
  }) async {
    await _firestore.collection('chat_rooms').doc(roomId).set(
      {
        'unreadCounts.$userId': 0,
        'lastSeenAt.$userId': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static DateTime? lastSeenAtForUser(
    Map<String, dynamic>? roomData,
    String userId,
  ) {
    if (roomData == null || userId.isEmpty) return null;
    final map = roomData['lastSeenAt'];
    if (map is! Map) return null;
    final value = map[userId];
    if (value is Timestamp) return value.toDate();
    return null;
  }

  Stream<int> watchUnreadTotal(String userId) {
    return _firestore.collection('chat_rooms').snapshots().map((snapshot) {
      var total = 0;
      for (final doc in snapshot.docs) {
        if (!doc.id.contains(userId)) continue;
        final counts =
            doc.data()['unreadCounts'] as Map<String, dynamic>? ?? {};
        total += (counts[userId] as num?)?.toInt() ?? 0;
      }
      return total;
    });
  }

  String otherParticipantId(String roomId, String currentUserId) {
    final parts = roomId.split('_');
    if (parts.length != 2) {
      return roomId.replaceFirst(currentUserId, '').replaceAll('_', '');
    }
    return parts.first == currentUserId ? parts.last : parts.first;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final uid = ref.watch(currentAuthUidProvider);
  if (uid == null) return Stream.value(0);
  return ref.watch(chatRepositoryProvider).watchUnreadTotal(uid);
});
