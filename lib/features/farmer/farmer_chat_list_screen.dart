import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/chat_repository.dart';
import '../../theme/agro_accent_colors.dart';
import '../../utils/chat_time_formatter.dart';
import '../../utils/scroll_bottom_padding.dart';
import '../../widgets/agro_glass_chrome.dart';
import '../chat/chat_screen.dart';

class FarmerChatListScreen extends ConsumerWidget {
  const FarmerChatListScreen({super.key});

  static const _chipGreen = AgroAccentColors.marketplaceChipGreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AgroAccentColors.marketplaceUnifiedGreen,
      appBar: AgroGlassAppBar(
        unifiedMarketplaceHeader: true,
        title: Text('chat_my_messages'.tr()),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AgroAccentColors.marketplaceUnifiedBackgroundGradient,
        ),
        child: currentUserId == null
            ? Center(
                child: Text(
                  'chat_login_required'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              )
            : _ChatRoomList(currentUserId: currentUserId),
      ),
    );
  }
}

class _ChatRoomList extends ConsumerWidget {
  const _ChatRoomList({required this.currentUserId});

  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatRepo = ref.watch(chatRepositoryProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: FarmerChatListScreen._chipGreen,
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'chat_load_error'.tr(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
            ),
          );
        }

        final myChats = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final participants = data['participants'] as List<dynamic>? ?? [];
          if (participants.contains(currentUserId)) return true;
          return doc.id.contains(currentUserId);
        }).toList();

        myChats.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>? ?? {};
          final bData = b.data() as Map<String, dynamic>? ?? {};
          final aTime = aData['lastMessageAt'] as Timestamp?;
          final bTime = bData['lastMessageAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (myChats.isEmpty) {
          return Center(
            child: Text(
              'chat_empty'.tr(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: ScrollBottomPadding.list(context),
          itemCount: myChats.length,
          itemBuilder: (context, index) {
            final roomDoc = myChats[index];
            final roomData = roomDoc.data() as Map<String, dynamic>? ?? {};
            final otherUserId =
                chatRepo.otherParticipantId(roomDoc.id, currentUserId);
            final unread =
                (roomData['unreadCounts'] as Map<String, dynamic>? ?? {})[
                        currentUserId] as num? ??
                    0;
            final preview = roomData['lastMessage'] as String? ?? '';
            final lastMessageAt = roomData['lastMessageAt'] as Timestamp?;
            final lastMessageDate = lastMessageAt?.toDate();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                final buyerData =
                    userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                final name =
                    buyerData['name'] as String? ?? 'common_user'.tr();

                return _ChatListTile(
                  name: name,
                  preview: preview.isEmpty
                      ? 'chat_tap_to_reply'.tr()
                      : preview,
                  unread: unread.toInt(),
                  lastMessageDate: lastMessageDate,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: otherUserId,
                          receiverName: name,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.name,
    required this.preview,
    required this.unread,
    required this.onTap,
    this.lastMessageDate,
  });

  final String name;
  final String preview;
  final int unread;
  final DateTime? lastMessageDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AgroAccentColors.marketplaceCornerRadius,
          ),
          side: BorderSide(
            color: FarmerChatListScreen._chipGreen.withValues(alpha: 0.22),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            AgroAccentColors.marketplaceCornerRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: FarmerChatListScreen._chipGreen,
                  child: unread > 0
                      ? Badge(
                          backgroundColor: Colors.red,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: FarmerChatListScreen._chipGreen,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (lastMessageDate != null)
                  Text(
                    ChatTimeFormatter.listTime(context, lastMessageDate!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: FarmerChatListScreen._chipGreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
