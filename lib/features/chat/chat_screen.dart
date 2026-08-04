import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/animal_record.dart';
import '../../models/medical_history_entry.dart';
import '../../providers/locale_settings_provider.dart';
import '../../repositories/animal_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../services/translation_service.dart';
import '../../widgets/chat_message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;

  String _viewerLanguage = 'hr';
  bool _isSendingCard = false;

  @override
  void initState() {
    super.initState();
    _syncPreferredLanguage();
    _markRoomRead();
  }

  Future<void> _markRoomRead() async {
    if (currentUser == null) return;
    await ref.read(chatRepositoryProvider).markRoomRead(
          roomId: _chatRoomId,
          userId: currentUser!.uid,
        );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _syncPreferredLanguage() async {
    if (currentUser == null) return;

    final storageKey =
        AppLocaleOption.fromLocale(context.locale)?.storageKey ??
            context.locale.languageCode;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .set({'preferredLanguage': storageKey}, SetOptions(merge: true));

    if (mounted) {
      setState(() => _viewerLanguage = context.locale.languageCode);
    }
  }

  String get _chatRoomId {
    final ids = [currentUser!.uid, widget.receiverId]..sort();
    return ids.join('_');
  }

  Future<String> _receiverLanguageCode() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverId)
        .get();
    final preference = doc.data()?['preferredLanguage'] as String?;
    return TranslationService.languageCodeFromPreference(preference);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final sourceLanguage = context.locale.languageCode;

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'receiverId': widget.receiverId,
      'message': text,
      'sourceLanguage': sourceLanguage,
      'messageType': 'text',
      'timestamp': Timestamp.now(),
    });

    await ref.read(chatRepositoryProvider).touchRoom(
          roomId: _chatRoomId,
          senderId: currentUser!.uid,
          receiverId: widget.receiverId,
          preview: text,
        );

    await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).set(
      {
        'preferredLanguage':
            AppLocaleOption.fromLocale(context.locale)?.storageKey ??
                sourceLanguage,
      },
      SetOptions(merge: true),
    );

    _messageController.clear();
  }

  Future<void> _sendMedicalCard(
    AnimalRecord animal, {
    List<MedicalHistoryEntry>? selectedEntries,
  }) async {
    if (currentUser == null || _isSendingCard) return;

    setState(() => _isSendingCard = true);

    try {
      final sourceLanguage = context.locale.languageCode;
      final receiverLanguage = await _receiverLanguageCode();
      final originalText = animal.formatMedicalCard(
        cardTitle: 'animals_medical_card'.tr(),
        selectedEntries: selectedEntries,
      );

      final translated = await ref.read(translationServiceProvider).translateForViewer(
            text: originalText,
            sourceLanguage: sourceLanguage,
            viewerLanguage: receiverLanguage,
          );

      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUser!.uid,
        'receiverId': widget.receiverId,
        'message': translated,
        'originalMessage': originalText,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': receiverLanguage,
        'messageType': 'medical_card',
        'animalId': animal.id,
        'animalName': animal.name,
        'timestamp': Timestamp.now(),
      });

      await ref.read(chatRepositoryProvider).touchRoom(
            roomId: _chatRoomId,
            senderId: currentUser!.uid,
            receiverId: widget.receiverId,
            preview: '${animal.name}',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat_medical_sent'.tr()),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'chat_medical_error'.tr()}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingCard = false);
    }
  }

  Future<void> _showMedicalCardPicker() async {
    List<AnimalRecord> animals;
    try {
      animals = await ref.read(userAnimalsProvider.future);
    } catch (_) {
      animals = [];
    }

    if (animals.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('chat_no_animals'.tr())),
      );
      return;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MedicalCardPickerSheet(
        animals: animals,
        onSend: (animal, selectedEntries) {
          Navigator.pop(ctx);
          _sendMedicalCard(animal, selectedEntries: selectedEntries);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _viewerLanguage = context.locale.languageCode;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName),
            Text(
              'chat_auto_translate'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chat_rooms')
                    .doc(_chatRoomId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data!.docs[index].data()
                          as Map<String, dynamic>;
                      final isMe = data['senderId'] == currentUser!.uid;
                      final messageType =
                          data['messageType'] as String? ?? 'text';

                      return ChatMessageBubble(
                        message: data['message'] as String? ?? '',
                        originalMessage: data['originalMessage'] as String?,
                        messageType: messageType,
                        sourceLanguage:
                            data['sourceLanguage'] as String? ?? 'auto',
                        viewerLanguage: _viewerLanguage,
                        isMe: isMe,
                      );
                    },
                  );
                },
              ),
            ),
            if (_isSendingCard)
              const LinearProgressIndicator(minHeight: 2),
            Material(
              elevation: 8,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.medical_services_outlined,
                          color: Colors.green),
                      tooltip: 'chat_send_medical_title'.tr(),
                      onPressed: _isSendingCard ? null : _showMedicalCardPicker,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'chat_hint'.tr(),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.green),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalCardPickerSheet extends StatefulWidget {
  final List<AnimalRecord> animals;
  final void Function(
    AnimalRecord animal,
    List<MedicalHistoryEntry>? selectedEntries,
  ) onSend;

  const _MedicalCardPickerSheet({
    required this.animals,
    required this.onSend,
  });

  @override
  State<_MedicalCardPickerSheet> createState() =>
      _MedicalCardPickerSheetState();
}

class _MedicalCardPickerSheetState extends State<_MedicalCardPickerSheet> {
  AnimalRecord? _selectedAnimal;
  final Set<String> _selectedEntryIds = {};
  bool _selectAll = true;

  void _selectAnimal(AnimalRecord animal) {
    setState(() {
      _selectedAnimal = animal;
      _selectedEntryIds
        ..clear()
        ..addAll(animal.sortedMedicalHistory.map((e) => e.id));
      _selectAll = animal.sortedMedicalHistory.isNotEmpty;
    });
  }

  List<MedicalHistoryEntry>? _selectedEntriesFor(AnimalRecord animal) {
    if (animal.sortedMedicalHistory.isEmpty) return null;
    if (_selectAll) return animal.sortedMedicalHistory;
    final selected = animal.sortedMedicalHistory
        .where((e) => _selectedEntryIds.contains(e.id))
        .toList();
    return selected.isEmpty ? null : selected;
  }

  @override
  Widget build(BuildContext context) {
    final animal = _selectedAnimal;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'chat_send_medical_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              'chat_send_medical_subtitle'.tr(),
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            if (animal == null)
              ...widget.animals.map(
                (item) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    backgroundImage: item.imageUrl.isNotEmpty
                        ? NetworkImage(item.imageUrl)
                        : null,
                    child: item.imageUrl.isEmpty
                        ? Icon(Icons.pets, color: Colors.green[800])
                        : null,
                  ),
                  title: Text(item.name),
                  subtitle: Text('${item.species} · ${item.age}'),
                  onTap: () => _selectAnimal(item),
                ),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.pets, color: Colors.green),
                title: Text(animal.name),
                subtitle: Text('chat_select_records'.tr()),
                trailing: TextButton(
                  onPressed: () => setState(() => _selectedAnimal = null),
                  child: Text('cart_cancel'.tr()),
                ),
              ),
              if (animal.sortedMedicalHistory.isNotEmpty) ...[
                CheckboxListTile(
                  value: _selectAll,
                  onChanged: (value) {
                    setState(() {
                      _selectAll = value ?? false;
                      if (_selectAll) {
                        _selectedEntryIds
                          ..clear()
                          ..addAll(
                            animal.sortedMedicalHistory.map((e) => e.id),
                          );
                      }
                    });
                  },
                  title: Text('chat_select_all_records'.tr()),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: animal.sortedMedicalHistory.length,
                    itemBuilder: (context, index) {
                      final entry = animal.sortedMedicalHistory[index];
                      final dateLabel = entry.createdAt != null
                          ? DateFormatHelper.formatTimestamp(entry.createdAt!)
                          : '';
                      return CheckboxListTile(
                        value: _selectAll ||
                            _selectedEntryIds.contains(entry.id),
                        onChanged: _selectAll
                            ? null
                            : (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedEntryIds.add(entry.id);
                                  } else {
                                    _selectedEntryIds.remove(entry.id);
                                  }
                                });
                              },
                        title: Text(
                          dateLabel.isEmpty ? entry.note : '$dateLabel — ${entry.note}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: entry.attachments.isNotEmpty
                            ? Text(
                                '${entry.attachments.length} prilog(a)',
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onSend(
                      animal,
                      _selectedEntriesFor(animal),
                    ),
                    icon: const Icon(Icons.send),
                    label: Text('chat_send_selected'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
