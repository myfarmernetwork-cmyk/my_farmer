import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';

/// Lokalni fallback: obavijest o novoj chat poruci dok je app otvoren.
class ChatMessageAlertListener extends StatefulWidget {
  const ChatMessageAlertListener({super.key, required this.child});

  final Widget child;

  @override
  State<ChatMessageAlertListener> createState() =>
      _ChatMessageAlertListenerState();
}

class _ChatMessageAlertListenerState extends State<ChatMessageAlertListener> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  final Map<String, String> _lastPreviewByRoom = {};
  bool _skipInitial = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('chat_rooms')
        .snapshots()
        .listen((snapshot) => _onRoomsUpdate(snapshot, uid));
  }

  void _onRoomsUpdate(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String uid,
  ) {
    if (_skipInitial) {
      for (final doc in snapshot.docs) {
        if (!_roomIncludesUser(doc, uid)) continue;
        _lastPreviewByRoom[doc.id] = _roomPreview(doc);
      }
      _skipInitial = false;
      return;
    }

    for (final doc in snapshot.docs) {
      if (!_roomIncludesUser(doc, uid)) continue;

      final preview = _roomPreview(doc);
      final previous = _lastPreviewByRoom[doc.id];
      _lastPreviewByRoom[doc.id] = preview;

      if (previous == null || previous == preview) continue;

      final unread = _unreadForUser(doc, uid);
      if (unread <= 0) continue;

      final senderId = _otherParticipantId(doc.id, uid);
      if (senderId.isEmpty) continue;

      unawaited(_notifyChat(senderId, preview));
    }
  }

  Future<void> _notifyChat(String senderId, String preview) async {
    var senderName = senderId;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(senderId)
          .get();
      senderName = doc.data()?['name']?.toString().trim() ?? senderId;
    } catch (_) {}

    if (!mounted) return;

    NotificationService().showChatMessageAlert(
      senderId: senderId,
      senderName: senderName,
      messagePreview: preview,
    );
  }

  bool _roomIncludesUser(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) {
    if (!doc.id.contains(uid)) return false;
    final participants =
        (doc.data()['participants'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList();
    return participants.contains(uid);
  }

  int _unreadForUser(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String uid,
  ) {
    final counts =
        doc.data()['unreadCounts'] as Map<String, dynamic>? ?? const {};
    return (counts[uid] as num?)?.toInt() ?? 0;
  }

  String _roomPreview(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return doc.data()['lastMessage']?.toString().trim() ?? '';
  }

  String _otherParticipantId(String roomId, String uid) {
    final parts = roomId.split('_');
    if (parts.length != 2) return '';
    return parts.first == uid ? parts.last : parts.first;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
