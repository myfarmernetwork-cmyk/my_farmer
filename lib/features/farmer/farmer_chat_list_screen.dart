import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:easy_localization/easy_localization.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../repositories/chat_repository.dart';

import '../chat/chat_screen.dart';



class FarmerChatListScreen extends ConsumerWidget {

  const FarmerChatListScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {

      return Scaffold(

        body: Center(child: Text('chat_login_required'.tr())),

      );

    }



    final chatRepo = ref.watch(chatRepositoryProvider);



    return Scaffold(

      appBar: AppBar(

        title: Text('chat_my_messages'.tr()),

        backgroundColor: Colors.green[700],

        foregroundColor: Colors.white,

      ),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance.collection('chat_rooms').snapshots(),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {

            return const Center(child: CircularProgressIndicator());

          }



          if (!snapshot.hasData) {

            return Center(child: Text('chat_load_error'.tr()));

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

            return Center(child: Text('chat_empty'.tr()));

          }



          return ListView.builder(

            itemCount: myChats.length,

            itemBuilder: (context, index) {

              final roomDoc = myChats[index];

              final roomData = roomDoc.data() as Map<String, dynamic>? ?? {};

              final otherUserId =

                  chatRepo.otherParticipantId(roomDoc.id, currentUserId);

              final unread = (roomData['unreadCounts'] as Map<String, dynamic>? ??

                      {})[currentUserId] as num? ??

                  0;

              final preview = roomData['lastMessage'] as String? ?? '';



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



                  return ListTile(

                    leading: CircleAvatar(

                      backgroundColor: Colors.green[100],

                      child: unread > 0

                          ? Badge(

                              backgroundColor: Colors.red,

                              child: Icon(Icons.person, color: Colors.green[800]),

                            )

                          : Icon(Icons.person, color: Colors.green[800]),

                    ),

                    title: Text(name),

                    subtitle: Text(

                      preview.isEmpty ? 'chat_tap_to_reply'.tr() : preview,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                    ),

                    trailing: unread > 0

                        ? Container(

                            padding: const EdgeInsets.symmetric(

                              horizontal: 8,

                              vertical: 4,

                            ),

                            decoration: BoxDecoration(

                              color: Colors.red,

                              borderRadius: BorderRadius.circular(12),

                            ),

                            child: Text(

                              '$unread',

                              style: const TextStyle(

                                color: Colors.white,

                                fontWeight: FontWeight.bold,

                                fontSize: 12,

                              ),

                            ),

                          )

                        : const Icon(Icons.chevron_right),

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

      ),

    );

  }

}


